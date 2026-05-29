/**
 * 亿库 AI 客服 — 并发压力测试工具
 *
 * 用法:
 *   node scripts/stress-test.js --mode mock    # Mock 模式（不烧钱，测自身服务）
 *   node scripts/stress-test.js --mode real    # 真实模式（走 AI API，需确认）
 *
 * 可选参数:
 *   --concurrency 10   并发用户数（默认 10）
 *   --duration 300     持续秒数（默认 300）
 *   --interval 5       每用户发送间隔秒数（默认 5）
 *   --url http://...   目标 URL（默认 http://127.0.0.1:8787/api/ai/chat）
 */

const http = require('http');
const https = require('https');

// ============ 参数解析 ============
const args = process.argv.slice(2);
const getArg = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : def;
};

const MODE = getArg('mode', 'mock');
const CONCURRENCY = parseInt(getArg('concurrency', '10'));
const DURATION = parseInt(getArg('duration', '300'));
const INTERVAL = parseInt(getArg('interval', '5'));
const TARGET_URL = getArg('url', 'http://127.0.0.1:8787/api/ai/chat');
const MOCK_PORT = 18787;

console.log('╔══════════════════════════════════════╗');
console.log('║  亿库 AI 客服 — 压力测试工具       ║');
console.log('╠══════════════════════════════════════╣');
console.log(`║  模式:     ${MODE === 'mock' ? 'Mock (无 AI 消耗)' : '真实 (走 AI API)'}`);
console.log(`║  并发:     ${CONCURRENCY} 用户`);
console.log(`║  持续:     ${DURATION} 秒`);
console.log(`║  间隔:     ${INTERVAL} 秒/用户`);
console.log(`║  预计请求: ~${Math.floor(CONCURRENCY * (DURATION / INTERVAL))} 个`);
console.log('╚══════════════════════════════════════╝');
console.log('');

// ============ Mock AI Server ============
function startMockServer() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.method === 'POST' && req.url.includes('/api/ai/chat')) {
        let body = '';
        req.on('data', (c) => (body += c));
        req.on('end', () => {
          let q = '';
          try {
            q = JSON.parse(body).question || '';
          } catch (_) {}

          // 模拟 AI 延迟 200-800ms
          const delay = 200 + Math.random() * 600;
          setTimeout(() => {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(
              JSON.stringify({
                answer: `[Mock] 关于"${q.slice(0, 30)}"的回复：亿库硅藻板采用光养硅藻技术，具有环保、防火、抗菌、防水等特性，适用于家装、学校、医院、酒店等多种场景。如需详细规格或报价，请联系 0779-8525688。`,
                channelPayload: { displayText: 'Mock response' },
                handoff: { handoff_readiness: 'low', lead_capture_needed: false },
              })
            );
          }, delay);
        });
      } else {
        res.writeHead(404);
        res.end();
      }
    });

    server.listen(MOCK_PORT, () => {
      console.log(` Mock 服务器已启动: http://127.0.0.1:${MOCK_PORT}/api/ai/chat\n`);
      resolve(server);
    });
  });
}

// ============ HTTP 客户端 ============
function post(url, body) {
  return new Promise((resolve) => {
    const u = new URL(url);
    const mod = u.protocol === 'https:' ? https : http;
    const payload = JSON.stringify(body);

    const start = Date.now();
    const req = mod.request(
      url,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        timeout: 30000,
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          const latency = Date.now() - start;
          try {
            const json = JSON.parse(data);
            resolve({ ok: res.statusCode < 400, status: res.statusCode, latency, data: json });
          } catch (_) {
            resolve({ ok: false, status: res.statusCode, latency, data: null, error: 'parse' });
          }
        });
      }
    );

    req.on('error', (e) => {
      resolve({ ok: false, status: 0, latency: Date.now() - start, data: null, error: e.code || e.message });
    });
    req.on('timeout', () => {
      req.destroy();
      resolve({ ok: false, status: 0, latency: 30000, data: null, error: 'timeout' });
    });
    req.write(payload);
    req.end();
  });
}

