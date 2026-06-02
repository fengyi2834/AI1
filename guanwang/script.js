var I = window.I18N;
var tt = function(k) { return I ? I.t(k) : k; };

var STORAGE_CONVERSATION = "yiku_site_conversation_id";
var STORAGE_USER = "yiku_site_user_id";
var STORAGE_AUTH_TOKEN = "yiku_auth_token";
var STORAGE_AUTH_USER = "yiku_auth_user";
var WELCOME_MESSAGE = tt('chat.welcome');

var mobileToggle = document.getElementById("mobile-toggle");
var mobileNav = document.getElementById("mobile-nav");
var currentYear = document.getElementById("current-year");
var goTopButton = document.getElementById("go-top");
var sectionLinks = Array.from(document.querySelectorAll('a[href^="#"]'));
var navLinks = Array.from(document.querySelectorAll(".nav a"));

function setMobileOpen(isOpen) {
  if (!mobileToggle || !mobileNav) {
    return;
  }

  mobileToggle.setAttribute("aria-expanded", String(isOpen));
  mobileToggle.setAttribute("aria-label", isOpen ? tt("mobile.close_menu") : tt("mobile.open_menu"));
  mobileNav.hidden = !isOpen;
}

function smoothScrollTo(selector) {
  var target = document.querySelector(selector);
  if (!target) {
    return;
  }

  target.scrollIntoView({ behavior: "smooth", block: "start" });
}

function resolveApiUrl() {
  var host = window.location.hostname || "127.0.0.1";
  var isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787/api/ai/chat";
  }

  return "/api/ai/chat";
}

function resolveLeadUrl() {
  var host = window.location.hostname || "127.0.0.1";
  var isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787/api/ai/lead";
  }

  return "/api/ai/lead";
}

function resolveHandoffUrl() {
  var host = window.location.hostname || "127.0.0.1";
  var isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787/api/ai/handoff";
  }

  return "/api/ai/handoff";
}

function resolveAuthBaseUrl() {
  var host = window.location.hostname || "127.0.0.1";
  var isLocalHost = host === "127.0.0.1" || host === "localhost" || window.location.protocol === "file:";

  if (isLocalHost) {
    return "http://127.0.0.1:8787";
  }

  return "";
}

function getAuthHeaders() {
  var token = localStorage.getItem(STORAGE_AUTH_TOKEN);
  var headers = { "Content-Type": "application/json" };
  if (token) {
    headers["Authorization"] = "Bearer " + token;
  }
  return headers;
}

function ensureStorageValue(key, prefix, length) {
  var value = localStorage.getItem(key);
  if (!value) {
    value = prefix + "-" + Math.random().toString(36).slice(2, length);
    localStorage.setItem(key, value);
  }
  return value;
}

function createMessageRow(role, text, imageUrl) {
  var row = document.createElement("div");
  row.className = "chat-row chat-row-" + role;

  var bubble = document.createElement("div");
  bubble.className = "chat-bubble";

  if (imageUrl) {
    var img = document.createElement("img");
    img.src = imageUrl;
    img.className = "chat-bubble-image";
    img.alt = tt("alt.chat_image");
    img.className = "chat-bubble-image";
    bubble.appendChild(img);
  }

  if (text) {
    var paragraph = document.createElement("p");
    paragraph.textContent = text;
    bubble.appendChild(paragraph);
  }

  row.appendChild(bubble);

  return row;
}

