const API_BASE = "/api/ai/chat";

const chatLog = document.getElementById("chatLog");
const chatForm = document.getElementById("chatForm");
const chatInput = document.getElementById("chatInput");
const leadForm = document.getElementById("leadForm");
const handoff = document.getElementById("handoff");

const appendMessage = (text, role) => {
  const p = document.createElement("p");
  p.textContent = text;
  p.className = role;
  chatLog.appendChild(p);
  chatLog.scrollTop = chatLog.scrollHeight;
};

const sendChat = async (question) => {
  appendMessage(question, "user");
  appendMessage("正在调用智谱 GLM-5.1 生成回答...", "bot");

  try {
    const response = await fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question, history: [] }),
    });
    const payload = await response.json();
    chatLog.lastElementChild.textContent = payload.answer || "未收到响应";
  } catch (error) {
    chatLog.lastElementChild.textContent =
      "请求失败，请检查网络或 API 配置。";
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

leadForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const data = Object.fromEntries(new FormData(leadForm));
  try {
    await fetch("/api/ai/lead", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    alert("留资已提交，人工客服将优先处理");
    leadForm.reset();
  } catch (error) {
    alert("提交异常，请重试或截屏反馈");
    console.error("lead error", error);
  }
});

handoff.addEventListener("click", async () => {
  try {
    const response = await fetch("/api/ai/handoff", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ reason: "用户请求人工协助" }),
    });
    const payload = await response.json();
    appendMessage("人工协助已请求：" + payload.status, "bot");
  } catch (error) {
    appendMessage("人工协助请求失败，请刷新页面后重试", "bot");
  }
});
