# DÀN Ý SLIDE THUYẾT TRÌNH & KỊCH BẢN VIDEO DEMO (5–7 PHÚT)

---

## PHẦN A: DÀN Ý SLIDE THUYẾT TRÌNH (10 - 12 SLIDES)

- **Slide 1: Trang bìa**  
  * Tiêu đề: ĐỒ ÁN MÔN HỌC CLOUD COMPUTING - DEVSNIPPET HUB
  * Tên giảng viên hướng dẫn, thông tin nhóm sinh viên (5 thành viên).
  * Đường dẫn ứng dụng trực tuyến: `https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com`
  * IP công khai: `52.231.24.237` | Khu vực: `Korea Central`

- **Slide 2: Đặt vấn đề & Mục tiêu đề tài**  
  * Khó khăn trong quản lý code snippet của lập trình viên.
  * Mục tiêu: Đóng gói Docker, triển khai Cloud-Native trên Microsoft Azure, giám sát toàn diện.

- **Slide 3: Chức năng chính của DevSnippet Hub**  
  * Xác thực người dùng (Bcrypt + JWT).
  * CRUD đoạn mã, tô màu cú pháp đa ngôn ngữ (Prism.js).
  * Lọc trạng thái (Công khai / Riêng tư / Của tôi).

- **Slide 4: Sơ đồ kiến trúc hệ thống (System Architecture)**  
  * Trình chiếu sơ đồ luồng dữ liệu: Client -> Nginx SSL -> Node.js Container -> Persistent Database Storage.
  * Lý do chọn Region: East Asia (Hong Kong) với độ trễ thấp ~48ms.

- **Slide 5: Quy trình Docker hóa (Docker Multi-Stage Build)**  
  * Kỹ thuật multi-stage build giảm kích thước từ 1GB xuống 120MB.
  * Thiết lập non-root user và chỉ thị HEALTHCHECK.

- **Slide 6: Hạ tầng dưới dạng mã (Terraform IaC) & Tự động hóa CI/CD**  
  * Mã nguồn Terraform định nghĩa toàn bộ hạ tầng Azure.
  * Pipeline GitHub Actions tự động kiểm thử mỗi khi push mã nguồn.

- **Slide 7: An toàn bảo mật & Quản lý Secret**  
  * Không commit file `.env` lên Git.
  * Mã hóa một chiều mật khẩu, xác thực bằng HTTP-only cookie.
  * Firewall Network Security Group chỉ mở cổng 80, 443, 22.

- **Slide 8: Khả năng quan sát & Giám sát (Observability)**  
  * Endpoint `/health` kiểm tra trạng thái máy chủ và CSDL.
  * Endpoint `/metrics` theo dõi RAM, CPU, tỷ lệ mã HTTP.
  * Chuẩn hóa Request Logging qua stdout.

- **Slide 9: Kết quả kiểm thử tải (Load Testing)**  
  * Biểu đồ hiệu năng: 162.21 req/giây.
  * Tỷ lệ thành công 100%, độ trễ trung bình 57ms.

- **Slide 10: Cơ chế Sao lưu & Khôi phục (Backup & Restore)**  
  * Quy trình tạo bản sao lưu tự động và kiểm chứng phục hồi 100% dữ liệu.

- **Slide 11: Dự toán chi phí & Budget Alert**  
  * Bảng chi phí hàng tháng ($5 - $17.50/tháng).
  * Cảnh báo ngưỡng ngân sách $25.00/tháng.

- **Slide 12: Tổng kết & Hỏi đáp (Q&A)**  
  * Lời cảm ơn thầy cô và hội đồng chấm thi.

---

## PHẦN B: KỊCH BẢN VIDEO DEMO TỪNG PHÚT (5 - 7 PHÚT)

| Mốc thời gian | Nội dung trình diễn trên màn hình | Lời thoại thuyết minh gợi ý |
|:---:|:---|:---|
| **00:00 - 01:00** | - Mở trang web bằng trình duyệt qua domain: `https://devsnippet-app-24110903.koreacentral.cloudapp.azure.com`<br/>- Chỉ vào biểu tượng ổ khóa SSL xanh (HTTPS). | *"Xin chào thầy cô, hôm nay nhóm em xin trình diễn sản phẩm DevSnippet Hub được triển khai trên Microsoft Azure. Trang web đang chạy với chứng chỉ SSL HTTPS bảo mật..."* |
| **01:00 - 02:30** | - Đăng nhập tài khoản demo: `demo@devsnippet.io` / `Password@123`<br/>- Thêm 1 snippet mới (ngôn ngữ Dockerfile hoặc Python).<br/>- Bấm nút sao chép mã (Copy code).<br/>- Chỉnh sửa tiêu đề snippet và đổi sang trạng thái Riêng tư.<br/>- Bấm các nút lọc trạng thái: "Công khai", "Riêng tư", "Của tôi". | *"Tiếp theo là phần kiểm thử chức năng CRUD và lọc trạng thái. Người dùng đăng nhập có thể tạo snippet mới với syntax highlighting đẹp mắt. Em chuyển trạng thái sang riêng tư và lọc thì snippet chỉ hiển thị với chính tác giả..."* |
| **02:30 - 03:30** | - Mở tab mới truy cập `/health`<br/>- Mở tab mới truy cập `/metrics`<br/>- Bấm vào nút "Cloud Observability" trên thanh điều hướng để xem popup trực quan. | *"Về tiêu chí giám sát và kiểm tra sức khỏe, hệ thống cung cấp endpoint /health trả về trạng thái UP và độ trễ database 0ms. Endpoint /metrics cung cấp chi tiết về lượng RAM tiêu thụ và số request..."* |
| **03:30 - 04:30** | - Mở terminal máy tính chạy lệnh kiểm thử tải: `node tests/load-test.js`<br/>- Quay màn hình terminal trả về 200 requests thành công 100% với tốc độ 162 req/s. | *"Nhóm em đã tiến hành kiểm thử tải đồng thời với 10 luồng và 200 requests. Kết quả đạt 162 requests mỗi giây với tỷ lệ thành công 100% và độ trễ chỉ 57ms..."* |
| **04:30 - 05:30** | - Mở mã nguồn trong VS Code / Git repo.<br/>- Trình bày file `Dockerfile`, thư mục `terraform/`, pipeline `.github/workflows/deploy.yml`. | *"Mã nguồn được đóng gói với Docker multi-stage build, có kịch bản hạ tầng Terraform và pipeline CI/CD tự động trên GitHub Actions..."* |
| **05:30 - 06:00** | - Tổng kết ngắn gọn và chào kết thúc video. | *"Dự án đã hoàn thành 100% các tiêu chí bắt buộc và đạt toàn bộ các điểm cộng kỹ thuật. Nhóm em xin cảm ơn thầy cô đã lắng nghe."* |
