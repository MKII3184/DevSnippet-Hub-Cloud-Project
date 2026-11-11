const https = require('https');

const TARGET_URL = process.env.TARGET_URL || 'https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com/health';
const TOTAL_REQUESTS = parseInt(process.env.TOTAL_REQUESTS || '200', 10);
const CONCURRENCY = parseInt(process.env.CONCURRENCY || '10', 10);

console.log('====================================================');
console.log('🚀 BẮT ĐẦU KIỂM THỬ TẢI HỆ THỐNG (LOAD TEST)');
console.log(`🌐 Mục tiêu:        ${TARGET_URL}`);
console.log(`📊 Tổng requests:   ${TOTAL_REQUESTS}`);
console.log(`⚡ Độ đồng thời:    ${CONCURRENCY} workers`);
console.log('====================================================\n');

let completed = 0;
let successCount = 0;
let errorCount = 0;
const latencies = [];
const startTime = Date.now();

function makeRequest() {
  return new Promise((resolve) => {
    const reqStart = Date.now();
    const req = https.get(TARGET_URL, (res) => {
      res.resume(); // consume body
      res.on('end', () => {
        const duration = Date.now() - reqStart;
        latencies.push(duration);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          successCount++;
        } else {
          errorCount++;
        }
        completed++;
        resolve();
      });
    });

    req.on('error', (err) => {
      latencies.push(Date.now() - reqStart);
      errorCount++;
      completed++;
      resolve();
    });

    req.setTimeout(10000, () => {
      req.destroy();
      errorCount++;
      completed++;
      resolve();
    });
  });
}

async function worker() {
  while (completed < TOTAL_REQUESTS) {
    await makeRequest();
  }
}

async function run() {
  const workers = [];
  for (let i = 0; i < CONCURRENCY; i++) {
    workers.push(worker());
  }
  await Promise.all(workers);

  const totalTimeSec = (Date.now() - startTime) / 1000;
  latencies.sort((a, b) => a - b);

  const avgLatency = Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length);
  const p50 = latencies[Math.floor(latencies.length * 0.5)];
  const p90 = latencies[Math.floor(latencies.length * 0.9)];
  const p99 = latencies[Math.floor(latencies.length * 0.99)];
  const rps = (TOTAL_REQUESTS / totalTimeSec).toFixed(2);

  console.log('📊 KẾT QUẢ KIỂM THỬ TẢI (LOAD TEST SUMMARY):');
  console.log(`- Thời gian kiểm thử:     ${totalTimeSec.toFixed(2)} giây`);
  console.log(`- Tốc độ xử lý (RPS):     ${rps} req/sec`);
  console.log(`- Tỷ lệ thành công:       ${((successCount / TOTAL_REQUESTS) * 100).toFixed(1)}% (${successCount}/${TOTAL_REQUESTS})`);
  console.log(`- Tỷ lệ lỗi (Error rate): ${((errorCount / TOTAL_REQUESTS) * 100).toFixed(1)}%`);
  console.log(`- Độ trễ trung bình:      ${avgLatency} ms`);
  console.log(`- Độ trễ P50 (Median):    ${p50} ms`);
  console.log(`- Độ trễ P90:             ${p90} ms`);
  console.log(`- Độ trễ P99:             ${p99} ms`);
  console.log('====================================================');
}

run();
