FROM python:3.11-slim

WORKDIR /app

# Add a non-root user
RUN adduser --disabled-password --gecos "" appuser

# Install apache2-utils for ab
RUN apt-get update && apt-get install -y apache2-utils && rm -rf /var/lib/apt/lists/*

COPY make-data.py .
COPY generate-votes.sh .

# Ensure the shell script is executable
RUN chmod +x generate-votes.sh

# Change ownership
RUN chown -R appuser:appuser /app

USER appuser

ENTRYPOINT ["./generate-votes.sh"]
