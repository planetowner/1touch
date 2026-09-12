"""임시저장 글과 미사용 첨부에 같은 보관 기간을 적용해요."""
from datetime import timedelta

# 초안은 마지막 저장, 글에 연결하지 않은 첨부는 업로드 시각부터 계산해요.
UNPUBLISHED_RETENTION = timedelta(days=7)
