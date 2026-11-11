# KẾT QUẢ KIỂM THỬ SAU TRIỂN KHAI (TEST RESULTS)

Dự án đã thực hiện kiểm thử đầy đủ 7 kịch bản (T1 - T7) theo yêu cầu tại **Bước 5** của đề bài.

| Mã | Tình huống | Kết quả mong đợi | Kết quả thực tế | Trạng thái |
|:---|:---|:---|:---|:---:|
| **T1** | Mở URL công khai | Trang web hiển thị bình thường | Trang giao diện DevSnippet Hub tải nhanh, CSS & icons hiển thị đầy đủ, danh sách snippet công khai render chính xác. | **PASS** ✅ |
| **T2** | Đăng ký và đăng nhập | Người dùng truy cập được chức năng cá nhân | Đăng ký tài khoản thành công; Đăng nhập trả về JWT token; Giao diện hiển thị tên người dùng và mở khóa nút "Tạo Snippet", lọc "Của tôi". | **PASS** ✅ |
| **T3** | Thêm, sửa, xóa snippet | Dữ liệu thay đổi đúng trong database | - Thêm snippet mới: Xuất hiện ngay trên bảng danh sách.<br/>- Sửa snippet: Cập nhật tiêu đề, code, ngôn ngữ.<br/>- Xóa snippet: Dữ liệu bị xóa khỏi DB, phản hồi HTTP 200. | **PASS** ✅ |
| **T4** | Khởi động lại ứng dụng | Dữ liệu vẫn còn nguyên vẹn | Khởi động lại container (`docker restart` hoặc restart trên Azure), kiểm tra lại toàn bộ dữ liệu tài khoản và snippet trước đó vẫn được lưu trữ bền vững. | **PASS** ✅ |
| **T5** | Gọi `/health` | Trả về trạng thái thành công | Endpoint `GET /health` trả về HTTP 200 JSON: `{"status": "UP", "uptimeSeconds": ..., "database": {"status": "UP"}}`. | **PASS** ✅ |
| **T6** | Gửi dữ liệu không hợp lệ | Ứng dụng báo lỗi phù hợp, không bị dừng (crash) | - Gửi thiếu email/mật khẩu -> HTTP 400 và thông báo lỗi rõ ràng.<br/>- Mật khẩu dưới 6 ký tự -> Báo lỗi validation.<br/>- Truy cập snippet riêng tư của người khác -> HTTP 403.<br/>- Server vẫn hoạt động ổn định, không bị ngắt. | **PASS** ✅ |
| **T7** | Xem log hệ thống | Tìm được request hoặc lỗi thử nghiệm | Console log và Log stream trên Cloud hiển thị đầy đủ định dạng chuẩn: `[APP-LOG] timestamp IP "METHOD URL HTTP/1.1" status duration ms`. | **PASS** ✅ |

---

## Chi tiết Minh chứng Kiểm thử trên Cloud (Live Evidence: https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com)

### Minh chứng T1: Truy cập trang chủ Web qua Domain HTTPS chính thức
```bash
curl -I https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com/
```
```http
HTTP/2 200 
server: nginx/1.24.0 (Ubuntu)
date: Wed, 11 Nov 2026 18:51:36 GMT
content-type: text/html; charset=UTF-8
```
*Tên miền & HTTPS:* Đã chứng thực thành công bằng chứng chỉ SSL Let's Encrypt!

### Minh chứng T5: Endpoint /health trên HTTPS Domain
```bash
curl -i https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com/health
```
```http
HTTP/2 200 
content-type: application/json; charset=utf-8

{
  "status": "UP",
  "timestamp": "2026-11-11T18:50:58.659Z",
  "uptimeSeconds": 33,
  "service": "DevSnippet Hub",
  "version": "1.0.0",
  "environment": "production",
  "database": {
    "status": "UP",
    "type": "SQLite",
    "latencyMs": 0
  }
}
```

### Minh chứng T6: Xử lý dữ liệu không hợp lệ
```bash
# Thử đăng ký với email không đúng định dạng
curl -X POST https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "not-an-email", "username": "user", "password": "123"}'
```
```json
{
  "success": false,
  "error": "Định dạng email không hợp lệ."
}
```
*(HTTP Status: 400 Bad Request, ứng dụng tiếp tục xử lý các kết nối khác bình thường).*

### Minh chứng T7: Log giám sát ứng dụng & Metrics (/metrics)
```bash
curl https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com/metrics
```
```json
{
  "status": "success",
  "timestamp": "2026-11-11T18:51:02.695Z",
  "metrics": {
    "uptimeSeconds": 36,
    "totalRequests": 52,
    "statusCodes": {
      "2xx": 50,
      "4xx": 1,
      "5xx": 0
    },
    "memory": {
      "rssMb": 66.71,
      "heapUsedMb": 10.08,
      "heapTotalMb": 11.35
    }
  }
}
```
