#!/bin/bash
# ==============================================================================
# SCRIPT SAO LƯU DATABASE TỰ ĐỘNG (BACKUP SCRIPT)
# Hỗ trợ cả SQLite (Local/VM) và PostgreSQL (Cloud Database)
# ==============================================================================
set -e

BACKUP_DIR="/opt/devsnippet-hub/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_DIR"

if [ -n "$DATABASE_URL" ]; then
    echo "[BACKUP] Đang sao lưu PostgreSQL database..."
    BACKUP_FILE="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql.gz"
    pg_dump "$DATABASE_URL" | gzip > "$BACKUP_FILE"
else
    echo "[BACKUP] Đang sao lưu SQLite database..."
    DB_FILE="/opt/devsnippet-hub/data/devsnippet.db"
    BACKUP_FILE="$BACKUP_DIR/sqlite_backup_$TIMESTAMP.db"
    # Dùng sqlite3 online backup để tránh lock database
    if command -v sqlite3 &> /dev/null; then
        sqlite3 "$DB_FILE" ".backup '$BACKUP_FILE'"
    else
        cp "$DB_FILE" "$BACKUP_FILE"
    fi
fi

echo "✅ Bản sao lưu đã tạo thành công: $BACKUP_FILE ($(stat -c%s "$BACKUP_FILE" 2>/dev/null || stat -f%z "$BACKUP_FILE") bytes)"

# Tự động xóa bản sao lưu cũ hơn 7 ngày (Retention policy)
find "$BACKUP_DIR" -type f -name "*_backup_*" -mtime +7 -delete
echo "[BACKUP] Hoàn tất dọn dẹp các bản backup cũ hơn 7 ngày."
