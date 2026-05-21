const siteConfig = {
  aiApiUrl: "/api/ai/chat",
  leadApiUrl: "/api/ai/lead",
  handoffApiUrl: "/api/ai/handoff",
  adminConfigUrl: "/api/admin/runtime-config",
  mediaApiUrl: "/api/media",
  enableLiveApi: true
};

const debugMode =
  new URLSearchParams(window.location.search).get("debug") === "1" ||
  window.localStorage.getItem("yiku_debug_console") === "1";

const state = {
  imageDataUrl: "",
  imageName: "",
  handoffReady: false,
  isSending: false
};

const panel = document.getElementById("ai-panel");
const launcher = document.getElementById("ai-launcher");
const closeButton = document.getElementById("panel-close");
const stream = document.getElementById("chat-stream");
const messageTemplate = document.getElementById("message-template");
const composer = document.getElementById("chat-composer");
const chatInput = document.getElementById("chat-input");
const chatSubmitButton = document.getElementById("chat-submit");
const imageInput = document.getElementById("image-input");
const imageLabel = document.getElementById("image-label");
const leadBridge = document.getElementById("lead-bridge");
const leadBridgeSubmitButton = document.getElementById("lead-bridge-submit");
const leadForm = document.getElementById("lead-form");
const leadSubmitButton = document.getElementById("lead-submit");
const modelStatus = document.getElementById("ai-model-status");
const adminConsole = document.getElementById("admin-console");
const adminToggleButton = document.getElementById("admin-toggle-button");
const adminConsoleBody = document.getElementById("admin-console-body");
const adminRuntimeNote = document.getElementById("admin-runtime-note");