// ============ 压测运行器 ============
async function run() {
  let mockServer = null;
  let url = TARGET_URL;

  if (MODE === 'mock') {
    mockServer = await startMockServer();
    url = `http://127.0.0.1:${MOCK_PORT}/api/ai/chat`;
  }

  if (MODE === 'real') {
    console.log('⚠️  真实模式将调用 AI API，会产生费用！');
    console.log('   按 Ctrl+C 可随时中断...\n');
    await new Promise((r) => setTimeout(r, 2000));
  }

  let active = true;
  let totalReqs = 0;
  let successReqs = 0;
  let failReqs = 0;
  const latencies = [];
  const errors = {};

  // 每个虚拟用户的模拟行为
  async function user(id) {
    let round = 0;
    const history = [];
    const questions = [
      '你们产品适合哪些场景？',
      '学校医院能不能用？',
      '规格有哪些？',
      '怎么报价？',
      '如何联系销售？',
      '环保方面有什么认证？',
      '防水的具体参数是什么？',
      '有没有幼儿园用过的案例？',
      '板材厚度可以选择吗？',
      '运输和安装怎么安排？',
    ];

    while (active) {
      const q = questions[round % questions.length];
      history.push({ role: 'user', text: q });

      const result = await post(url, {
        channel: 'web',
        externalUserId: `stress-user-${id}`,
        conversationId: `stress-conv-${id}`,
        sessionId: `stress-session-${id}-${round}`,
        question: q,
        history: history.slice(-12),
      });

      totalReqs++;
      if (result.ok) {
        successReqs++;
        const answer = result.data?.answer || '';
        if (answer) {
          history.push({ role: 'assistant', text: answer });
        }
      } else {
        failReqs++;
        const errKey = result.error || `HTTP_${result.status}`;
        errors[errKey] = (errors[errKey] || 0) + 1;
      }
      latencies.push(result.latency);

      round++;

      // 等待间隔再发下一轮
      await new Promise((r) => setTimeout(r, INTERVAL * 1000));
    }
  }

  // 启动所有并发用户
  const users = [];
  for (let i = 0; i < CONCURRENCY; i++) {
    users.push(user(i + 1));
  }

  // 进度打印
  const progressTimer = setInterval(() => {
    const elapsed = Math.floor((Date.now() - startTime) / 1000);
    const qps = totalReqs > 0 ? (totalReqs / Math.max(elapsed, 1)).toFixed(2) : '0.00';
    const okRate = totalReqs > 0 ? ((successReqs / totalReqs) * 100).toFixed(1) : '0.0';
    process.stdout.write(
      `\r  已运行 ${elapsed}s | 请求 ${totalReqs} | 成功 ${successReqs} | QPS ${qps} | 成功率 ${okRate}%`
    );
  }, 2000);

  // 运行指定时长
  const startTime = Date.now();
  await new Promise((r) => setTimeout(r, DURATION * 1000));
  active = false;

  // 等待所有用户协程结束
  await Promise.allSettled(users);
  clearInterval(progressTimer);

  // 关闭 mock 服务器
  if (mockServer) {
    mockServer.close();
  }

  // ============ 结果汇总 ============
  console.log('\n');
  console.log('═══════════════════════════════════');
  console.log('        压测结果汇总');
  console.log('═══════════════════════════════════');

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`  总耗时:       ${elapsed} 秒`);
  console.log(`  总请求数:     ${totalReqs}`);
  console.log(`  成功:         ${successReqs}`);
  console.log(`  失败:         ${failReqs}`);
  console.log(`  成功率:       ${totalReqs > 0 ? ((successReqs / totalReqs) * 100).toFixed(1) : '0.0'}%`);
  console.log(`  实际 QPS:     ${(totalReqs / parseFloat(elapsed)).toFixed(2)}`);

  if (latencies.length > 0) {
    const sorted = [...latencies].sort((a, b) => a - b);
    const avg = (sorted.reduce((a, b) => a + b, 0) / sorted.length).toFixed(0);
    const min = sorted[0];
    const max = sorted[sorted.length - 1];
    const p50 = sorted[Math.floor(sorted.length * 0.5)];
    const p95 = sorted[Math.floor(sorted.length * 0.95)];
    const p99 = sorted[Math.floor(sorted.length * 0.99)];

    console.log('───────────────────────────────────');
    console.log('  响应时间 (ms):');
    console.log(`    Min:  ${min}`);
    console.log(`    Avg:  ${avg}`);
    console.log(`    P50:  ${p50}`);
    console.log(`    P95:  ${p95}`);
    console.log(`    P99:  ${p99}`);
    console.log(`    Max:  ${max}`);
  }

  if (Object.keys(errors).length > 0) {
    console.log('───────────────────────────────────');
    console.log('  错误分布:');
    Object.entries(errors)
      .sort((a, b) => b[1] - a[1])
      .forEach(([k, v]) => console.log(`    ${k}: ${v}`));
  }

  // Token 消耗估算
  if (MODE === 'mock') {
    console.log('\n  Token 消耗: 0（Mock 模式）');
  } else {
    const estTokens = totalReqs * 2000;
    console.log(`\n  预估 Token: ~${(estTokens / 10000).toFixed(0)} 万`);
    console.log(`  预估费用:   ~¥${(estTokens / 1000000 * 1.5).toFixed(2)}（按 DeepSeek 计）`);
  }

  console.log('═══════════════════════════════════\n');
}

run().catch((e) => {
  console.error('压测异常:', e.message);
  process.exit(1);
});