function initializeChatWidget(widget) {
  var launcher = widget.querySelector(".chat-launcher");
  var launcherText = widget.querySelector(".chat-launcher-text");
  var panel = widget.querySelector(".chat-panel");
  var body = widget.querySelector(".chat-body");
  var form = widget.querySelector(".chat-form");
  var input = form ? form.querySelector('input[name="draft"]') : null;
  var submitButton = form ? form.querySelector('button[type="submit"]') : null;
  var quickButtons = Array.from(widget.querySelectorAll("[data-quick]"));
  var hasAuth = !!localStorage.getItem(STORAGE_AUTH_TOKEN);
  var conversationId = hasAuth ? ensureStorageValue(STORAGE_CONVERSATION, "site", 14) : ("anon-" + Math.random().toString(36).slice(2, 14));
  var userId = hasAuth ? ensureStorageValue(STORAGE_USER, "visitor", 12) : ("anon-" + Math.random().toString(36).slice(2, 12));
  var sessionId = "web-session-" + Math.random().toString(36).slice(2, 10);
  var chatHistory = [];
  var open = false;
  var loading = false;
  var rateLimited = false;
  var currentImageDataUrl = null;
  var currentImageName = null;
  var imageInput = form.querySelector('.chat-image-input');
  var imageBtn = form.querySelector('.chat-image-btn');
  var imagePreview = form.querySelector('.chat-image-preview');
  var imagePreviewName = imagePreview ? imagePreview.querySelector('.chat-image-preview-name') : null;
  var imagePreviewRemove = imagePreview ? imagePreview.querySelector('.chat-image-preview-remove') : null;

  function clearImageSelection() {
    currentImageDataUrl = null;
    currentImageName = null;
    imageInput.value = '';
    imageBtn.classList.remove('has-image');
    if (imagePreview) imagePreview.hidden = true;
  }

  // ====== 多功能 "+" 菜单（表情/图片/转人工） ======
  var EMOJI_LIST = ['😀','😃','😄','😁','😅','😂','🤣','😊','😇','🙂','😉','😌','😍','🥰','😘','😋','😛','😝','🤪','😎','🤩','🥳','👍','👎','👏','🙌','💪','🤝','👌','✌️','❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','🔥','⭐','🌟','✨','💫','🎉','🎊','🎈','🎂','🎁','🏆','✅','❌','❓','❗','⚠️','💯','🔴','🟢','🔵','🙏','🤔','😷','🤒','💊','🏠','🏢','🏥','🏨','📞','📱','💻'];

  // 隐藏原始 label，创建独立的 "+" 按钮
  if (imageBtn) imageBtn.style.display = 'none';
  var plusBtn = document.createElement('button');
  plusBtn.type = 'button';
  plusBtn.textContent = '+';
  plusBtn.title = '更多功能';
  plusBtn.style.cssText = 'flex-shrink:0;min-width:26px;min-height:26px;width:26px;height:26px;border:1px solid rgba(47,122,79,0.18);border-radius:50%;background:#f6faf7;color:#5b846b;font-size:14px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;padding:0;line-height:1';
  // 插入到 input 前面
  if (input) input.parentNode.insertBefore(plusBtn, input);

  // 创建 "+" 弹出面板（竖排菜单）
  var plusMenu = document.createElement('div');
  plusMenu.style.cssText = 'display:none;position:absolute;bottom:50px;left:14px;background:#fff;border:1px solid #e8e8e8;border-radius:12px;padding:4px;box-shadow:0 -4px 24px rgba(0,0,0,0.08);z-index:1000';
  plusMenu.innerHTML = '' +
    '<div data-action="emoji" style="display:flex;align-items:center;gap:8px;cursor:pointer;padding:8px 12px;border-radius:8px;white-space:nowrap" onmouseover="this.style.background=\'#f5f5f5\'" onmouseout="this.style.background=\'transparent\'"><span style="font-size:16px">😊</span><span style="font-size:13px;color:#333">表情</span></div>' +
    '<div data-action="image" style="display:flex;align-items:center;gap:8px;cursor:pointer;padding:8px 12px;border-radius:8px;white-space:nowrap" onmouseover="this.style.background=\'#f5f5f5\'" onmouseout="this.style.background=\'transparent\'"><span style="font-size:16px">📷</span><span style="font-size:13px;color:#333">图片</span></div>' +
    '<div data-action="handoff" style="display:flex;align-items:center;gap:8px;cursor:pointer;padding:8px 12px;border-radius:8px;white-space:nowrap" onmouseover="this.style.background=\'#f5f5f5\'" onmouseout="this.style.background=\'transparent\'"><span style="font-size:16px">🎧</span><span style="font-size:13px;color:#e74c3c">转人工</span></div>';
  form.parentNode.insertBefore(plusMenu, form.nextSibling);

  // 创建表情面板
  var emojiPanel = document.createElement('div');
  emojiPanel.style.cssText = 'display:none;position:absolute;bottom:50px;right:12px;background:#fff;border:1px solid #e0e0e0;border-radius:12px;padding:8px;box-shadow:0 8px 24px rgba(0,0,0,0.12);z-index:999;width:300px;max-height:220px;overflow-y:auto';
  emojiPanel.innerHTML = '<div style="display:grid;grid-template-columns:repeat(10,1fr);gap:4px">' + EMOJI_LIST.map(function(e) { return '<span style="cursor:pointer;font-size:18px;padding:4px;text-align:center;border-radius:4px" onmouseover="this.style.background=\"#f0f0f0\"}" onmouseout="this.style.background=\"none\"">' + e + '</span>'; }).join('') + '</div>';
  form.parentNode.insertBefore(emojiPanel, form.nextSibling);

  // "+" 按钮点击 → 切换菜单
  plusBtn.addEventListener('click', function(ev) { ev.stopPropagation(); plusMenu.style.display = plusMenu.style.display === 'none' ? 'block' : 'none'; });

  // 菜单选项点击
  plusMenu.addEventListener('click', function(ev) {
    var item = ev.target.closest('[data-action]');
    if (!item) return;
    var action = item.getAttribute('data-action');
    plusMenu.style.display = 'none';
    if (action === 'emoji') { emojiPanel.style.display = 'block'; }
    else if (action === 'image') { if (imageInput) imageInput.click(); }
    else if (action === 'handoff') { triggerHandoff(); }
  });

  // emoji 面板点击 → 插入表情
  emojiPanel.addEventListener('click', function(ev) {
    var span = ev.target.closest('span'); if (!span) return;
    var e = span.textContent.trim(), v = input.value, s = input.selectionStart || v.length;
    input.value = v.substring(0, s) + e + v.substring(s); input.selectionStart = input.selectionEnd = s + e.length;
    input.focus(); emojiPanel.style.display = 'none';
  });

  // 点击外部关闭所有弹窗
  document.addEventListener('click', function(ev) {
    if (!plusMenu.contains(ev.target) && ev.target !== plusBtn) plusMenu.style.display = 'none';
    if (!emojiPanel.contains(ev.target) && !plusMenu.contains(ev.target) && ev.target !== plusBtn) emojiPanel.style.display = 'none';
  });

  // ====== 转人工逻辑 ======
  var handoffActive = false, handoffId = '';

  async function triggerHandoff() {
    if (handoffActive) return;
    try {
      // 收集聊天记录（含图片）带给坐席
      var historyForHandoff = [];
      var rows = body.querySelectorAll('.chat-row');
      rows.forEach(function(row) {
        var bubble = row.querySelector('.chat-bubble');
        var img = row.querySelector('.chat-bubble-image');
        var p = bubble ? bubble.querySelector('p') : null;
        if (img || p) {
          historyForHandoff.push({
            role: row.classList.contains('chat-row-user') ? 'user' : 'assistant',
            text: p ? p.textContent : '',
            imageUrl: img ? img.src : ''
          });
        }
      });
      var res = await fetch(resolveApiUrl().replace('/api/ai/chat', '/api/ai/handoff'), {
        method: 'POST', headers: getAuthHeaders(),
        body: JSON.stringify({ userId: userId, conversationId: conversationId, reason: '客户请求转人工', history: historyForHandoff })
      });
      var data = await res.json().catch(function(){ return {} });
      if (data.ok) {
        handoffId = data.handoffId; handoffActive = true;
        appendMessage('assistant', data.message || '已通知顾问，请稍候');
        pollHandoffMessages();
      } else if (data.offline) {
        appendMessage('assistant', data.message || '顾问当前不在线');
      } else {
        appendMessage('assistant', '转人工失败，请拨打电话 0779-8525688');
      }
    } catch(e) {}
  }

  async function pollHandoffMessages() {
    if (!handoffId || !handoffActive) return;
    try {
      var res = await fetch('/api/ai/handoff-status?id=' + handoffId); var data = await res.json();
      if (data.ok && data.status === 'active') {
        var seen = []; body.querySelectorAll('.chat-row-agent .chat-bubble').forEach(function(b){ seen.push(b.textContent.trim()); });
        (data.messages || []).forEach(function(m) {
          if (m.role !== 'agent') return;
          var dedupKey = m.imageUrl || m.text.trim();
          if (seen.indexOf(dedupKey) !== -1) return;
          seen.push(dedupKey);
          var label = m.text ? '【顾问】' + m.text : '【顾问】';
          appendMessage('assistant', label, m.imageUrl);
        });
      }
      if (data.status === 'completed') { handoffActive = false; appendMessage('assistant', '顾问已结束会话，可再次转人工或拨打电话 0779-8525688。'); return; }
    } catch(e) {}
    if (handoffActive) setTimeout(pollHandoffMessages, 3000);
  }

  if (!launcher || !panel || !body || !form || !input || !submitButton || !imageInput) {
    return;
  }

  imageInput.addEventListener('change', function () {
    var file = imageInput.files[0];
    if (!file) return;

    var allowedTypes = ['image/png', 'image/jpeg', 'image/webp'];
    if (allowedTypes.indexOf(file.type) === -1) {
      alert(tt('img.unsupported_format'));
      imageInput.value = '';
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      alert(tt('img.too_large'));
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
    if (launcherText) {
      launcherText.textContent = open ? tt("chat.close_chat") : tt("chat.online_chat");
    }
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
    if (panel.querySelector(".chat-login-banner")) {
      return;
    }

    var banner = document.createElement("div");
    banner.className = "chat-login-banner";

    var msg = document.createElement("p");
    msg.textContent = tt("chat.free_used");
    msg.className = "chat-login-banner-text";

    var action = document.createElement("p");
    action.textContent = tt("chat.please_login");
    action.className = "chat-login-banner-action";

    var loginBtn = document.createElement("a");
    loginBtn.href = "#";
    loginBtn.className = "chat-login-banner-btn";
    loginBtn.textContent = tt("chat.login_register");
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
    appendMessage("user", text || tt("chat.image_sent"), currentImageDataUrl);
    submitButton.disabled = true;
    submitButton.textContent = tt("chat.sending");

    chatHistory.push({ role: "user", text: text || "" });

    try {
      // 转人工模式：消息发给坐席而不是 AI
      if (handoffActive && handoffId) {
        await fetch('/api/ai/handoff-message', {
          method: 'POST',
          headers: getAuthHeaders(),
          body: JSON.stringify({
            handoffId: handoffId,
            text: text || '',
            imageDataUrl: imageDataToSend || undefined,
            imageName: imageNameToSend || undefined
          })
        });
        loading = false;
        submitButton.disabled = false;
        submitButton.textContent = tt("chat.send");
        clearImageSelection();
        return;
      }

      var response = await fetch(resolveApiUrl(), {
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

      var data = await response.json().catch(function() { return {}; });

      if (data.error === "login_required") {
        rateLimited = true;
        appendMessage("assistant", data.message || tt("chat.free_used"));
        showLoginBanner(panel, form);
        input.disabled = true;
        submitButton.disabled = true;
        submitButton.textContent = tt("chat.locked");
        loading = false;
        clearImageSelection();
        return;
      }

      var answer = data.answer || data.channelPayload ? (data.channelPayload && data.channelPayload.displayText) || tt("chat.no_reply") : tt("chat.no_reply");
      if (data.answer) answer = data.answer;
      else if (data.channelPayload && data.channelPayload.displayText) answer = data.channelPayload.displayText;
      else answer = tt("chat.no_reply");
      chatHistory.push({ role: "assistant", text: answer });
      appendMessage("assistant", answer);

      if (data.handoff && (data.handoff.handoff_readiness === "high" || data.handoff.lead_capture_needed)) {
        appendMessage("assistant", tt("chat.handoff"));
      }
    } catch (error) {
      appendMessage("assistant", tt("chat.service_unavailable"));
    } finally {
      loading = false;
      submitButton.disabled = false;
      submitButton.textContent = tt("chat.send");
      clearImageSelection();
    }
  }

  launcher.addEventListener("click", function() {
    if (window.innerWidth < 768) {
      window.location.href = "/chat.html?lang=" + (I ? I.getLang() : 'zh-CN');
      return;
    }
    setOpen(!open);
  });

  quickButtons.forEach(function(button) {
    button.addEventListener("click", function() {
      if (window.innerWidth < 768) {
        window.location.href = "/chat.html?lang=" + (I ? I.getLang() : 'zh-CN') + "&q=" + encodeURIComponent(button.getAttribute("data-quick") || "");
        return;
      }
      setOpen(true);
      sendMessage(button.getAttribute("data-quick") || "");
    });
  });

  form.addEventListener("submit", function(event) {
    event.preventDefault();
    sendMessage(input.value.trim());
  });

  document.addEventListener("click", function(event) {
    if (!widget.contains(event.target)) {
      setOpen(false);
    }
  });

  document.addEventListener("auth-login-success", function() {
    var banner = panel.querySelector(".chat-login-banner");
    if (banner) banner.remove();
    rateLimited = false;
    input.disabled = false;
    submitButton.disabled = false;
    submitButton.textContent = tt("chat.send");
  });
}

function updateActiveNav() {
  var sections = navLinks
    .map(function(link) {
      var target = document.querySelector(link.getAttribute("href"));
      return target ? { link: link, target: target } : null;
    })
    .filter(Boolean);

  var marker = window.scrollY + 140;
  var activeLink = sections[0] ? sections[0].link : null;

  sections.forEach(function(s) {
    if (s.target.offsetTop <= marker) {
      activeLink = s.link;
    }
  });

  navLinks.forEach(function(link) {
    link.classList.toggle("is-active", link === activeLink);
  });
}

if (currentYear) {
  currentYear.textContent = String(new Date().getFullYear());
}

if (mobileToggle && mobileNav) {
  mobileToggle.addEventListener("click", function() {
    setMobileOpen(mobileNav.hidden);
  });

  var menuOpenedAt = 0;
  var scrollAnchor = 0;
  var origSetMobileOpen = setMobileOpen;
  setMobileOpen = function(v) {
    origSetMobileOpen(v);
    if (v) { menuOpenedAt = Date.now(); scrollAnchor = window.scrollY; }
  };

  window.addEventListener("scroll", function() {
    if (!mobileNav.hidden && Date.now() - menuOpenedAt > 300 && Math.abs(window.scrollY - scrollAnchor) > 60) {
      setMobileOpen(false);
    }
  }, { passive: true });
}

sectionLinks.forEach(function(link) {
  link.addEventListener("click", function(event) {
    var href = link.getAttribute("href");
    if (!href || href === "#") {
      return;
    }

    var target = document.querySelector(href);
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

document.querySelectorAll(".ai-chat").forEach(function(widget) {
  initializeChatWidget(widget);
});

if (goTopButton) {
  goTopButton.addEventListener("click", function() {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });
}

window.addEventListener("scroll", function() {
  if (goTopButton) {
    goTopButton.classList.toggle("is-visible", window.scrollY > 320);
  }
  updateActiveNav();
});

window.addEventListener("load", function() {
  updateActiveNav();
});

/* ====== Update chat.html links with current lang ====== */
function updateChatLinks() {
  var links = document.querySelectorAll('a[data-chat-link], a[href*="chat.html"]');
  for (var i = 0; i < links.length; i++) {
    var el = links[i];
    var baseHref = (el.getAttribute('href') || './chat.html').split('?')[0];
    el.setAttribute('href', baseHref + '?lang=' + (I ? I.getLang() : 'zh-CN'));
  }
}
updateChatLinks();

/* ====== Auth Modal ====== */
(function initAuth() {
  var modalHtml =
    '<div id="auth-overlay" class="auth-overlay" hidden>' +
      '<div class="auth-overlay-backdrop"></div>' +
      '<div class="auth-dialog">' +
        '<button class="auth-dialog-close" type="button">&times;</button>' +
        '<div class="auth-tabs">' +
          '<button class="auth-tab is-active" data-auth-tab="login" data-i18n="auth.login">登录</button>' +
          '<button class="auth-tab" data-auth-tab="register" data-i18n="auth.register">注册</button>' +
        '</div>' +
        '<form id="auth-form-login" class="auth-form">' +
          '<input name="email" type="email" placeholder="邮箱" required autocomplete="email" data-i18n-placeholder="auth.email">' +
          '<input name="password" type="password" placeholder="密码" required minlength="6" autocomplete="current-password" data-i18n-placeholder="auth.password">' +
          '<button type="submit" data-i18n="auth.login">登录</button>' +
        '</form>' +
        '<p class="auth-forgot"><a id="auth-forgot-link" href="javascript:;" data-i18n="auth.forgot_password">忘记密码？</a></p>' +
        '<form id="auth-form-register" class="auth-form" hidden>' +
          '<input name="email" type="email" placeholder="邮箱" required autocomplete="email" data-i18n-placeholder="auth.email">' +
          '<input name="password" type="password" placeholder="密码（至少 6 位）" required minlength="6" data-i18n-placeholder="auth.password_hint">' +
          '<input name="nickname" type="text" placeholder="昵称（选填）" data-i18n-placeholder="auth.nickname">' +
          '<button type="submit" data-i18n="auth.get_code">获取验证码</button>' +
        '</form>' +
        '<form id="auth-form-verify" class="auth-form" hidden>' +
          '<p class="auth-verify-hint" data-i18n="auth.code_sent_full">验证码已发送至您的邮箱，10分钟内有效</p>' +
          '<p class="auth-verify-hint auth-verify-spam" data-i18n="auth.check_spam">如未收到请检查垃圾邮件箱</p>' +
          '<input name="code" type="text" placeholder="6 位验证码" required pattern="[0-9]{6}" maxlength="6" inputmode="numeric" autocomplete="one-time-code" data-i18n-placeholder="auth.code_placeholder">' +
          '<button type="submit" data-i18n="auth.verify_activate">验证并激活</button>' +
        '</form>' +
        '<form id="auth-form-forgot" class="auth-form" hidden>' +
          '<p class="auth-verify-hint" data-i18n="auth.enter_email">输入注册邮箱，我们将发送重置验证码</p>' +
          '<input name="email" type="email" placeholder="注册邮箱" required autocomplete="email" data-i18n-placeholder="auth.email">' +
          '<button type="submit" data-i18n="auth.get_code">获取重置验证码</button>' +
        '</form>' +
        '<form id="auth-form-reset" class="auth-form" hidden>' +
          '<p class="auth-verify-hint"><span data-i18n="auth.reset_code_sent">重置验证码已发送至</span> <strong id="auth-reset-target"></strong></p>' +
          '<input name="code" type="text" placeholder="6 位验证码" required pattern="[0-9]{6}" maxlength="6" inputmode="numeric" autocomplete="one-time-code" data-i18n-placeholder="auth.code_placeholder">' +
          '<input name="newPassword" type="password" placeholder="新密码（至少 6 位）" required minlength="6" data-i18n-placeholder="auth.new_password">' +
          '<button type="submit" data-i18n="auth.reset_password_btn">重置密码</button>' +
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
  var forgotForm = document.getElementById("auth-form-forgot");
  var resetForm = document.getElementById("auth-form-reset");
  var forgotLink = document.getElementById("auth-forgot-link");
  var resetTarget = document.getElementById("auth-reset-target");
  var tabButtons = Array.from(overlay.querySelectorAll("[data-auth-tab]"));
  var closeBtn = overlay.querySelector(".auth-dialog-close");
  var backdrop = overlay.querySelector(".auth-overlay-backdrop");
  var pendingEmail = "";
  var pendingForgotEmail = "";

  /* Apply i18n to the newly inserted auth modal */
  if (I) I.apply();

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
        btn.textContent = user.nickname || user.email || tt("auth.logged_in");
        btn.title = tt("auth.logout_confirm");
        btn.classList.add("is-logged-in");
      } else {
        btn.textContent = tt("auth.login");
        btn.title = tt("auth.login_register") || tt("chat.login_register");
        btn.classList.remove("is-logged-in");
      }
    });
  }

  tabButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      switchTab(btn.getAttribute("data-auth-tab"));
    });
  });

  closeBtn.addEventListener("click", hideOverlay);
  backdrop.addEventListener("click", hideOverlay);

  document.addEventListener("click", function (e) {
    var btn = e.target.closest(".chat-auth-btn");
    if (!btn) return;
    if (btn.classList.contains("is-logged-in")) {
      if (confirm(tt("auth.logout_confirm"))) {
        logout();
      }
    } else {
      showOverlay();
    }
  });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !overlay.hidden) {
      hideOverlay();
    }
  });

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
          showError(data.message || tt("auth.login_failed"));
        }
      })
      .catch(function () {
        showError(tt("auth.network_error"));
      });
  });

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
          registerForm.hidden = true;
          verifyForm.hidden = false;
          loginForm.hidden = true;
        } else {
          showError(data.message || tt("auth.register_failed"));
        }
      })
      .catch(function () {
        showError(tt("auth.network_error"));
      });
  });

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
          showError(data.message || tt("auth.verify_failed"));
        }
      })
      .catch(function () {
        showError(tt("auth.network_error"));
      });
  });

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
          showError(data.message || tt("auth.send_failed"));
        }
      })
      .catch(function () { showError(tt("auth.network_error")); });
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
          alert(tt("auth.password_reset_ok"));
          switchTab("login");
          forgotForm.reset();
          resetForm.reset();
        } else {
          showError(data.message || tt("auth.reset_failed"));
        }
      })
      .catch(function () { showError(tt("auth.network_error")); });
  });

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
