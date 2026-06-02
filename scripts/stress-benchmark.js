/**
 * 亿库 AI 客服 — 全面基准压测
 *
 * 多组配置自动轮跑，输出结构化报告
 * 用法: node scripts/stress-benchmark.js [--mode mock|real] [--url http://...]
 */

const { spawn } = require('child_process');
const path = require('path');

const MODE = process.argv.includes('--real') ? 'real' : 'mock';
const BASE_URL = (() => {
  const i = process.argv.indexOf('--url');
  return i >= 0 ? process.argv[i + 1] : 'http://127.0.0.1:8787/api/ai/chat';
})();

// 测试矩阵：覆盖低/中/高并发 + 不同发送频率
const TEST_MATRIX = [
  // 低负载
  { concurrency: 5, duration: 60, interval: 5, label: '低负载-标准' },
  { concurrency: 5, duration: 60, interval: 3, label: '低负载-高频' },
  // 中负载
  { concurrency: 10, duration: 60, interval: 5, label: '中负载-标准' },
  { concurrency: 10, duration: 60, interval: 3, label: '中负载-高频' },
  { concurrency: 10, duration: 60, interval: 2, label: '中负载-极速' },
  // 高负载
  { concurrency: 20, duration: 60, interval: 5, label: '高负载-标准' },
  { concurrency: 20, duration: 60, interval: 3, label: '高负载-高频' },
  { concurrency: 20, duration: 60, interval: 2, label: '高负载-极速' },
  // 极限
  { concurrency: 50, duration: 60, interval: 5, label: '极限-标准' },
  { concurrency: 50, duration: 60, interval: 3, label: '极限-高频' },
  { concurrency: 50, duration: 60, interval: 2, label: '极限-极速' },
  { concurrency: 100, duration: 30, interval: 3, label: '压垮测试' },
];

function parseOutput(out) {
  const result = {};
  const m = {
    elapsed: out.match(/总耗时:\s+([\d.]+)\s*秒/),
    total: out.match(/总请求数:\s+(\d+)/),
    success: out.match(/成功:\s+(\d+)/),
    fail: out.match(/失败:\s+(\d+)/),
    okRate: out.match(/成功率:\s+([\d.]+)%/),
    qps: out.match(/实际 QPS:\s+([\d.]+)/),
    min: out.match(/Min:\s+(\d+)/),
    avg: out.match(/Avg:\s+(\d+)/),
    p50: out.match(/P50:\s+(\d+)/),
    p95: out.match(/P95:\s+(\d+)/),
    p99: out.match(/P99:\s+(\d+)/),
    max: out.match(/Max:\s+(\d+)/),
  };
  for (const [k, v] of Object.entries(m)) {
    result[k] = v ? v[1] : '-';
  }
  return result;
}

async function runTest(config) {
  return new Promise((resolve) => {
    const start = Date.now();
    const child = spawn('node', [
      path.join(__dirname, 'stress-test.js'),
      '--mode', MODE,
      '--concurrency', String(config.concurrency),
      '--duration', String(config.duration),
      '--interval', String(config.interval),
      '--url', BASE_URL,
    ], {
      cwd: path.join(__dirname, '..'),
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => { stdout += d.toString(); });
    child.stderr.on('data', (d) => { stderr += d.toString(); });

    child.on('close', () => {
      const wallTime = ((Date.now() - start) / 1000).toFixed(1);
      const data = parseOutput(stdout);
      data.wallTime = wallTime;
      data.label = config.label;
      data.concurrency = config.concurrency;
      data.interval = config.interval;
      data.expectedReqs = Math.floor(config.concurrency * (config.duration / config.interval));
      resolve(data);
    });

    child.on('error', () => {
      resolve({ label: config.label, concurrency: config.concurrency, interval: config.interval, error: 'spawn_failed' });
    });
  });
}

async function main() {
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║  亿库 AI 客服 — 全面基准压测报告                    ║');
  console.log('╠══════════════════════════════════════════════════════╣');
  console.log(`║  模式: ${MODE === 'mock' ? 'Mock (本地模拟 AI 延迟 200-800ms)' : 'Real (直连生产)'}`);
  console.log(`║  目标: ${MODE === 'mock' ? '127.0.0.1:18787' : BASE_URL}`);
  console.log(`║  时间: ${new Date().toISOString().replace('T',' ').slice(0,19)}`);
  console.log(`║  用例: ${TEST_MATRIX.length} 组`);
  console.log('╚══════════════════════════════════════════════════════╝\n');

  const results = [];
  for (let i = 0; i < TEST_MATRIX.length; i++) {
    const cfg = TEST_MATRIX[i];
    const eta = cfg.duration + 5;
    console.log(`[${i + 1}/${TEST_MATRIX.length}] ${cfg.label}: ${cfg.concurrency}并发/${cfg.duration}s/${cfg.interval}s间隔 ... (预计${eta}s)`);
    const r = await runTest(cfg);
    results.push(r);
    console.log(`  → 请求:${r.total} | 成功率:${r.okRate}% | QPS:${r.qps} | P50:${r.p50}ms | P95:${r.p95}ms\n`);
  }

  // === 报告 ===
  console.log('\n');
  console.log('┌──────────────────────────────────────────────────────────────────────────┐');
  console.log('│                         压 测 报 告 汇 总                                │');
  console.log('├──────────────────────────────────────────────────────────────────────────┤');
  console.log('│ 配置              并发  间隔  预测    实际  成功率    QPS   P50   P95   P99 │');
  console.log('├──────────────────────────────────────────────────────────────────────────┤');
  for (const r of results) {
    const label = (r.label || '').padEnd(16);
    const c = String(r.concurrency || '-').padStart(4);
    const iv = (String(r.interval) + 's').padStart(4);
    const exp = String(r.expectedReqs || '-').padStart(5);
    const tot = String(r.total || '-').padStart(5);
    const ok = ((r.okRate || '-') + '%').padStart(5);
    const qps = String(r.qps || '-').padStart(5);
    const p50 = (String(r.p50) + 'ms').padStart(5);
    const p95 = (String(r.p95) + 'ms').padStart(5);
    const p99 = (String(r.p99) + 'ms').padStart(5);
    console.log(`│ ${label} ${c}  ${iv}  ${exp}   ${tot}  ${ok}  ${qps}  ${p50}  ${p95}  ${p99} │`);
  }
  console.log('└──────────────────────────────────────────────────────────────────────────┘');

  // 结论
  const allOk = results.every(r => parseFloat(r.okRate) >= 99);
  const maxQps = Math.max(...results.map(r => parseFloat(r.qps) || 0));
  const maxP95 = Math.max(...results.map(r => parseInt(r.p95) || 0));

  console.log('\n【结论】');
  console.log(`  稳定性: ${allOk ? '全部通过 ✓' : '部分失败 ✗'}`);
  console.log(`  峰值 QPS: ${maxQps.toFixed(1)}`);
  console.log(`  最差 P95: ${maxP95}ms`);

  if (MODE === 'mock') {
    console.log(`  模拟 AI 延迟: 200-800ms（均匀分布）`);
    console.log(`  Token 消耗: 0`);
    console.log(`\n  说明: Mock 模式测试的是 Node.js HTTP 服务的基础承载能力。`);
    console.log(`  真实场景需要额外加上 DeepSeek/智谱 API 的 2-10 秒延迟。`);
    console.log(`  按 10 并发 × 5s 间隔计算，真实场景 QPS 约 2，完全可以接受。`);
  }

  console.log('');
}

main().catch(e => { console.error(e); process.exit(1); });
