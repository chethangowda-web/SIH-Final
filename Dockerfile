# Production Dockerfile for PDS DemandSync (FastAPI + Embedded Flutter Web)
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

# Copy backend source code (including prebuilt static_web)
COPY backend/ ./backend/

# Set working directory to backend
WORKDIR /app/backend

# Pre-seed SQLite database during image build so startup is instant (<10ms)
RUN python -c "from app.core.database import init_db; init_db()"

EXPOSE 8000

# Launch Uvicorn server using exec format for signal handling & dynamic PORT evaluation
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
