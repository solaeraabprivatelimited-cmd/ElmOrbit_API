FROM python:3.11.9-slim

# Cache-bust timestamp: 2026-04-14T06:22:00Z
# Set working directory
WORKDIR /app

# Install system dependencies for opencv, mediapipe, and graphics
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libopenblas0 \
    libharfbuzz0b \
    libwebp7 \
    libtiff6 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY monitoring_requirements.txt .

# Upgrade pip and install dependencies
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r monitoring_requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()"

# Run the application
CMD ["uvicorn", "monitoring_server:app", "--host", "0.0.0.0", "--port", "8000"]
