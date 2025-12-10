FROM python:3.12-slim

# Set the application directory via build argument
ARG APP_DIR

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Set working directory
WORKDIR /app

# Install system dependencies (now includes curl)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for Docker layer caching)
COPY ${APP_DIR}/requirements.txt .

# Install dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# ---- App layer ----
COPY ${APP_DIR}/ .

# Create non-root user for security (Kubernetes best practice)
RUN useradd -m flaskuser
USER flaskuser

EXPOSE 8080

# Gunicorn recommended for Flask in production:
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
