FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt ./
COPY deploy/vultr/constraints.txt ./deploy/vultr/constraints.txt
# 로컬에서 쓰는 수치 계산 패키지 버전을 이전 중에도 유지해요.
RUN pip install --no-cache-dir -r requirements.txt -c deploy/vultr/constraints.txt

COPY python ./python
COPY deploy/vultr/transfer.py ./deploy/vultr/transfer.py
WORKDIR /app/python
CMD ["python", "-m", "one_touch_loader.api"]
