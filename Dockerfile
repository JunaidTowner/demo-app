# =========================
# 1️⃣ Build stage
# =========================
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build

# =========================
# 2️⃣ Runtime stage
# =========================
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
# Azure App Service sets PORT automatically, default to 8080
ENV PORT=8080
ENV HOSTNAME=0.0.0.0

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy standalone build from builder
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 8080

# Use standalone server.js which handles PORT env var automatically
CMD ["node", "server.js"]
