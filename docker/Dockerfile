FROM node:20-alpine AS base
WORKDIR /app

# Install server deps
COPY server/package.json server/package-lock.json* ./server/
RUN cd server && npm install --production

# Copy server source and manifest data
COPY server/src ./server/src
COPY nodes ./nodes
COPY examples ./examples
COPY schema ./schema

ENV PORT=3000
ENV SKILLS_DIR=/app/nodes,/app/examples
ENV NODE_ENV=production

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://localhost:3000/v1 || exit 1

CMD ["node", "server/src/server.js"]
