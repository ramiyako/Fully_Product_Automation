FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose ports
# SCPI port (configurable via SCPI_PORT env var, default 5025)
EXPOSE 5025
# HTTP admin interface (default 8000)
EXPOSE 8000

# Environment variables with defaults
ENV EQUIPMENT_TYPE=spectrum_analyzer
ENV SCPI_PORT=5025
ENV HTTP_PORT=8000
ENV HTTP_HOST=0.0.0.0
ENV ENABLE_HARMONICS=true
ENV ENABLE_INTERMOD=true
ENV HARMONIC_ORDER=3
ENV NOISE_FLOOR_DBM=-120

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["python", "-m", "mock_equipment.main"]
