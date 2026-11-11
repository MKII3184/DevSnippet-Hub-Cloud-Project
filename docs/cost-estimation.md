# BẢNG ƯỚC TÍNH CHI PHÍ VẬN HÀNH TRÊN MICROSOFT AZURE (1 THÁNG)

## 1. Các Giả định (Assumptions)
- **Tài khoản sử dụng:** Azure for Students (Credit khởi điểm $100) hoặc Pay-As-You-Go với Free Tier.
- **Khu vực (Region):** East Asia (Hong Kong) hoặc Southeast Asia (Singapore) – gần Việt Nam nhất để tối ưu độ trễ mạng (< 50ms).
- **Lượng truy cập dự kiến:** Phục vụ nhóm đồ án và giảng viên kiểm thử (~5,000 lượt request/tháng, lượng truyền tải dữ liệu < 5GB).
- **Thời gian chạy:** Ứng dụng chạy liên tục trong 10 tuần học tập và bảo vệ đồ án (730 giờ/tháng).

---

## 2. Bảng Dự Toán Chi Phí Chi Tiết (Chi phí/Tháng)

| Dịch vụ Azure | Cấu hình / SKU | Giả định tài nguyên | Chi phí ước tính (USD) | Ghi chú Free Tier / Tiết kiệm |
|:---|:---|:---|:---:|:---|
| **Azure Container Apps** | Consumption Plan | 0.25 vCPU, 0.5 GB RAM, scale to zero khi nhàn rỗi | **$0.00** | Miễn phí 180,000 vCPU-seconds & 360,000 GiB-seconds đầu mỗi tháng |
| **Azure Container Registry (ACR)** | Basic SKU | 1 repository, 10GB dung lượng lưu trữ image | **$5.00** | Đủ lưu trữ các version image v1.0, v1.1 |
| **Azure Database for PostgreSQL** | Flexible Server (Burstable B1ms) | 1 vCore, 2 GB RAM, 32 GB Storage | **$12.50** | Có gói Free 12 tháng đầu tiên cho tài khoản sinh viên/mới |
| **Azure Log Analytics & App Insights** | Pay-as-you-go | Dung lượng log < 1 GB/tháng | **$0.00** | Miễn phí 5 GB ingestion data/tháng đầu tiên |
| **Băng thông Internet (Data Egress)** | Standard Data Transfer | ~3 GB dữ liệu ra ngoài Internet | **$0.00** | Miễn phí 100 GB dữ liệu tải ra đầu tiên mỗi tháng |
| **Chứng chỉ SSL & Tên miền** | *.azurecontainerapps.io | HTTPS tự động do Azure quản lý | **$0.00** | Tích hợp sẵn chứng chỉ TLS miễn phí |
| **TỔNG CHI PHÍ DỰ KIẾN / THÁNG** | | | **~$5.00 - $17.50 / tháng** | Trừ trực tiếp vào $100 Credit sinh viên |

---

## 3. Chính Sách Cảnh Báo Ngân Sách (Budget Alert)

Nhằm đảm bảo không vượt quá ngân sách $100 và tránh phát sinh chi phí ngoài ý muốn:
1. **Thiết lập cảnh báo:** Đặt ngân sách cố định **$25.00 USD/tháng** trên Azure Cost Management.
2. **Ngưỡng kích hoạt:**
   - **50% ($12.50):** Gửi email thông báo nhắc nhở nhóm.
   - **80% ($20.00):** Gửi cảnh báo kiểm tra tài nguyên.
   - **100% ($25.00):** Tự động gửi cảnh báo khẩn cấp để scale down hoặc tạm dừng tài nguyên kiểm thử.
3. **Kế hoạch dọn dẹp tài nguyên (Clean up):**
   - Sau khi kết thúc buổi bảo vệ đồ án, chỉ cần chạy 1 lệnh CLI để xóa toàn bộ Resource Group:
     ```bash
     az group delete --name rg-devsnippet-eastasia --yes --no-wait
     ```
   - Lệnh này hủy ngay lập tức tất cả tài nguyên liên quan, đảm bảo chi phí dừng ở mức $0.