function createId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`;
}

function getSession() {
  const saved = localStorage.getItem("yiku_ai_session");

  if (saved) {
    return JSON.parse(saved);
  }

  const session = {
    channel: "web",
    externalUserId: createId("visitor"),
    conversationId: createId("conversation"),
    sessionId: createId("session"),
    history: []
  };

  localStorage.setItem("yiku_ai_session", JSON.stringify(session));
  return session;
}

function saveSession(session) {
  localStorage.setItem("yiku_ai_session", JSON.stringify(session));
}

function openPanel() {
  panel.classList.add("open");
  panel.setAttribute("aria-hidden", "false");
}

function closePanel() {
  panel.classList.remove("open");
  panel.setAttribute("aria-hidden", "true");
}

function setServiceStatus(text) {
  if (modelStatus) {
    modelStatus.textContent = text;
  }
}

function getTechnicalStatus(mode, backendModel = "") {
  if (backendModel) {
    return `模型链路：FastGPT 应用 / ${backendModel.toUpperCase()}`;
  }

  const labels = {
    fastgpt_app: "模型链路：FastGPT 应用 / GLM-4-Flash",
    fastgpt_cache: "模型链路：FastGPT 应用缓存",
    fastgpt_vision_app: "模型链路：FastGPT 图片应用 / GLM-4-Flash",
    api_rag: "模型链路：API RAG / GLM-4-Flash",
    live_model: "模型链路：直连智谱 GLM-4-Flash",
    live_model_fallback: "模型链路：FastGPT 回退 / 智谱 GLM-4-Flash",
    vision_rag: "模型链路：图片理解 + API RAG",
    vision_model: "模型链路：智谱 GLM-4V-Flash",
    model_diagnostics: "模型链路：隐藏诊断",
    identity_guard: "模型链路：身份保护",
    guided_answer: "模型链路：后端业务规则",
    scenario_guided: "模型链路：后端场景规则",
    fallback: "模型链路：本地知识库兜底",
    fastgpt_unavailable: "模型链路：FastGPT 未返回稳定结果",
    live_unavailable: "模型链路：仅在线主链，当前未拿到稳定结果"
  };

  return labels[mode] || `模型链路：${mode || "未知"}`;
}

function updateModelStatus(mode, backendModel = "") {
  if (!modelStatus) {
    return;
  }

  if (debugMode) {
    modelStatus.textContent = getTechnicalStatus(mode, backendModel);
    return;
  }

  modelStatus.textContent = "当前客服在线，可继续追问产品、空间、报价、施工和案例。";
}

function setAdminRuntimeNote(text, tone = "muted") {
  if (!adminRuntimeNote) {
    return;
  }

  adminRuntimeNote.textContent = text;
  adminRuntimeNote.dataset.tone = tone;
}

function toggleAdminConsole(forceOpen) {
  if (!adminConsoleBody || !adminToggleButton) {
    return;
  }

  const nextOpen =
    typeof forceOpen === "boolean"
      ? forceOpen
      : adminConsoleBody.classList.contains("hidden");

  adminConsoleBody.classList.toggle("hidden", !nextOpen);
  adminToggleButton.setAttribute("aria-expanded", nextOpen ? "true" : "false");
}

function updateDebugVisibility() {
  if (!adminConsole) {
    return;
  }

  adminConsole.classList.toggle("hidden", !debugMode);
}

function renderOnlineOnlyAdminConfig(config) {
  if (!config || !debugMode) {
    return;
  }

  const backend = config.chat_backend || "direct";
  const guidedAnswer = config.guided_answer_enabled === false ? "off" : "on";
  setAdminRuntimeNote(
    `CHAT_BACKEND=${backend}，guided_answer=${guidedAnswer}。`,
    "muted"
  );
}

async function loadAdminConfig() {
  if (!siteConfig.adminConfigUrl || !debugMode) {
    return;
  }

  try {
    const response = await fetch(siteConfig.adminConfigUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      throw new Error(`配置读取失败 (${response.status})`);
    }

    const config = await response.json();
    renderOnlineOnlyAdminConfig(config);
  } catch (error) {
    setAdminRuntimeNote(
      `调试配置读取失败：${error.message || "请稍后再试"}`,
      "warning"
    );
  }
}

function resetImageSelection() {
  state.imageDataUrl = "";
  state.imageName = "";
  imageInput.value = "";
  imageLabel.textContent = "上传现场图";
  imageLabel.parentElement?.classList.remove("is-disabled");
}

function setComposerPending(isPending) {
  state.isSending = isPending;
  composer.classList.toggle("is-pending", isPending);
  chatInput.disabled = isPending;
  imageInput.disabled = isPending;
  chatSubmitButton.disabled = isPending;
  chatSubmitButton.textContent = isPending ? "客服查看中..." : "发送给客服";
  imageLabel.parentElement?.classList.toggle("is-disabled", isPending);
}

function setButtonPending(button, isPending, pendingText, idleText) {
  if (!button) {
    return;
  }

  button.disabled = isPending;
  button.textContent = isPending ? pendingText : idleText;
}

function renderMessage(role, text, assets = [], options = {}) {
  const fragment = messageTemplate.content.cloneNode(true);
  const article = fragment.querySelector(".message");
  const roleNode = fragment.querySelector(".message-role");
  const bubbleNode = fragment.querySelector(".message-bubble");
  const isPending = Boolean(options.pending);

  article.classList.add(role === "assistant" ? "is-assistant" : "is-user");
  if (isPending) {
    article.classList.add("is-pending");
  }

  roleNode.textContent =
    role === "assistant" ? (isPending ? "客服处理中" : "在线客服") : "您";
  bubbleNode.textContent = text;

  if (assets.length) {
    const gallery = document.createElement("div");
    gallery.className = "asset-gallery";

    assets.forEach((asset) => {
      const card = document.createElement("article");
      card.className = "asset-card";

      const image = document.createElement("img");
      image.src = asset.url;
      image.alt = asset.caption;

      const caption = document.createElement("p");
      caption.textContent = asset.caption;

      card.append(image, caption);
      gallery.append(card);
    });

    bubbleNode.append(gallery);
  }

  if (options.replaceArticle) {
    options.replaceArticle.replaceWith(article);
  } else {
    stream.append(fragment);
  }

  stream.scrollTop = stream.scrollHeight;
  return article;
}

function appendSystemGreeting() {
  if (stream.children.length) {
    return;
  }

  renderMessage(
    "assistant",
    "您好，直接告诉我您想了解的空间、板材、报价或施工问题就可以。也可以直接发现场图，我先帮您做初步判断。"
  );
}

function buildPayload(question, session) {
  return {
    channel: session.channel,
    externalUserId: session.externalUserId,
    conversationId: session.conversationId,
    sessionId: session.sessionId,
    question,
    history: session.history.slice(-6),
    imageDataUrl: state.imageDataUrl,
    imageName: state.imageName
  };
}

function normalizeHistory(session, question, answer) {
  session.history.push({ role: "user", text: question });
  session.history.push({ role: "assistant", text: answer });
  session.history = session.history.slice(-6);
  saveSession(session);
}

async function postJson(url, payload, defaultErrorMessage) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  const rawText = await response.text();
  let data = {};

  if (rawText) {
    try {
      data = JSON.parse(rawText);
    } catch (error) {
      throw new Error(defaultErrorMessage);
    }
  }

  if (!response.ok) {
    throw new Error(data?.message || `${defaultErrorMessage} (${response.status})`);
  }

  return data;
}

async function callAi(payload) {
  if (!siteConfig.enableLiveApi) {
    throw new Error("当前在线咨询未开启。");
  }

  const data = await postJson(
    siteConfig.aiApiUrl,
    payload,
    "在线咨询返回了无法识别的内容"
  );

  const assets = (data?.channelPayload?.assets || []).map((asset) => ({
    url: asset.url || `${siteConfig.mediaApiUrl}?path=${encodeURIComponent(asset.path || "")}`,
    caption: asset.caption || "参考图片"
  }));

  const handoff = data?.handoff;
  const shouldShowHandoff = handoff === true || handoff?.lead_capture_needed === true;

  return {
    answer:
      data?.channelPayload?.displayText ||
      data?.answer ||
      "已收到您的问题，客服正在继续整理信息。",
    assets,
    mode: data?.mode || "live_api",
    backendModel: data?.backend_model || "",
    handoff: shouldShowHandoff
  };
}

function buildLeadPayload(formData, session) {
  return {
    channel: session.channel,
    externalUserId: session.externalUserId,
    conversationId: session.conversationId,
    sessionId: session.sessionId,
    name: formData.get("name") || "",
    contact: formData.get("phone") || "",
    intent: formData.get("intent") || "",
    message: formData.get("message") || "",
    source: "guanwang_lead_form",
    page: window.location.pathname
  };
}

function buildHandoffPayload(formData, session) {
  return {
    channel: session.channel,
    externalUserId: session.externalUserId,
    conversationId: session.conversationId,
    sessionId: session.sessionId,
    name: formData.get("bridgeName") || "",
    contact: formData.get("bridgeContact") || "",
    need: formData.get("bridgeNeed") || "",
    source: "guanwang_handoff_form",
    page: window.location.pathname
  };
}

async function sendQuestion(question) {
  const cleanQuestion = question.trim();

  if (!cleanQuestion || state.isSending) {
    return;
  }

  openPanel();
  appendSystemGreeting();
  leadBridge.classList.add("hidden");

  const session = getSession();
  const payload = buildPayload(cleanQuestion, session);

  renderMessage(
    "user",
    state.imageName ? `${cleanQuestion}\n\n已附图：${state.imageName}` : cleanQuestion
  );

  const pendingArticle = renderMessage(
    "assistant",
    "客服正在查看您的问题，请稍等几秒。",
    [],
    { pending: true }
  );

  chatInput.value = "";
  setComposerPending(true);
  setServiceStatus("客服正在查看资料，请稍等几秒。");

  try {
    const result = await callAi(payload);
    updateModelStatus(result.mode, result.backendModel);
    renderMessage("assistant", result.answer, result.assets, {
      replaceArticle: pendingArticle
    });
    normalizeHistory(session, cleanQuestion, result.answer);

    state.handoffReady = result.handoff;
    leadBridge.classList.toggle("hidden", !result.handoff);
  } catch (error) {
    state.handoffReady = false;
    leadBridge.classList.add("hidden");
    setServiceStatus("这边暂时没收到完整回复，您可以再问一次或直接留下联系方式。");
    renderMessage(
      "assistant",
      `这边暂时没收到完整回复：${error.message || "请稍后再试"}\n\n如果您在问报价、施工、合作或送样，也可以直接留下联系方式，我们安排顾问跟进。`,
      [],
      { replaceArticle: pendingArticle }
    );
  } finally {
    setComposerPending(false);
    resetImageSelection();
  }
}

document.querySelectorAll(".trigger-ai").forEach((button) => {
  button.addEventListener("click", () => {
    const preset = button.getAttribute("data-prompt") || "";
    openPanel();
    appendSystemGreeting();
    chatInput.value = preset;
    chatInput.focus();
  });
});

document.querySelectorAll(".suggestion").forEach((button) => {
  button.addEventListener("click", () => {
    sendQuestion(button.dataset.prompt || "");
  });
});

launcher.addEventListener("click", () => {
  openPanel();
  appendSystemGreeting();
  chatInput.focus();
});

closeButton.addEventListener("click", closePanel);

if (adminToggleButton && debugMode) {
  adminToggleButton.addEventListener("click", () => {
    toggleAdminConsole();
  });
}

composer.addEventListener("submit", (event) => {
  event.preventDefault();
  sendQuestion(chatInput.value);
});

imageInput.addEventListener("change", () => {
  const [file] = imageInput.files;

  if (!file) {
    resetImageSelection();
    return;
  }

  state.imageName = file.name;
  imageLabel.textContent = `已附图：${file.name}`;

  const reader = new FileReader();
  reader.onload = () => {
    state.imageDataUrl = typeof reader.result === "string" ? reader.result : "";
  };
  reader.readAsDataURL(file);
});

leadBridge.addEventListener("submit", async (event) => {
  event.preventDefault();

  const formData = new FormData(leadBridge);
  const session = getSession();
  const payload = buildHandoffPayload(formData, session);

  setButtonPending(leadBridgeSubmitButton, true, "提交中...", "提交给客服");

  try {
    await postJson(
      siteConfig.handoffApiUrl,
      payload,
      "顾问跟进提交失败"
    );

    renderMessage(
      "assistant",
      "已收到您的联系方式和需求说明，我们会尽快安排顾问与您联系。您也可以继续补充项目背景、预算区间或施工节点。"
    );
    setServiceStatus("顾问跟进信息已登记，您也可以继续在这里补充问题。");
    leadBridge.reset();
    leadBridge.classList.add("hidden");
  } catch (error) {
    renderMessage(
      "assistant",
      `联系方式提交失败：${error.message || "请稍后再试"}`
    );
  } finally {
    setButtonPending(leadBridgeSubmitButton, false, "提交中...", "提交给客服");
  }
});

leadForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const formData = new FormData(leadForm);
  const session = getSession();
  const payload = buildLeadPayload(formData, session);
  const summary = [
    `姓名：${payload.name || "未填写"}`,
    `联系方式：${payload.contact || "未填写"}`,
    `需求类型：${payload.intent || "未填写"}`,
    `项目说明：${payload.message || "未填写"}`
  ].join("\n");

  setButtonPending(leadSubmitButton, true, "提交中...", "提交线索");

  try {
    await postJson(
      siteConfig.leadApiUrl,
      payload,
      "线索提交失败"
    );

    openPanel();
    appendSystemGreeting();
    renderMessage(
      "assistant",
      `已收到您的项目需求：\n${summary}\n\n客服这边已经登记完成，接下来会安排顾问继续跟进。`
    );
    setServiceStatus("项目需求已登记成功，您也可以继续追问产品、场景或报价细节。");
    leadForm.reset();
  } catch (error) {
    openPanel();
    appendSystemGreeting();
    renderMessage(
      "assistant",
      `线索提交失败：${error.message || "请稍后再试"}`
    );
  } finally {
    setButtonPending(leadSubmitButton, false, "提交中...", "提交线索");
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closePanel();
  }
});

appendSystemGreeting();
updateDebugVisibility();
loadAdminConfig();
