const API_BASE = "/api/ai/chat";
const LEAD_API = "/api/ai/lead";
const HANDOFF_API = "/api/ai/handoff";
const ADMIN_CONFIG_API = "/api/admin/runtime-config";

const CHAT_CHANNEL = "web";
const USER_STORAGE_KEY = "gx_yiku_demo_external_user_id";
const CONVERSATION_STORAGE_KEY = "gx_yiku_demo_conversation_id";
const MODEL_STORAGE_KEY = "gx_yiku_demo_direct_model_override";
const HISTORY_LIMIT = 12;
const IMAGE_MARKDOWN_RE = /!\[([^\]]*)\]\(((?:https?:\/\/|\/)[^\s)]+)\)/g;

const MODEL_DEFAULT = "glm-4-flash-250414";
const MODEL_EXPERIMENT = "glm-5";
const STEALTH_TAP_COUNT = 5;
const STEALTH_TAP_WINDOW_MS = 2200;

const chatLog = document.getElementById("chatLog");
const chatForm = document.getElementById("chatForm");
const chatInput = document.getElementById("chatInput");
const imageInput = document.getElementById("imageInput");
const imagePreview = document.getElementById("imagePreview");
const imagePreviewImg = document.getElementById("imagePreviewImg");
const imagePreviewName = document.getElementById("imagePreviewName");
const imagePreviewMeta = document.getElementById("imagePreviewMeta");
const clearImageBtn = document.getElementById("clearImageBtn");
const leadForm = document.getElementById("leadForm");
const handoff = document.getElementById("handoff");
const quickQuestions = document.querySelectorAll(".quick-question");
const adminRuntimeNote = document.getElementById("adminRuntimeNote");
const stealthTrigger = document.getElementById("stealthTrigger");
const stealthPanel = document.getElementById("stealthPanel");
const stealthClose = document.getElementById("stealthClose");
const stealthState = document.getElementById("stealthState");
const stealthOptions = document.querySelectorAll(".stealth-option");

let pendingImage = null;
let chatHistory = [];
let stealthTapTimes = [];

const externalUserId = getOrCreateId(localStorage, USER_STORAGE_KEY, "web-user");
const conversationId = getOrCreateId(sessionStorage, CONVERSATION_STORAGE_KEY, "web-conv");
const sessionId = createId("web-session");

function createId(prefix) {
  if (window.crypto?.randomUUID) {
    return `${prefix}-${window.crypto.randomUUID()}`;
  }

  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
}

function getOrCreateId(storage, key, prefix) {
  try {
    const existing = storage.getItem(key);
    if (existing) return existing;
    const next = createId(prefix);
    storage.setItem(key, next);
    return next;
  } catch {
    return createId(prefix);
  }
}

function normalizeText(text = "") {
  return text
    .replace(/\r\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+\n/g, "\n")
    .trim();
}

function getSelectedModel() {
  try {
    const current = localStorage.getItem(MODEL_STORAGE_KEY);
    return current === MODEL_EXPERIMENT ? MODEL_EXPERIMENT : MODEL_DEFAULT;
  } catch {
    return MODEL_DEFAULT;
  }
}

function setSelectedModel(model) {
  const next = model === MODEL_EXPERIMENT ? MODEL_EXPERIMENT : MODEL_DEFAULT;
  try {
    if (next === MODEL_DEFAULT) {
      localStorage.removeItem(MODEL_STORAGE_KEY);
    } else {
      localStorage.setItem(MODEL_STORAGE_KEY, next);
    }
  } catch {
    // ignore storage errors
  }
  updateStealthPanelState();
}

function getModelLabel(model) {
  return model === MODEL_EXPERIMENT ? "glm-5（实验）" : "glm-4-flash-250414（默认）";
}

function updateStealthPanelState() {
  const selectedModel = getSelectedModel();
  if (stealthState) {
    stealthState.textContent = `当前：${getModelLabel(selectedModel)}`;
  }

  stealthOptions.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.model === selectedModel);
  });
}

