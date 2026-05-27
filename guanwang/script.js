const STORAGE_CONVERSATION = "yiku_site_conversation_id";
const STORAGE_USER = "yiku_site_user_id";
const WELCOME_MESSAGE = "你好，我是亿库 AI 客服。可以咨询产品适用场景、规格、报价方式和销售联系方式。";

const mobileToggle = document.getElementById("mobile-toggle");
const mobileNav = document.getElementById("mobile-nav");
const currentYear = document.getElementById("current-year");
const goTopButton = document.getElementById("go-top");
const sectionLinks = Array.from(document.querySelectorAll('a[href^="#"]'));
const navLinks = Array.from(document.querySelectorAll(".nav a"));

function setMobileOpen(isOpen) {
  if (!mobileToggle || !mobileNav) {
    return;
  }

  mobileToggle.setAttribute("aria-expanded", String(isOpen));
  mobileToggle.setAttribute("aria-label", isOpen ? "关闭菜单" : "打开菜单");
  mobileNav.hidden = !isOpen;
}

function smoothScrollTo(selector) {
  const target = document.querySelector(selector);
  if (!target) {
    return;
  }

  target.scrollIntoView({ behavior: "smooth", block: "start" });
}

function resolveApiUrl() {
  const host = window.location.hostname || "127.0.0.1";
  const isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787/api/ai/chat";
  }

  return "/api/ai/chat";
}

function resolveLeadUrl() {
  const host = window.location.hostname || "127.0.0.1";
  const isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787/api/ai/lead";
  }

  return "/api/ai/lead";
}

function resolveHandoffUrl() {
  const host = window.location.hostname || "127.0.0.1";
  const isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787/api/ai/handoff";
  }

  return "/api/ai/handoff";
}

function ensureStorageValue(key, prefix, length) {
  let value = localStorage.getItem(key);
  if (!value) {
    value = `${prefix}-${Math.random().toString(36).slice(2, length)}`;
    localStorage.setItem(key, value);
  }
  return value;
}

function createMessageRow(role, text) {
  const row = document.createElement("div");
  row.className = `chat-row chat-row-${role}`;

  const bubble = document.createElement("div");
  bubble.className = "chat-bubble";

  const paragraph = document.createElement("p");
  paragraph.textContent = text;

  bubble.appendChild(paragraph);
  row.appendChild(bubble);

  return row;
}

function initializeChatWidget(widget) {
  const launcher = widget.querySelector(".chat-launcher");
  const launcherText = widget.querySelector(".chat-launcher-text");
  const panel = widget.querySelector(".chat-panel");
  const body = widget.querySelector(".chat-body");
  const form = widget.querySelector(".chat-form");
  const input = form ? form.querySelector('input[name="draft"]') : null;
  const submitButton = form ? form.querySelector('button[type="submit"]') : null;
  const quickButtons = Array.from(widget.querySelectorAll("[data-quick]"));
  const conversationId = ensureStorageValue(STORAGE_CONVERSATION, "site", 14);
  const userId = ensureStorageValue(STORAGE_USER, "visitor", 12);
  const sessionId = "web-session-" + Math.random().toString(36).slice(2, 10);
  let chatHistory = [];
  let open = false;
  let loading = false;

  if (!launcher || !panel || !body || !form || !input || !submitButton) {
    return;
  }

  body.innerHTML = "";
  body.appendChild(createMessageRow("assistant", WELCOME_MESSAGE));

  function scrollToBottom() {
    body.scrollTop = body.scrollHeight;
  }

  function setOpen(nextOpen) {
    open = nextOpen;
    panel.hidden = !open;
    launcher.setAttribute("aria-expanded", String(open));
    launcherText.textContent = open ? "关闭咨询" : "在线咨询";
    if (open) {
      scrollToBottom();
      input.focus();
    }
  }

  function appendMessage(role, text) {
    body.appendChild(createMessageRow(role, text));
    scrollToBottom();
  }

  async function sendMessage(text) {
    if (!text || loading) {
      return;
    }

    loading = true;
    input.value = "";
    appendMessage("user", text);
    submitButton.disabled = true;
    submitButton.textContent = "发送中";

    chatHistory.push({ role: "user", text: text });

    try {
      const response = await fetch(resolveApiUrl(), {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          channel: "web",
          externalUserId: userId,
          conversationId: conversationId,
          sessionId: sessionId,
          question: text,
          history: chatHistory.slice(-12)
        })
      });

      const data = await response.json().catch(() => ({}));
      const answer = data.answer || data.channelPayload?.displayText || "暂时没有获取到回复。";
      chatHistory.push({ role: "assistant", text: answer });
      appendMessage("assistant", answer);

      // 仅当 AI 明确判断需转人工时才提示（报价/施工/合作类问题）
      if (data.handoff && (data.handoff.handoff_readiness === "high" || data.handoff.lead_capture_needed)) {
        appendMessage("assistant", "如需报价或人工跟进，请拨打 0779-8525688 / 18169771178，或留下您的联系方式。");
      }
    } catch (error) {
      appendMessage("assistant", "当前咨询服务暂时不可用，请稍后再试或直接拨打 0779-8525688。");
    } finally {
      loading = false;
      submitButton.disabled = false;
      submitButton.textContent = "发送";
    }
  }

  launcher.addEventListener("click", () => {
    setOpen(!open);
  });

  quickButtons.forEach((button) => {
    button.addEventListener("click", () => {
      setOpen(true);
      sendMessage(button.getAttribute("data-quick") || "");
    });
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    sendMessage(input.value.trim());
  });

  document.addEventListener("click", (event) => {
    if (!widget.contains(event.target)) {
      setOpen(false);
    }
  });
}

function updateActiveNav() {
  const sections = navLinks
    .map((link) => {
      const target = document.querySelector(link.getAttribute("href"));
      return target ? { link, target } : null;
    })
    .filter(Boolean);

  const marker = window.scrollY + 140;
  let activeLink = sections[0] ? sections[0].link : null;

  sections.forEach(({ link, target }) => {
    if (target.offsetTop <= marker) {
      activeLink = link;
    }
  });

  navLinks.forEach((link) => {
    link.classList.toggle("is-active", link === activeLink);
  });
}

if (currentYear) {
  currentYear.textContent = String(new Date().getFullYear());
}

if (mobileToggle && mobileNav) {
  mobileToggle.addEventListener("click", () => {
    setMobileOpen(mobileNav.hidden);
  });
}

sectionLinks.forEach((link) => {
  link.addEventListener("click", (event) => {
    const href = link.getAttribute("href");
    if (!href || href === "#") {
      return;
    }

    const target = document.querySelector(href);
    if (!target) {
      return;
    }

    event.preventDefault();
    smoothScrollTo(href);

    if (mobileNav && !mobileNav.hidden) {
      setMobileOpen(false);
    }
  });
});

document.querySelectorAll(".ai-chat").forEach((widget) => {
  initializeChatWidget(widget);
});

if (goTopButton) {
  goTopButton.addEventListener("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });
}

window.addEventListener("scroll", () => {
  if (goTopButton) {
    goTopButton.classList.toggle("is-visible", window.scrollY > 320);
  }
  updateActiveNav();
});

window.addEventListener("load", () => {
  updateActiveNav();
});
