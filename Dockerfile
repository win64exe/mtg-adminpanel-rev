# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /build

# Copy frontend source
COPY frontend/package.json frontend/package-lock.json* ./frontend/
RUN cd frontend && npm install

COPY frontend/ ./frontend/
COPY backend/ ./backend/

# vite builds to ../backend/public (relative to frontend dir = /build/frontend)
RUN cd frontend && npm run build

# Stage 2: Production backend
FROM node:20-alpine

# Install dependencies for better-sqlite3
RUN apk add --no-cache python3 make g++

WORKDIR /app

COPY backend/package.json ./
RUN npm install --production

COPY backend/src ./src

# Copy built frontend
COPY --from=frontend-builder /build/backend/public ./public

EXPOSE 3000

CMD ["node", "src/app.js"]
