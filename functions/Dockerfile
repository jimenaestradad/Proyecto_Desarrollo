FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm ci
ENV PORT=8080
CMD ["node", "server.js"]
