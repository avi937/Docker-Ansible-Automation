# ==============================================================================
# PROJECT 3: MULTI-TIER MICROSERVICES DOCKERFILE
# Stage 1: Builder (Compiles & audits dependencies)
# ==============================================================================
FROM node:18-alpine AS builder

WORKDIR /app

# Optimize caching: copy package manifests first
COPY package*.json ./

# Strict reproducible build: uses npm ci when lockfile exists, fallback to install
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Copy application source
COPY . .

# ==============================================================================
# Stage 2: Production Runtime (Minimal, hardened, non-root)
# ==============================================================================
FROM node:18-alpine

WORKDIR /app

# 1. Security: Create an unprivileged non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 2. Install production dependencies ONLY (strict pinned versions)
COPY --from=builder /app/package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --only=production; else npm install --omit=dev; fi && npm cache clean --force

# 3. Copy source code with non-root ownership
COPY --from=builder --chown=appuser:appgroup /app/src ./src

# 4. Drop root privileges
USER appuser

# Expose internal API port
EXPOSE 3000

# Exec form: Ensures node is PID 1 for instant SIGTERM graceful shutdown
CMD ["node", "src/server.js"]
