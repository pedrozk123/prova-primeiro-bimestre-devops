# ---- Estágio 1: instala dependências de produção ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# ---- Estágio 2: imagem final ----
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src

# roda como usuário sem privilégios (já existe na imagem do node)
USER node

EXPOSE 3000
CMD ["npm", "start"]