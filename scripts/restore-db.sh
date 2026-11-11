#!/bin/bash
# ==============================================================================
# SCRIPT KHÔI PHỤC DATABASE TỰ ĐỘNG (RESTORE SCRIPT)
# ==============================================================================
set -e

if [ -z "$1" ]; then
    echo "Cách sử dụng: ./scripts/restore-db.sh <đường-dẫn-file-backup>"
    echo "Ví dụ: ./scripts/restore-db.sh /opt/devsnippet-hub/backups/sqlite_backup_20261111_120000.db"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Lỗi: File sao lưu '$BACKUP_FILE' không tồn tại!"
    exit 1
fi

echo "[RESTORE] Bắt đầu quá trình khôi phục từ: $BACKUP_FILE..."

# Dừng tạm thời dịch vụ để an toàn dữ liệu
systemctl stop devsnippet.service 2>/dev/null || true

if [[ "$BACKUP_FILE" == *.sql.gz ]]; then
    echo "[RESTORE] Đang phục hồi cơ sở dữ liệu PostgreSQL..."
    gunzip -c "$BACKUP_FILE" | psql "$DATABASE_URL"
else
    echo "[RESTORE] Đang phục hồi cơ sở dữ liệu SQLite..."
    DB_TARGET="/opt/devsnippet-hub/data/devsnippet.db"
    cp "$BACKUP_FILE" "$DB_TARGET"
fi

# Khởi động lại dịch vụ
systemctl start devsnippet.service 2>/dev/null || true

echo "✅ Phục hồi cơ sở dữ liệu thành công! Ứng dụng đã hoạt động trở lại."
