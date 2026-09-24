FROM python:3.12-slim

WORKDIR /app
COPY docker_metrics.py .

EXPOSE 9100
ENTRYPOINT ["python", "docker_metrics.py"]
