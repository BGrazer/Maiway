# Stage 1: Build the Flutter application
FROM cirrusci/flutter:3.22.2 AS build

WORKDIR /app

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code
COPY . .

# Build the Flutter web application
RUN dart pub run build_runner build --delete-conflicting-outputs
RUN flutter build web --release

# Stage 2: Serve the application with Nginx
FROM nginx:stable-alpine AS server

# Copy the built web application from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80 for Nginx
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]