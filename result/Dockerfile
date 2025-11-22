FROM node:18-alpine

WORKDIR /app

# Add wget for health checks
RUN apk add --no-cache wget

# Add a non-root user (node image already has a 'node' user, but we can be explicit or use it)
# The 'node' user exists in the official image with uid 1000
RUN chown -R node:node /app

COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

COPY . .

USER node

EXPOSE 80

ENV PORT 80

CMD ["node", "server.js"]
