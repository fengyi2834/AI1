const API_BASE = "/api/ai/chat";
const LEAD_API = "/api/ai/lead";
const HANDOFF_API = "/api/ai/handoff";

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

let pendingImage = null;

const IMAGE_MARKDOWN_RE = /!\[([^\]]*)\]\(((?:https?:\/\/|\/)[^\s)]+)\)/g;

const normalizeText = (text = "") =>
  text
    .replace(/\r\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+\n/g, "\n")
    .trim();

const looksBroken = (text = "") => {
  const trimmed = text.trim();
  if (!trimmed) return true;

  const questionMarks = (trimmed.match(/[\?\uFF1F]/g) || []).length;
  const replacementMarks = (trimmed.match(/[�锟]/g) || []).length;
  const cjkChars = (trimmed.match(/[\u4e00-\u9fff]/g) || []).length;
  const latinChars = (trimmed.match(/[A-Za-z]/g) || []).length;

  if (replacementMarks > 0) return true;
  if (questionMarks >= 4 && cjkChars + latinChars <= 3) return true;
  if (trimmed.length <= 3) return true;

  return false;
};

const looksLikeEnglishFallback = (text = "") => {
  const trimmed = text.trim();
  if (!trimmed) return false;

  const cjkChars = (trimmed.match(/[\u4e00-\u9fff]/g) || []).length;
  const latinWords = trimmed.match(/[A-Za-z]{3,}/g) || [];

  return cjkChars === 0 && latinWords.length >= 4;
};

const isNewHouseQuestion = (question = "") => /新房|装修|家装|适合/.test(question);
const isOdorQuestion = (question = "") => /除味|异味|气味|空气|甲醛/.test(question);
const isIntroQuestion = (question = "") => /介绍|产品|做什么|是什么/.test(question);

const answerLooksOffTopic = (question = "", answer = "") => {
  if (!answer) return true;

  if (isNewHouseQuestion(question)) {
    return !/新房|家装|居住|空间|通风|检测|适合/.test(answer);
  }

  if (isOdorQuestion(question)) {
    return !/除味|异味|气味|空气|净化|吸附|甲醛/.test(answer);
  }

  if (isIntroQuestion(question)) {
    return !/产品|硅藻板|公司|环保|功能|定位/.test(answer);
  }

  return false;
};

const buildFriendlyFallback = (question) => {
  if (isIntroQuestion(question)) {
    return "我先按当前资料给您做个简要介绍：这类问题更适合先看产品定位、核心功能和适用场景，您也可以继续追问更具体的点。";
  }

  if (isNewHouseQuestion(question)) {
    return "如果您主要是看新房能不能用，我建议重点确认适用空间、环保依据和是否需要配合通风检测，我可以继续按这几个点给您展开。";
  }

  if (isOdorQuestion(question)) {
    return "关于气味和空气感受这类问题，我会尽量只按已有资料来回答。如果您方便，也可以把产品图、参数图或现场图一起发来，我结合图片看会更稳。";
  }

  return "这次返回内容不够稳定，我先按当前资料继续帮您确认。您可以换个更具体的问法，或者直接补一张相关图片给我。";
};

const createFigure = (src, alt = "图片", captionText = "") => {
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
};

const renderRichText = (container, text) => {
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
};

const appendMessage = ({ text = "", role, isSystem = false, imageSrc = "", imageAlt = "", imageName = "" }) => {
  const row = document.createElement("div");
  row.className = `message-row ${role}`;

  const bubble = document.createElement("article");
  bubble.className = `message-bubble ${role}`;

  if (role === "bot" && isSystem) {
    const meta = document.createElement("span");
    meta.className = "message-meta";
    meta.textContent = "服务提示";
    bubble.appendChild(meta);
  }

  const body = document.createElement("div");
  body.className = "message-body";
  bubble.appendChild(body);

  if (text) {
    renderRichText(body, text);
  }

  if (imageSrc) {
    body.appendChild(createFigure(imageSrc, imageAlt || imageName || "用户发送的图片", imageName || ""));
  }

  row.appendChild(bubble);
  chatLog.appendChild(row);
  chatLog.scrollTop = chatLog.scrollHeight;

  return { row, bubble, body };
};

const setMessageText = (handle, text) => {
  if (!handle?.body) return;
  renderRichText(handle.body, text);
  chatLog.scrollTop = chatLog.scrollHeight;
};

const formatAnswer = (payload, question) => {
  const rawAnswer = normalizeText(payload?.answer || "");

  if (!rawAnswer || looksBroken(rawAnswer)) {
    return buildFriendlyFallback(question);
  }

  if (payload?.mode === "fallback" && looksLikeEnglishFallback(rawAnswer)) {
    return buildFriendlyFallback(question);
  }

  if (payload?.mode === "fallback" && /[\u4e00-\u9fff]/.test(rawAnswer) && answerLooksOffTopic(question, rawAnswer)) {
    return buildFriendlyFallback(question);
  }

  return rawAnswer;
};

const formatFileSize = (bytes = 0) => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
};

const readFileAsDataURL = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(new Error("图片读取失败，请换一张图片再试。"));
    reader.readAsDataURL(file);
  });

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("图片预览失败，请重新上传。"));
    img.src = src;
  });

const compressImage = async (dataUrl, fileType) => {
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
};

const prepareImagePayload = async (file) => {
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
};

const resetPendingImage = () => {
  pendingImage = null;
  imageInput.value = "";
  imagePreview.classList.add("is-hidden");
  imagePreviewImg.src = "";
  imagePreviewName.textContent = "待发送图片";
  imagePreviewMeta.textContent = "支持 PNG、JPG、WEBP";
};

const renderPendingImage = () => {
  if (!pendingImage) {
    resetPendingImage();
    return;
  }

  imagePreview.classList.remove("is-hidden");
  imagePreviewImg.src = pendingImage.dataUrl;
  imagePreviewName.textContent = pendingImage.name;
  imagePreviewMeta.textContent = `已准备发送 · ${pendingImage.sizeLabel}`;
};

const sendChat = async (question, imagePayload = null) => {
  const userText = question || "请帮我看看这张图片。";
  appendMessage({
    text: userText,
    role: "user",
    imageSrc: imagePayload?.dataUrl || "",
    imageName: imagePayload?.name || ""
  });

  const pendingText = imagePayload ? "正在结合图片和问题整理答复，请稍等片刻。" : "正在整理答复，请稍等片刻。";
  const pending = appendMessage({ text: pendingText, role: "bot" });

  try {
    const response = await fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify({
        question,
        history: [],
        imageDataUrl: imagePayload?.dataUrl || null,
        imageName: imagePayload?.name || null
      })
    });

    const payload = await response.json();
    setMessageText(pending, formatAnswer(payload, question || userText));
  } catch (error) {
    setMessageText(pending, "这次请求没有成功返回。您可以稍后再试，或者先换一张更清晰的图片继续发给我。");
    console.error("chat error", error);
  }
};

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
        body: JSON.stringify(data)
      });
      alert("信息已提交，顾问会根据当前咨询情况继续跟进。");
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
        body: JSON.stringify({ reason: "用户请求人工协助" })
      });
      const payload = await response.json();
      appendMessage({
        text: `已为您转入顾问跟进流程，当前状态：${payload.status}。`,
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
  text: "您好，欢迎咨询。您可以直接发文字，也可以点击右下角加号上传产品图、现场图或聊天截图，我会结合图片一起帮您看。",
  role: "bot"
});