function openStealthPanel() {
  if (!stealthPanel) return;
  stealthPanel.classList.remove("is-hidden");
  updateStealthPanelState();
}

function closeStealthPanel() {
  stealthPanel?.classList.add("is-hidden");
}

function handleStealthTap() {
  const now = Date.now();
  stealthTapTimes = stealthTapTimes.filter((time) => now - time <= STEALTH_TAP_WINDOW_MS);
  stealthTapTimes.push(now);
  if (stealthTapTimes.length >= STEALTH_TAP_COUNT) {
    stealthTapTimes = [];
    openStealthPanel();
  }
}

function bindStealthAccess() {
  stealthTrigger?.addEventListener("click", handleStealthTap);
  stealthClose?.addEventListener("click", closeStealthPanel);

  document.addEventListener("keydown", (event) => {
    if (event.ctrlKey && event.altKey && event.key.toLowerCase() === "m") {
      event.preventDefault();
      if (stealthPanel?.classList.contains("is-hidden")) {
        openStealthPanel();
      } else {
        closeStealthPanel();
      }
    }

    if (event.key === "Escape" && !stealthPanel?.classList.contains("is-hidden")) {
      closeStealthPanel();
    }
  });

  stealthOptions.forEach((button) => {
    button.addEventListener("click", () => {
      setSelectedModel(button.dataset.model || MODEL_DEFAULT);
    });
  });
}

function setAdminRuntimeNote(text, tone = "muted") {
  if (!adminRuntimeNote) return;
  adminRuntimeNote.textContent = text;
  adminRuntimeNote.dataset.tone = tone;
}

