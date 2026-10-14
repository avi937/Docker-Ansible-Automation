# ========================================================
# PRODUCTION-GRADE MULTI-STAGE DOCKERFILE
# (Engineered for Minimal Size, Caching & Non-Root Security)
# ========================================================

# ==========================================
# STAGE 1: Builder Stage (Build & Dependencies)
# ==========================================
FROM node:18-alpine AS builder

# Set working directory inside builder container
WORKDIR /app

# Step 1: Copy ONLY dependency manifests first (enables Docker layer caching)
COPY package*.json ./

# Step 2: Install dependencies cleanly matching package-lock.json
RUN npm ci

# Step 3: Copy source code only AFTER dependencies are installed and cached
COPY . .

# ==========================================
# STAGE 2: Production Runtime (Ultra-Lean Stage)
# ==========================================
FROM node:18-alpine

# Set clean working directory for production
WORKDIR /app

# Step 4: Security Hardening - Create an unprivileged non-root system user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Step 5: Copy package manifests from Stage 1
COPY --from=builder /app/package*.json ./

# Step 6: Install ONLY production dependencies (skips all devDependencies)
RUN npm ci --only=production && npm cache clean --force

# Step 7: Copy application code from Stage 1 and grant ownership to non-root user
COPY --from=builder --chown=appuser:appgroup /app/src ./src

# Step 8: Switch from root to non-root user
USER appuser

# Step 9: Document container listening port
EXPOSE 3000

# Step 10: Exec-form CMD directly invokes Node (handles PID 1 SIGTERM gracefully)
CMD ["node", "src/server.js"]
