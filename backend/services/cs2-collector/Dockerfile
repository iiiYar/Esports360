FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# System deps for lxml
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libxml2 \
        libxslt1.1 \
    && rm -rf /var/lib/apt/lists/*

COPY services/cs2-collector/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/shared/esports360 ./esports360
COPY services/cs2-collector/engines/ ./engines/
COPY services/cs2-collector/main.py .

CMD ["python", "main.py"]