async function loadAdminConfig() {
  try {
    const response = await fetch(ADMIN_CONFIG_API, {
      method: "GET",
      headers: {
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      throw new Error(`配置读取失败 (${response.status})`);
    }

    const config = await response.json();
    const backend = config.chat_backend || "direct";
    const guidedAnswer = config.guided_answer_enabled === false ? "off" : "on";
    setAdminRuntimeNote(`当前链路：${backend} · guided_answer=${guidedAnswer}`, "muted");
  } catch (error) {
    setAdminRuntimeNote(`配置读取失败：${error.message || "请稍后再试"}`, "warning");
  }
}

function createFigure(src, alt = "图片", captionText = "") {
  const figure = document.createElement("figure");
  figure.className = "message-image";

  const img = document.createElement("img");
  img.src = src;
  img.alt = alt;
  figure.appendChild(img);

  if (captionText) {
    const caption = document.createElement("figcaption");
    caption.className = "message-caption";
    caption.textContent = captionText;
    figure.appendChild(caption);
  }

  return figure;
}

function renderRichText(container, text) {
  container.innerHTML = "";
  const raw = text || "";
  const matches = [...raw.matchAll(IMAGE_MARKDOWN_RE)];

  if (matches.length === 0) {
    if (raw) {
      const p = document.createElement("p");
      p.textContent = raw;
      container.appendChild(p);
    }
    return;
  }

  let cursor = 0;
  matches.forEach((match) => {
    const [full, alt, url] = match;
    const index = match.index ?? 0;
    const plainChunk = normalizeText(raw.slice(cursor, index));
    if (plainChunk) {
      const p = document.createElement("p");
      p.textContent = plainChunk;
      container.appendChild(p);
    }

    container.appendChild(createFigure(url, alt || "图片", alt || ""));
    cursor = index + full.length;
  });

  const tail = normalizeText(raw.slice(cursor));
  if (tail) {
    const p = document.createElement("p");
    p.textContent = tail;
    container.appendChild(p);
  }
}

function renderAssets(container, assets = []) {
  assets.forEach((asset) => {
    if (!asset?.url) return;
    container.appendChild(createFigure(asset.url, asset.alt || "图片", asset.caption || ""));
  });
}

function appendMessage({
  text = "",
  role,
  isSystem = false,
  isPending = false,
  imageSrc = "",
  imageAlt = "",
  imageName = "",
  assets = []
}) {
  const row = document.createElement("div");
  row.className = `message-row ${role}`;

  const bubble = document.createElement("article");
  bubble.className = `message-bubble ${role}`;

  if (isPending) {
    bubble.classList.add("is-typing");
  }

  if (role === "bot" && isSystem) {
    const meta = document.createElement("span");
    meta.className = "message-meta";
    meta.textContent = "服务提示";
    bubble.appendChild(meta);
  }

  const body = document.createElement("div");
  body.className = "message-body";
  bubble.appendChild(body);

  if (isPending) {
    const p = document.createElement("p");
    p.textContent = text || "正在输入";
    body.appendChild(p);

    const dots = document.createElement("span");
    dots.className = "typing-dots";
    dots.innerHTML = "<span></span><span></span><span></span>";
    body.appendChild(dots);
  } else if (text) {
    renderRichText(body, text);
  }

  if (imageSrc) {
    body.appendChild(createFigure(imageSrc, imageAlt || imageName || "用户发送的图片", imageName || ""));
  }

  if (assets.length > 0) {
    renderAssets(body, assets);
  }

  row.appendChild(bubble);
  chatLog.appendChild(row);
  chatLog.scrollTop = chatLog.scrollHeight;

  return { row, bubble, body };
}

function setMessageContent(handle, { text = "", assets = [] }) {
  if (!handle?.body) return;
  handle.bubble?.classList.remove("is-typing");
  renderRichText(handle.body, text);
  if (assets.length > 0) {
    renderAssets(handle.body, assets);
  }
  chatLog.scrollTop = chatLog.scrollHeight;
}

function pushHistory(role, text) {
  const content = normalizeText(text || "");
  if (!content) return;

  chatHistory.push({
    role,
    text: content
  });

  if (chatHistory.length > HISTORY_LIMIT) {
    chatHistory = chatHistory.slice(-HISTORY_LIMIT);
  }
}

function formatAssistantPayload(payload, question) {
  const displayText = normalizeText(
    payload?.channelPayload?.displayText || payload?.answer || ""
  );
  const assets = Array.isArray(payload?.channelPayload?.assets)
    ? payload.channelPayload.assets
    : [];

  if (!displayText) {
    return {
      text: question
        ? "这次没有拿到稳定回复，你可以换个更具体的问法，或者直接发张图给我。"
        : "这次没有拿到稳定回复，你可以稍后再试，或者直接发张图给我。",
      assets: []
    };
  }

  return {
    text: displayText,
    assets
  };
}

function formatFileSize(bytes = 0) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function readFileAsDataURL(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(new Error("图片读取失败，请换一张图片再试。"));
    reader.readAsDataURL(file);
  });
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("图片预览失败，请重新上传。"));
    img.src = src;
  });
}

async function compressImage(dataUrl, fileType) {
  const image = await loadImage(dataUrl);
  const maxSide = 1600;
  const scale = Math.min(1, maxSide / Math.max(image.width, image.height));
  const width = Math.max(1, Math.round(image.width * scale));
  const height = Math.max(1, Math.round(image.height * scale));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext("2d");
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(image, 0, 0, width, height);

  const outputType = fileType === "image/png" && scale === 1 ? "image/png" : "image/jpeg";
  const quality = outputType === "image/jpeg" ? 0.86 : undefined;

  return canvas.toDataURL(outputType, quality);
}

async function prepareImagePayload(file) {
  if (!file) return null;

  if (!/^image\/(png|jpeg|jpg|webp)$/.test(file.type)) {
    throw new Error("当前只支持 PNG、JPG、JPEG、WEBP 图片。");
  }

  if (file.size > 12 * 1024 * 1024) {
    throw new Error("单张图片请控制在 12MB 以内。");
  }

  let dataUrl = await readFileAsDataURL(file);
  if (file.size > 1.8 * 1024 * 1024) {
    dataUrl = await compressImage(dataUrl, file.type);
  }

  return {
    name: file.name,
    dataUrl,
    sizeLabel: formatFileSize(file.size)
  };
}

