# frontend/Dockerfile

# 1. Use a lightweight Nginx image
FROM nginx:alpine

# 2. Copy our HTML files to the Nginx public folder
# Nginx automatically serves anything in this folder
COPY . /usr/share/nginx/html

# 3. Expose port 80 (standard web port)
EXPOSE 80