# Multi-stage Dockerfile for DevSnippet Hub
# Stage 1: Build & Dependencies
FROM node:24-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2: Runtime Production Image
FROM node:24-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

# Security: Create non-root user and setup directories
RUN mkdir -p /app/data && chown -R node:node /app

# Copy dependencies and application source
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .

# Run as non-root user for security best practices
USER node

# Health check matching Section 3.1 & Test Case T5
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["node", "src/server.js"]
