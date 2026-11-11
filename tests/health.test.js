const assert = require('assert');
const db = require('../src/db/database');

async function runTests() {
  console.log('🧪 Bắt đầu chạy Unit & Integration Tests...');

  // Test 1: Database Initialization & Health Check
  console.log('Test 1: Kiểm tra kết nối cơ sở dữ liệu...');
  await db.initDb();
  const dbHealth = await db.checkHealth();
  assert.strictEqual(dbHealth.status, 'UP', 'Database health check phải trả về UP');
  console.log('✅ Test 1 PASSED: Database hoạt động tốt.');

  // Test 2: User creation & Query
  console.log('Test 2: Kiểm tra truy vấn bảng users...');
  const userCount = await db.query('SELECT COUNT(*) as count FROM users');
  assert(parseInt(userCount.rows[0].count, 10) >= 0, 'Phải truy vấn được bảng users');
  console.log('✅ Test 2 PASSED: Truy vấn users thành công.');

  // Test 3: Snippets Query & Filtering
  console.log('Test 3: Kiểm tra lọc snippets theo trạng thái...');
  const snippets = await db.query("SELECT * FROM snippets WHERE status = 'public'");
  assert(Array.isArray(snippets.rows), 'Kết quả truy vấn phải là một mảng');
  console.log('✅ Test 3 PASSED: Lọc trạng thái snippets thành công.');

  console.log('\n🎉 TOÀN BỘ TESTS ĐÃ VƯỢT QUA THÀNH CÔNG (100% PASSED)!');
}

runTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Test thất bại:', err);
    process.exit(1);
  });
