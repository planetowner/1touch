FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
# 예약 수집도 로컬과 같은 공개 화면을 읽어요. 브라우저와 드라이버 버전을 함께 설치해요.
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium chromium-driver \
    && rm -rf /var/lib/apt/lists/*
# Compose의 기존 UID에 홈 디렉터리를 연결해 브라우저 임시 설정을 쓸 수 있게 해요.
RUN groupadd --gid 1001 onetouch \
    && useradd --uid 1001 --gid 1001 --create-home onetouch
COPY requirements.txt ./
COPY deploy/vultr/constraints.txt ./deploy/vultr/constraints.txt
# 로컬에서 쓰는 수치 계산 패키지 버전을 이전 중에도 유지해요.
RUN pip install --no-cache-dir -r requirements.txt -c deploy/vultr/constraints.txt

COPY python ./python
COPY deploy/vultr/transfer.py ./deploy/vultr/transfer.py
WORKDIR /app/python
CMD ["python", "-m", "one_touch_loader.api"]
