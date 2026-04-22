const API_BASE = "/api/ai/chat";
const LEAD_API = "/api/ai/lead";
const HANDOFF_API = "/api/ai/handoff";

const chatLog = document.getElementById("chatLog");
const chatForm = document.getElementById("chatForm");
const chatInput = document.getElementById("chatInput");
const leadForm = document.getElementById("leadForm");
const handoff = document.getElementById("handoff");
const quickQuestions = document.querySelectorAll(".quick-question");

const appendMessage = (text, role, isSystem = false) => {
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

  const content = document.createElement("p");
  content.textContent = text;
  bubble.appendChild(content);

  row.appendChild(bubble);
  chatLog.appendChild(row);
  chatLog.scrollTop = chatLog.scrollHeight;

  return { row, bubble, content };
};

const normalizeText = (text = "") =>
  text
    .replace(/\r\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+\n/g, "\n")
    .trim();

const looksBroken = (text = "") => {
  const trimmed = text.trim();
  if (!trimmed) return true;

  const questionMarks = (trimmed.match(/[\?？]/g) || []).length;
  const replacementMarks = (trimmed.match(/[�]/g) || []).length;
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
    return !/新房|家装|居住|空间|通风|检测|潮湿|适合/.test(answer);
  }

  if (isOdorQuestion(question)) {
    return !/除味|异味|气味|空气|净化|吸附|清新|甲醛|霉味/.test(answer);
  }

  if (isIntroQuestion(question)) {
    return !/产品|硅藻板|公司|环保|功能|定位/.test(answer);
  }

  return false;
};

const localizeFacts = (rawAnswer = "") => {
  const facts = [];

  if (/odor absorption/i.test(rawAnswer)) {
    facts.push("根据演示资料，这类材料在合适条件下可以辅助吸附异味。");
  }
  if (/home and commercial spaces/i.test(rawAnswer)) {
    facts.push("当前资料显示，它适合家庭空间和商业空间。");
  }
  if (/ventilation and inspection/i.test(rawAnswer)) {
    facts.push("如果是新房场景，建议搭配通风和检测一起使用。");
  }
  if (/product overview, usage scenarios, and lead capture flow/i.test(rawAnswer)) {
    facts.push("当前资料更适合展示产品介绍、适用场景和留资转化流程。");
  }

  return facts;
};

const buildFriendlyFallback = (question, rawAnswer = "") => {
  const factLines = localizeFacts(rawAnswer);

  if (isIntroQuestion(question)) {
    if (factLines.length > 0) {
      return `先给您一个简要介绍：\n- ${factLines.join("\n- ")}`;
    }
    return "这是一类适合先了解产品定位、核心功能和适用空间的咨询问题。您也可以继续追问适合哪些场景、主要解决什么问题。";
  }

  if (isNewHouseQuestion(question)) {
    if (factLines.length > 0) {
      return `如果是新房或装修场景，可以先这样理解：\n- ${factLines.join("\n- ")}`;
    }
    return "如果是新房或装修场景，通常会先关心是否适合入住、适用空间以及是否需要配合通风检测。当前这类问题会优先围绕这些重点说明。";
  }

  if (isOdorQuestion(question)) {
    if (factLines.length > 0) {
      return `关于除味和空气环境，当前资料可以先说明：\n- ${factLines.join("\n- ")}`;
    }
    return "关于除味、空气改善这类问题，当前会优先给出更稳妥的中文说明，避免把质量不稳定的原始内容直接展示出来。";
  }

  if (factLines.length > 0) {
    return `当前先根据已有资料给您说明：\n- ${factLines.join("\n- ")}`;
  }

  return "刚才这次答复不够稳定，我先按当前资料继续给您说明。您可以继续追问产品介绍、适用场景、空气环境改善或合作方式。";
};

const formatAnswer = (payload, question) => {
  const rawAnswer = normalizeText(payload?.answer || "");

  if (!rawAnswer || looksBroken(rawAnswer)) {
    return buildFriendlyFallback(question, rawAnswer);
  }

  if (payload?.mode === "fallback" && looksLikeEnglishFallback(rawAnswer)) {
    return buildFriendlyFallback(question, rawAnswer);
  }

  if (payload?.mode === "fallback" && /[\u4e00-\u9fff]/.test(rawAnswer) && answerLooksOffTopic(question, rawAnswer)) {
    return buildFriendlyFallback(question, rawAnswer);
  }

  return rawAnswer;
};

const sendChat = async (question) => {
  appendMessage(question, "user");
  const pending = appendMessage("正在整理答复，请稍等片刻。", "bot");

  try {
    const response = await fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question, history: [] })
    });

    const payload = await response.json();
    pending.content.textContent = formatAnswer(payload, question);
  } catch (error) {
    pending.content.textContent =
      "这次请求没有成功返回，您可以稍后再试，或先用上面的快捷问题继续了解。";
    console.error("chat error", error);
  }
};

chatForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const question = chatInput.value.trim();
  if (!question) return;
  chatInput.value = "";
  sendChat(question);
});

quickQuestions.forEach((button) => {
  button.addEventListener("click", () => {
    chatInput.value = button.textContent.trim();
    chatInput.focus();
  });
});

leadForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const data = Object.fromEntries(new FormData(leadForm));

  try {
    await fetch(LEAD_API, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data)
    });
    alert("信息已提交，顾问会根据当前咨询情况继续跟进。");
    leadForm.reset();
  } catch (error) {
    alert("提交失败，请稍后重试。");
    console.error("lead error", error);
  }
});

handoff.addEventListener("click", async () => {
  try {
    const response = await fetch(HANDOFF_API, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ reason: "用户请求人工协助" })
    });
    const payload = await response.json();
    appendMessage(`已为您转入顾问跟进流程，当前状态：${payload.status}。`, "bot", true);
  } catch (error) {
    appendMessage("暂时无法转接顾问，请稍后再试。", "bot", true);
    console.error("handoff error", error);
  }
});

appendMessage(
  "您好，欢迎咨询。您可以先问产品介绍、新房使用场景、除味效果，或者直接说明您的需求。",
  "bot"
);
