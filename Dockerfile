# ============================
# Stage 1: Build
# ============================
# We use the full Node.js image because we need npm and tsc to compile.
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files first to leverage Docker layer caching.
# This way, if only source code changes, npm install is skipped.
COPY package*.json ./
RUN npm install --ignore-scripts

# Copy source and compile TypeScript → JavaScript into ./dist
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN npm run build

# Prune devDependencies so only production deps remain
RUN npm prune --omit=dev

# ============================
# Stage 2: Runtime
# ============================
# We use a fresh, minimal Node.js image.
# This image has NO build tools (no npm, no tsc) — just Node.
FROM node:22-alpine AS runtime

# Run as non-root user for security (best practice)
RUN addgroup -S nestjs && adduser -S nestjs -G nestjs

WORKDIR /app

# Copy only the production node_modules and compiled dist from builder
COPY --from=builder --chown=nestjs:nestjs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nestjs /app/dist ./dist
COPY --from=builder --chown=nestjs:nestjs /app/package.json ./

# Switch to non-root user
USER nestjs

# The application will listen on 3000 by default.
# This is documentation — it doesn't actually publish the port.
# Kubernetes uses this to know which port the container exposes.
EXPOSE 3000

# Start the app using the production script defined in package.json
CMD ["node", "dist/main"]