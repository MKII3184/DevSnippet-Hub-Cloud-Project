const bcrypt = require('bcryptjs');
const db = require('./db/database');

async function seed() {
  console.log('[SEED] Initializing database schema...');
  await db.initDb();

  console.log('[SEED] Checking existing demo user...');
  const existingUser = await db.query('SELECT * FROM users WHERE email = $1', ['demo@devsnippet.io']);
  let userId;

  if (existingUser.rows.length === 0) {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash('Password@123', salt);

    let insertUserSql = `
      INSERT INTO users (email, username, password_hash)
      VALUES ($1, $2, $3)
    `;
    if (db.isPostgres()) {
      insertUserSql += ' RETURNING id';
    }

    const userRes = await db.query(insertUserSql, [
      'demo@devsnippet.io',
      'cloud_master',
      passwordHash
    ]);

    userId = db.isPostgres() ? userRes.rows[0].id : userRes.lastInsertRowid;
    console.log(`[SEED] Created demo user: demo@devsnippet.io (ID: ${userId})`);
  } else {
    userId = existingUser.rows[0].id;
    console.log(`[SEED] Demo user already exists with ID: ${userId}`);
  }

  // Clear existing snippets for clean seed if needed
  const countRes = await db.query('SELECT COUNT(*) as count FROM snippets');
  if (parseInt(countRes.rows[0].count, 10) > 0) {
    console.log(`[SEED] Database already contains ${countRes.rows[0].count} snippets. Skipping snippet creation.`);
    return;
  }

  const sampleSnippets = [
    {
      title: 'Docker Multi-Stage Build for Node.js Application',
      language: 'dockerfile',
      description: 'Tối ưu hóa dung lượng Docker image từ 1GB xuống dưới 120MB bằng multi-stage build với Alpine Linux.',
      tags: 'docker, nodejs, devops, production',
      status: 'public',
      code: `FROM node:24-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 8080
USER node
CMD ["node", "src/server.js"]`
    },
    {
      title: 'Azure CLI - Deploy Container to Azure Container Apps',
      language: 'bash',
      description: 'Lệnh Azure CLI một dòng để build ACR và triển khai lên Azure Container Apps có HTTPS tự động.',
      tags: 'azure, cloud, cli, container-apps',
      status: 'public',
      code: `# 1. Tạo Resource Group
az group create --name rg-devsnippet-eastasia --location eastasia

# 2. Tạo Azure Container Registry
az acr create --resource-group rg-devsnippet-eastasia --name acrdevsnippet2026 --sku Basic --admin-enabled true

# 3. Build image trên cloud bằng ACR Build
az acr build --registry acrdevsnippet2026 --image devsnippet-hub:v1.0 .

# 4. Tạo Azure Container Apps Environment
az containerapp env create --name env-devsnippet --resource-group rg-devsnippet-eastasia --location eastasia

# 5. Triển khai ứng dụng
az containerapp create \\
  --name app-devsnippet \\
  --resource-group rg-devsnippet-eastasia \\
  --environment env-devsnippet \\
  --image acrdevsnippet2026.azurecr.io/devsnippet-hub:v1.0 \\
  --target-port 8080 \\
  --ingress external`
    },
    {
      title: 'Express.js Cloud Health Check & Observability Handler',
      language: 'javascript',
      description: 'Endpoint chuẩn /health trả về trạng thái máy chủ, độ trễ database và thông số bộ nhớ RAM.',
      tags: 'express, health-check, observability, api',
      status: 'public',
      code: `router.get('/health', async (req, res) => {
  const dbHealth = await db.checkHealth();
  const isHealthy = dbHealth.status === 'UP';

  return res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'UP' : 'DEGRADED',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    database: dbHealth,
    memory: process.memoryUsage()
  });
});`
    },
    {
      title: 'Python FastAPI Async PostgreSQL Connection Pool',
      language: 'python',
      description: 'Cấu hình AsyncPG pool với lifespan context manager trong FastAPI hiện đại.',
      tags: 'python, fastapi, postgresql, async',
      status: 'public',
      code: `from contextlib import asynccontextmanager
from fastapi import FastAPI
import asyncpg
import os

DATABASE_URL = os.getenv("DATABASE_URL")

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)
    print("Database pool connected successfully.")
    yield
    await app.state.pool.close()

app = FastAPI(lifespan=lifespan)`
    },
    {
      title: 'PostgreSQL Automated Database Backup Script with Retention',
      language: 'bash',
      description: 'Script sao lưu tự động PostgreSQL dump mỗi ngày và xóa các file backup cũ hơn 7 ngày.',
      tags: 'postgresql, backup, automation, devops',
      status: 'public',
      code: `#!/bin/bash
BACKUP_DIR="/var/backups/postgres"
DATE=$(date +"%Y%m%d_%H%M%S")
FILENAME="$BACKUP_DIR/db_backup_$DATE.sql.gz"

mkdir -p $BACKUP_DIR
pg_dump -U postgres -h localhost devsnippet_db | gzip > $FILENAME

echo "Backup completed: $FILENAME"
# Giữ lại bản sao lưu trong 7 ngày
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +7 -delete`
    },
    {
      title: 'Terraform - Azure Resource Group & App Service Plan (IaC)',
      language: 'hcl',
      description: 'Mã nguồn Infrastructure as Code định nghĩa Azure Resource Group và App Service Plan gói Free F1.',
      tags: 'terraform, iac, azure, cloud',
      status: 'public',
      code: `terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-devsnippet-iac"
  location = "East Asia"
}

resource "azurerm_service_plan" "asp" {
  name                = "asp-devsnippet-free"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}`
    },
    {
      title: 'Private Production Database Secret Credentials (Demo)',
      language: 'json',
      description: 'Đoạn cấu hình mẫu riêng tư (Private) chỉ chủ sở hữu tài khoản mới xem và sửa được.',
      tags: 'secret, private, config',
      status: 'private',
      code: `{
  "DB_HOST": "psql-devsnippet-prod.postgres.database.azure.com",
  "DB_PORT": 5432,
  "DB_USER": "azureuser@psql-devsnippet-prod",
  "DB_NAME": "devsnippet_db",
  "MAX_CONNECTIONS": 20,
  "SSL_MODE": "require"
}`
    }
  ];

  for (const item of sampleSnippets) {
    let insertSnippetSql = `
      INSERT INTO snippets (user_id, title, language, code, description, tags, status, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `;
    await db.query(insertSnippetSql, [
      userId,
      item.title,
      item.language,
      item.code,
      item.description,
      item.tags,
      item.status
    ]);
  }

  console.log(`[SEED] Successfully seeded ${sampleSnippets.length} sample snippets!`);
}

if (require.main === module) {
  seed()
    .then(() => {
      console.log('[SEED] Finished.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('[SEED] Error seeding data:', err);
      process.exit(1);
    });
}

module.exports = seed;
