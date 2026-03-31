FROM node:18              # Uses official Node.js version 18 image as base
 
WORKDIR /app             # Sets working directory inside container to /app
 
COPY . .                 # Copies all files from current directory to /app inside container
 
RUN npm install          # Installs all dependencies defined in package.json
 
CMD ["node", "server.js"]  # Default command to start the application
