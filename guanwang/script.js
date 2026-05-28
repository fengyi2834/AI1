const STORAGE_CONVERSATION = "yiku_site_conversation_id";
const STORAGE_USER = "yiku_site_user_id";
const STORAGE_AUTH_TOKEN = "yiku_auth_token";
const STORAGE_AUTH_USER = "yiku_auth_user";
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

function resolveAuthBaseUrl() {
  const host = window.location.hostname || "127.0.0.1";
  const isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787";
  }

  return "";
}

function getAuthHeaders() {
  const token = localStorage.getItem(STORAGE_AUTH_TOKEN);
  const headers = { "Content-Type": "application/json" };
  if (token) {
    headers["Authorization"] = "Bearer " + token;
  }
  return headers;
}

function ensureStorageValue(key, prefix, length) {
  let value = localStorage.getItem(key);
  if (!value) {
    value = `${prefix}-${Math.random().toString(36).slice(2, length)}`;
    localStorage.setItem(key, value);
  }
  return value;
}

function createMessageRow(role, text, imageUrl) {
  const row = document.createElement("div");
  row.className = `chat-row chat-row-${role}`;

  const bubble = document.createElement("div");
  bubble.className = "chat-bubble";

  if (imageUrl) {
    const img = document.createElement("img");
    img.src = imageUrl;
    img.className = "chat-bubble-image";
    img.alt = "发送的图片";
    img.style.cssText = "max-width:200px;max-height:200px;border-radius:12px;display:block;margin-bottom:8px;";
    bubble.appendChild(img);
  }

  if (text) {
    const paragraph = document.createElement("p");
    paragraph.textContent = text;
    bubble.appendChild(paragraph);
  }

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
  const hasAuth = !!localStorage.getItem(STORAGE_AUTH_TOKEN);
  const conversationId = hasAuth ? ensureStorageValue(STORAGE_CONVERSATION, "site", 14) : ("anon-" + Math.random().toString(36).slice(2, 14));
  const userId = hasAuth ? ensureStorageValue(STORAGE_USER, "visitor", 12) : ("anon-" + Math.random().toString(36).slice(2, 12));
  const sessionId = "web-session-" + Math.random().toString(36).slice(2, 10);
  let chatHistory = [];
  let open = false;
  let loading = false;
  let rateLimited = false;
  let currentImageDataUrl = null;
  let currentImageName = null;
  const imageInput = form.querySelector('.chat-image-input');
  const imageBtn = form.querySelector('.chat-image-btn');
  const imagePreview = form.querySelector('.chat-image-preview');
  const imagePreviewName = imagePreview ? imagePreview.querySelector('.chat-image-preview-name') : null;
  const imagePreviewRemove = imagePreview ? imagePreview.querySelector('.chat-image-preview-remove') : null;

  function clearImageSelection() {
    currentImageDataUrl = null;
    currentImageName = null;
    imageInput.value = '';
    imageBtn.classList.remove('has-image');
    if (imagePreview) imagePreview.hidden = true;
  }

  if (!launcher || !panel || !body || !form || !input || !submitButton || !imageInput) {
    return;
  }

  imageInput.addEventListener('change', function () {
    var file = imageInput.files[0];
    if (!file) return;

    var allowedTypes = ['image/png', 'image/jpeg', 'image/webp'];
    if (allowedTypes.indexOf(file.type) === -1) {
      alert('仅支持 PNG、JPEG、WebP 格式的图片');
      imageInput.value = '';
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      alert('图片大小不能超过 10MB');
      imageInput.value = '';
      return;
    }

    var reader = new FileReader();
    reader.onload = function () {
      currentImageDataUrl = reader.result;
      currentImageName = file.name;
      imageBtn.classList.add('has-image');
      if (imagePreviewName) imagePreviewName.textContent = file.name;
      if (imagePreview) imagePreview.hidden = false;
      input.focus();
    };
    reader.readAsDataURL(file);
  });

  if (imagePreviewRemove) {
    imagePreviewRemove.addEventListener('click', function () {
      clearImageSelection();
    });
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

  function appendMessage(role, text, imageUrl) {
    body.appendChild(createMessageRow(role, text, imageUrl));
    scrollToBottom();
  }

  function showLoginBanner(panel, form) {
    // 避免重复添加
    if (panel.querySelector(".chat-login-banner")) {
      return;
    }

    const banner = document.createElement("div");
    banner.className = "chat-login-banner";

    const msg = document.createElement("p");
    msg.textContent = "免费咨询次数已用完";
    msg.className = "chat-login-banner-text";

    const action = document.createElement("p");
    action.textContent = "请登录后继续咨询";
    action.className = "chat-login-banner-action";

    const loginBtn = document.createElement("a");
    loginBtn.href = "#";
    loginBtn.className = "chat-login-banner-btn";
    loginBtn.textContent = "登录 / 注册";
    loginBtn.addEventListener("click", function (e) {
      e.preventDefault();
      var authOverlay = document.getElementById("auth-overlay");
      if (authOverlay) {
        authOverlay.hidden = false;
      }
    });

    banner.appendChild(msg);
    banner.appendChild(action);
    banner.appendChild(loginBtn);

    // 插入到表单位置之前
    panel.insertBefore(banner, form);
  }

  async function sendMessage(text) {
    if (rateLimited) {
      return;
    }

    if ((!text && !currentImageDataUrl) || loading) {
      return;
    }

    loading = true;
    var imageDataToSend = currentImageDataUrl;
    var imageNameToSend = currentImageName;
    input.value = "";
    appendMessage("user", text || "发送了一张图片", currentImageDataUrl);
    submitButton.disabled = true;
    submitButton.textContent = "发送中";

    chatHistory.push({ role: "user", text: text || "" });

    try {
      const response = await fetch(resolveApiUrl(), {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          channel: "web",
          externalUserId: userId,
          conversationId: conversationId,
          sessionId: sessionId,
          question: text,
          history: chatHistory.slice(-12),
          imageDataUrl: imageDataToSend || undefined,
          imageName: imageNameToSend || undefined
        })
      });

      const data = await response.json().catch(() => ({}));

      // 检查是否需要登录（设备限流触发）
      if (data.error === "login_required") {
        rateLimited = true;
        appendMessage("assistant", data.message || "免费咨询次数已用完，请登录后继续");
        showLoginBanner(panel, form);
        input.disabled = true;
        submitButton.disabled = true;
        submitButton.textContent = "已锁定";
        loading = false;
        clearImageSelection();
        return;
      }

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
      clearImageSelection();
    }
  }

  launcher.addEventListener("click", () => {
    if (window.innerWidth < 768) {
      window.location.href = "/chat.html";
      return;
    }
    setOpen(!open);
  });

  quickButtons.forEach((button) => {
    button.addEventListener("click", () => {
      if (window.innerWidth < 768) {
        window.location.href = "/chat.html?q=" + encodeURIComponent(button.getAttribute("data-quick") || "");
        return;
      }
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

  document.addEventListener("auth-login-success", () => {
    var banner = panel.querySelector(".chat-login-banner");
    if (banner) banner.remove();
    rateLimited = false;
    input.disabled = false;
    submitButton.disabled = false;
    submitButton.textContent = "发送";
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

  // 滚动超过一屏后自动收起菜单
  let scrollSinceOpen = 0;
  window.addEventListener("scroll", () => {
    if (!mobileNav.hidden) {
      scrollSinceOpen += Math.abs(window.scrollY - (scrollSinceOpen > 0 ? window.scrollY : 0));
      if (window.scrollY > 400) {
        setMobileOpen(false);
      }
    }
  }, { passive: true });
  mobileToggle.addEventListener("click", () => {
    scrollSinceOpen = 0;
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

// ====== Auth Modal ======
(function initAuth() {
  var modalHtml =
    '<div id="auth-overlay" class="auth-overlay" hidden>' +
      '<div class="auth-overlay-backdrop"></div>' +
      '<div class="auth-dialog">' +
        '<button class="auth-dialog-close" type="button">&times;</button>' +
        '<div class="auth-tabs">' +
          '<button class="auth-tab is-active" data-auth-tab="login">登录</button>' +
          '<button class="auth-tab" data-auth-tab="register">注册</button>' +
        '</div>' +
        '<form id="auth-form-login" class="auth-form">' +
          '<input name="email" type="email" placeholder="邮箱" required autocomplete="email">' +
          '<input name="password" type="password" placeholder="密码" required minlength="6" autocomplete="current-password">' +
          '<button type="submit">登录</button>' +
        '</form>' +
        '<p class="auth-forgot"><a id="auth-forgot-link" href="javascript:;">忘记密码？</a></p>' +
        '<form id="auth-form-register" class="auth-form" hidden>' +
          '<input name="email" type="email" placeholder="邮箱" required autocomplete="email">' +
          '<input name="password" type="password" placeholder="密码（至少 6 位）" required minlength="6">' +
          '<input name="nickname" type="text" placeholder="昵称（选填）">' +
          '<button type="submit">获取验证码</button>' +
        '</form>' +
        '<form id="auth-form-verify" class="auth-form" hidden>' +
          '<p class="auth-verify-hint">验证码已发送至 <strong id="auth-verify-target"></strong></p>' +
          '<p class="auth-verify-hint">验证码已发送至您的邮箱，10分钟内有效</p>' +
          '<p class="auth-verify-hint auth-verify-spam">如未收到请检查垃圾邮件箱</p>' +
          '<input name="code" type="text" placeholder="6 位验证码" required pattern="[0-9]{6}" maxlength="6" inputmode="numeric" autocomplete="one-time-code">' +
          '<button type="submit">验证并激活</button>' +
        '</form>' +
        '<form id="auth-form-forgot" class="auth-form" hidden>' +
          '<p class="auth-verify-hint">输入注册邮箱，我们将发送重置验证码</p>' +
          '<input name="email" type="email" placeholder="注册邮箱" required autocomplete="email">' +
          '<button type="submit">获取重置验证码</button>' +
        '</form>' +
        '<form id="auth-form-reset" class="auth-form" hidden>' +
          '<p class="auth-verify-hint">重置验证码已发送至 <strong id="auth-reset-target"></strong></p>' +
          '<input name="code" type="text" placeholder="6 位验证码" required pattern="[0-9]{6}" maxlength="6" inputmode="numeric" autocomplete="one-time-code">' +
          '<input name="newPassword" type="password" placeholder="新密码（至少 6 位）" required minlength="6">' +
          '<button type="submit">重置密码</button>' +
        '</form>' +
        '<p class="auth-error" id="auth-error-msg" hidden></p>' +
      '</div>' +
    '</div>';

  document.body.insertAdjacentHTML("beforeend", modalHtml);

  var overlay = document.getElementById("auth-overlay");
  var loginForm = document.getElementById("auth-form-login");
  var registerForm = document.getElementById("auth-form-register");
  var verifyForm = document.getElementById("auth-form-verify");
  var errorEl = document.getElementById("auth-error-msg");
  var verifyTarget = document.getElementById("auth-verify-target");
  var forgotForm = document.getElementById("auth-form-forgot");
  var resetForm = document.getElementById("auth-form-reset");
  var forgotLink = document.getElementById("auth-forgot-link");
  var resetTarget = document.getElementById("auth-reset-target");
  var tabButtons = Array.from(overlay.querySelectorAll("[data-auth-tab]"));
  var closeBtn = overlay.querySelector(".auth-dialog-close");
  var backdrop = overlay.querySelector(".auth-overlay-backdrop");
  var pendingEmail = "";
  var pendingForgotEmail = "";

  function showError(msg) {
    errorEl.textContent = msg;
    errorEl.hidden = false;
  }

  function clearError() {
    errorEl.textContent = "";
    errorEl.hidden = true;
  }

  function showOverlay() {
    overlay.hidden = false;
    clearError();
    loginForm.reset();
    registerForm.reset();
    verifyForm.reset();
    forgotForm.reset();
    resetForm.reset();
  }

  function hideOverlay() {
    overlay.hidden = true;
    clearError();
    tabButtons.forEach(function (btn) {
      btn.classList.toggle("is-active", btn.getAttribute("data-auth-tab") === "login");
    });
    loginForm.hidden = false;
    registerForm.hidden = true;
    verifyForm.hidden = true;
    forgotForm.hidden = true;
    resetForm.hidden = true;
    forgotLink.style.display = "";
  }

  function switchTab(tabName) {
    clearError();
    tabButtons.forEach(function (btn) {
      btn.classList.toggle("is-active", btn.getAttribute("data-auth-tab") === tabName);
    });
    loginForm.hidden = tabName !== "login";
    registerForm.hidden = tabName !== "register";
    verifyForm.hidden = true;
    forgotForm.hidden = true;
    resetForm.hidden = true;
    forgotLink.style.display = tabName === "login" ? "" : "none";
  }

  function saveAuth(token, user) {
    localStorage.setItem(STORAGE_AUTH_TOKEN, token);
    localStorage.setItem(STORAGE_AUTH_USER, JSON.stringify(user));
    updateAuthButtons();
    hideOverlay();
    document.dispatchEvent(new CustomEvent("auth-login-success"));
  }

  function logout() {
    localStorage.removeItem(STORAGE_AUTH_TOKEN);
    localStorage.removeItem(STORAGE_AUTH_USER);
    updateAuthButtons();
  }

  function getLoggedInUser() {
    var raw = localStorage.getItem(STORAGE_AUTH_USER);
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  function updateAuthButtons() {
    var user = getLoggedInUser();
    var buttons = document.querySelectorAll(".chat-auth-btn");
    buttons.forEach(function (btn) {
      if (user) {
        btn.textContent = user.nickname || user.email || "已登录";
        btn.title = "点击退出登录";
        btn.classList.add("is-logged-in");
      } else {
        btn.textContent = "登录";
        btn.title = "登录 / 注册";
        btn.classList.remove("is-logged-in");
      }
    });
  }

  // Tab switching
  tabButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      switchTab(btn.getAttribute("data-auth-tab"));
    });
  });

  // Close handlers
  closeBtn.addEventListener("click", hideOverlay);
  backdrop.addEventListener("click", hideOverlay);

  // Auth button click - toggle login/logout
  document.addEventListener("click", function (e) {
    var btn = e.target.closest(".chat-auth-btn");
    if (!btn) return;
    if (btn.classList.contains("is-logged-in")) {
      if (confirm("确定要退出登录吗？")) {
        logout();
      }
    } else {
      showOverlay();
    }
  });

  // Escape key to close
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !overlay.hidden) {
      hideOverlay();
    }
  });

  // Login form submit
  loginForm.addEventListener("submit", function (e) {
    e.preventDefault();
    clearError();
    var email = loginForm.querySelector('[name="email"]').value.trim();
    var password = loginForm.querySelector('[name="password"]').value;
    var baseUrl = resolveAuthBaseUrl();

    fetch(baseUrl + "/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: email, password: password })
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.ok) {
          saveAuth(data.token, data.user);
        } else {
          showError(data.message || "登录失败");
        }
      })
      .catch(function () {
        showError("网络错误，请稍后重试");
      });
  });

  // Register form submit
  registerForm.addEventListener("submit", function (e) {
    e.preventDefault();
    clearError();
    var email = registerForm.querySelector('[name="email"]').value.trim();
    var password = registerForm.querySelector('[name="password"]').value;
    var nickname = registerForm.querySelector('[name="nickname"]').value.trim();
    var baseUrl = resolveAuthBaseUrl();

    fetch(baseUrl + "/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: email, password: password, nickname: nickname || undefined })
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.ok) {
          pendingEmail = email;
          verifyTarget.textContent = email;
          registerForm.hidden = true;
          verifyForm.hidden = false;
          loginForm.hidden = true;
        } else {
          showError(data.message || "注册失败");
        }
      })
      .catch(function () {
        showError("网络错误，请稍后重试");
      });
  });

  // Verify form submit
  verifyForm.addEventListener("submit", function (e) {
    e.preventDefault();
    clearError();
    var code = verifyForm.querySelector('[name="code"]').value.trim();
    var baseUrl = resolveAuthBaseUrl();

    fetch(baseUrl + "/api/auth/verify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: pendingEmail, code: code })
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.ok) {
          saveAuth(data.token, data.user);
        } else {
          showError(data.message || "验证失败");
        }
      })
      .catch(function () {
        showError("网络错误，请稍后重试");
      });
  });

  // Forgot password link
  forgotLink.addEventListener("click", function (e) {
    e.preventDefault();
    switchTab("");
    tabButtons.forEach(function (btn) { btn.classList.remove("is-active"); });
    loginForm.hidden = true;
    registerForm.hidden = true;
    verifyForm.hidden = true;
    forgotForm.hidden = false;
    resetForm.hidden = true;
    forgotLink.style.display = "none";
    clearError();
  });

  forgotForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var email = (forgotForm.querySelector('[name=email]') || {}).value;
    if (!email) return;
    pendingForgotEmail = email.trim();
    fetch(resolveAuthBaseUrl() + "/api/auth/forgot", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: pendingForgotEmail })
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.ok) {
          resetTarget.textContent = pendingForgotEmail;
          forgotForm.hidden = true;
          resetForm.hidden = false;
          clearError();
        } else {
          showError(data.message || "发送失败");
        }
      })
      .catch(function () { showError("网络错误，请稍后重试"); });
  });

  resetForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var code = (resetForm.querySelector('[name=code]') || {}).value;
    var newPw = (resetForm.querySelector('[name=newPassword]') || {}).value;
    if (!code || !newPw) return;
    fetch(resolveAuthBaseUrl() + "/api/auth/reset-password", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: pendingForgotEmail, code: code.trim(), newPassword: newPw })
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.ok) {
          clearError();
          alert("密码已重置，请用新密码登录");
          switchTab("login");
          forgotForm.reset();
          resetForm.reset();
        } else {
          showError(data.message || "重置失败");
        }
      })
      .catch(function () { showError("网络错误，请稍后重试"); });
  });

  // Check existing auth on page load
  (function checkExistingAuth() {
    var token = localStorage.getItem(STORAGE_AUTH_TOKEN);
    if (!token) {
      updateAuthButtons();
      return;
    }
    var baseUrl = resolveAuthBaseUrl();
    fetch(baseUrl + "/api/auth/me", {
      headers: { "Authorization": "Bearer " + token }
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.ok) {
          localStorage.setItem(STORAGE_AUTH_USER, JSON.stringify(data.user));
        } else {
          localStorage.removeItem(STORAGE_AUTH_TOKEN);
          localStorage.removeItem(STORAGE_AUTH_USER);
        }
        updateAuthButtons();
      })
      .catch(function () {
        updateAuthButtons();
      });
  })();
})();
