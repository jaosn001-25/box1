FROM node:20-alpine

WORKDIR /app

# 安装 Xray 及脚本所需的依赖工具
RUN apk add --no-cache bash curl wget unzip openssl ca-certificates coreutils

COPY package*.json ./
RUN npm install --production 2>/dev/null || true

COPY . .
RUN chmod +x start.sh

EXPOSE 3000/tcp

CMD ["node", "index.js"]