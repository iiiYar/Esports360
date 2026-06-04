FROM node:20-alpine
WORKDIR /app
COPY services/cs2-gc-node-collector/package.json ./
RUN npm install --no-audit --no-fund
COPY services/cs2-gc-node-collector/collector.js ./
CMD ["node", "collector.js"]
