# 1. Use an official, lightweight Node.js image
FROM node:18-alpine

# 2. Set the working directory inside the container
WORKDIR /usr/src/app

# 3. Copy your package files first (for efficient caching)
COPY package*.json ./

# 4. Install your dependencies (excluding dev dependencies like nodemon)
RUN npm install --omit=dev

# 5. Copy the rest of your backend code into the container
COPY . .

# 6. Expose the port your server runs on
EXPOSE 3000

# 7. Start the application
CMD ["node", "server.js"]