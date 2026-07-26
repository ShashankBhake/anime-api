FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps:
# - botan3/botan-cli for anime.sh crypto steps
# - curl/coreutils/sed/grep/dd/od for the shell script
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        botan \
        curl \
        coreutils \
        grep \
        sed \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chmod +x /app/anime.sh

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "180", "app:app"]