function resetPendingImage() {
  pendingImage = null;
  imageInput.value = "";
  imagePreview.classList.add("is-hidden");
  imagePreviewImg.src = "";
  imagePreviewName.textContent = "待发送图片";
  imagePreviewMeta.textContent = "支持 PNG、JPG、WEBP";
}

function renderPendingImage() {
  if (!pendingImage) {
    resetPendingImage();
    return;
  }

  imagePreview.classList.remove("is-hidden");
  imagePreviewImg.src = pendingImage.dataUrl;
  imagePreviewName.textContent = pendingImage.name;
  imagePreviewMeta.textContent = `已准备发送 · ${pendingImage.sizeLabel}`;
}

async function sendChat(question, imagePayload = null) {
  const userText = question || "请帮我看看这张图片。";
  const historySnapshot = chatHistory.slice(-6);

  appendMessage({
    text: userText,
    role: "user",
    imageSrc: imagePayload?.dataUrl || "",
    imageName: imagePayload?.name || ""
  });
  pushHistory("user", userText);

  const pending = appendMessage({
    text: "正在输入",
    role: "bot",
    isPending: true
  });

  try {
    const response = await fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify({
        channel: CHAT_CHANNEL,
        externalUserId,
        conversationId,
        sessionId,
        question,
        history: historySnapshot,
        imageDataUrl: imagePayload?.dataUrl || null,
        imageName: imagePayload?.name || null,
        modelOverride: getSelectedModel()
      })
    });

    const payload = await response.json();
    const formatted = formatAssistantPayload(payload, question);
    setMessageContent(pending, formatted);
    pushHistory("assistant", formatted.text);
  } catch (error) {
    const fallbackText =
      "这次请求没有成功返回。你可以稍后再试，或者先换一张更清晰的图片继续发给我。";
    setMessageContent(pending, { text: fallbackText, assets: [] });
    pushHistory("assistant", fallbackText);
    console.error("chat error", error);
  }
}

chatForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const question = chatInput.value.trim();
  if (!question && !pendingImage) return;

  const imagePayload = pendingImage;
  chatInput.value = "";
  resetPendingImage();
  await sendChat(question, imagePayload);
});

imageInput.addEventListener("change", async (event) => {
  const [file] = event.target.files || [];
  if (!file) return;

  try {
    pendingImage = await prepareImagePayload(file);
    renderPendingImage();
  } catch (error) {
    resetPendingImage();
    alert(error.message);
  }
});

clearImageBtn.addEventListener("click", () => {
  resetPendingImage();
});

quickQuestions.forEach((button) => {
  button.addEventListener("click", () => {
    chatInput.value = button.textContent.trim();
    chatInput.focus();
  });
});

if (leadForm) {
  leadForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(leadForm));

    try {
      await fetch(LEAD_API, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify({
          ...data,
          channel: CHAT_CHANNEL,
          externalUserId,
          conversationId,
          sessionId
        })
      });
      alert("信息已提交，顾问会继续跟进。");
      leadForm.reset();
    } catch (error) {
      alert("提交失败，请稍后重试。");
      console.error("lead error", error);
    }
  });
}

if (handoff) {
  handoff.addEventListener("click", async () => {
    try {
      const response = await fetch(HANDOFF_API, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify({
          reason: "用户请求人工协助",
          channel: CHAT_CHANNEL,
          externalUserId,
          conversationId,
          sessionId
        })
      });
      const payload = await response.json();
      appendMessage({
        text: `已为你转入顾问跟进流程，当前状态：${payload.status}。`,
        role: "bot",
        isSystem: true
      });
    } catch (error) {
      appendMessage({
        text: "暂时无法转接顾问，请稍后再试。",
        role: "bot",
        isSystem: true
      });
      console.error("handoff error", error);
    }
  });
}

appendMessage({
  text: "你好，直接说你现在最想确认的点就行。比如适合哪里用、能不能做柜体，或者发张图我帮你一起看。",
  role: "bot"
});

bindStealthAccess();
updateStealthPanelState();
loadAdminConfig();
