# RF Test Runner Container
# Professional Docker image for Robot Framework test execution
# Python 3.11 slim base for minimal footprint

FROM python:3.11-slim

LABEL maintainer="Automation Team"
LABEL description="RF Equipment Test Automation Runner"
LABEL version="1.0.0"

# Prevent Python from writing pyc files and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
# - iputils-ping: Network connectivity testing
# - curl: HTTP requests and health checks
# - vim: Quick file editing for debugging
# - net-tools: Network diagnostics
# - wget: Download Allure CLI
# - default-jre-headless: Java runtime for Allure (headless to save space)
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping \
    iproute2 \
    curl \
    vim \
    net-tools \
    wget \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install Allure CLI
# Download and install Allure commandline tool for report generation
ARG ALLURE_VERSION=2.25.0
RUN wget -q https://github.com/allure-framework/allure2/releases/download/${ALLURE_VERSION}/allure-${ALLURE_VERSION}.tgz && \
    tar -zxf allure-${ALLURE_VERSION}.tgz -C /opt/ && \
    ln -s /opt/allure-${ALLURE_VERSION}/bin/allure /usr/bin/allure && \
    rm allure-${ALLURE_VERSION}.tgz

# Verify Allure installation
RUN allure --version

# Set working directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY tests/ ./tests/
COPY resources/ ./resources/
COPY scripts/ ./scripts/
COPY config/ ./config/

# Create directories for results and logs
RUN mkdir -p /app/results /app/logs

# Set proper permissions
RUN chmod -R 755 /app

# Health check - verify Robot Framework is installed
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import robot; print(robot.__version__)" || exit 1

# Default entry point - Robot Framework
ENTRYPOINT ["robot"]

# Default command - run all tests with verbose output
CMD ["--outputdir", "results", "--loglevel", "INFO", "tests/"]
