FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Expose port (SnapDeploy will map this automatically)
EXPOSE 3000

CMD ["npm", "start"]
