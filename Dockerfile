# Production Dockerfile for PDS DemandSync (FastAPI + Embedded Flutter Web)

# Stage 1: Build Flutter Web Application
FROM ghcr.io/cirrusci/flutter:stable AS flutter-builder
WORKDIR /app
COPY frontend/ ./frontend/
WORKDIR /app/frontend
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Production Python FastAPI Server
FROM python:3.11-slim
WORKDIR /app

# Set environment variables for production
ENV ENVIRONMENT=production
ENV SECRET_KEY=a_very_long_secure_random_production_secret_key_minimum_32_characters_railway
ENV HOST=0.0.0.0
ENV PYTHONUNBUFFERED=1

# Install backend dependencies
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r backend/requirements.txt
RUN pip install --no-cache-dir python-multipart

# Copy backend source code
COPY backend/ ./backend/

# Copy freshly built Flutter Web assets from Stage 1 over to static_web
COPY --from=flutter-builder /app/frontend/build/web/ ./backend/app/static_web/

# Set working directory to backend
WORKDIR /app/backend

EXPOSE 8000

# Launch Uvicorn server using shell execution format for dynamic PORT evaluation
CMD sh -c "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"

