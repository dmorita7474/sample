
# Stage 1: Build stage
FROM python:3.12.4-slim AS builder

# Install uv
RUN pip install uv

WORKDIR /code

# Copy requirements and install dependencies into a virtual environment
COPY requirements.txt .
RUN uv venv /opt/venv && \
    /opt/venv/bin/uv pip install --no-cache --system -r requirements.txt

# Stage 2: Final stage
FROM python:3.12.4-slim

# Create a non-privileged user
RUN addgroup --system app && adduser --system --group app

WORKDIR /home/app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code
COPY ./app ./app

# Change ownership
RUN chown -R app:app /home/app

# Switch to the non-privileged user
USER app

# Set path to include venv
ENV PATH="/opt/venv/bin:$PATH"

EXPOSE 8000

# Use the new health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
