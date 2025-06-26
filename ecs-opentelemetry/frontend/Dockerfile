# Stage 1: Build the application
FROM node:20.15.1-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

# Set NEXT_TELEMETRY_DISABLED to 1 to prevent Next.js from sending telemetry data
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# Stage 2: Create the production image
FROM node:20.15.1-alpine

WORKDIR /app

# Create a non-privileged user
RUN addgroup --system nextjs && adduser --system --group nextjs

# Copy built assets from builder stage
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nextjs /app/.next/standalone ./ 
COPY --from=builder --chown=nextjs:nextjs /app/.next/static ./.next/static

# Switch to the non-privileged user
USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV NEXT_TELEMETRY_DISABLED 1

# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget -q --spider http://localhost:3000 || exit 1

# Start the application using the standalone server
CMD ["node", "server.js"]