FROM node:20-alpine
  
WORKDIR /app

COPY package*.json ./
RUN apk add --no-cache bash curl && \
    npm install

COPY . .
RUN chmod +x start.sh

EXPOSE 3000/tcp

CMD ["node", "index.js"]