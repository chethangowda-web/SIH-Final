# Stage 1: Build the Flutter Web App
FROM ghcr.io/cirruslabs/flutter:stable AS frontend-builder
WORKDIR /app/frontend
COPY frontend/ ./
# Resolve dependencies and build for web
RUN flutter pub get
RUN flutter build web --release --base-href "/app/"

# Stage 2: Build the Python Backend
FROM python:3.11-slim
WORKDIR /app

# Set environment variables for production
ENV ENVIRONMENT=production
# Provide a default secure secret key (for Railway deployment)
ENV SECRET_KEY=a_very_long_secure_random_production_secret_key_minimum_32_characters_railway
ENV HOST=0.0.0.0
# Railway passes PORT environment variable dynamically
ENV PORT=8000
# Ensure stdout/stderr are unbuffered for logs
ENV PYTHONUNBUFFERED=1

# Install backend dependencies
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy backend source code
COPY backend/ ./backend/

# Copy the built Flutter web files from the frontend-builder stage
COPY --from=frontend-builder /app/frontend/build/web ./frontend/build/web

# Set the working directory to backend so server.py/uvicorn runs correctly
WORKDIR /app/backend

# The start command that respects Railway's dynamic $PORT variable
CMD python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
