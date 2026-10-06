"""커뮤니티 자료의 종류별 보관 기간을 한곳에서 정해요."""
from datetime import timedelta

# 초안은 마지막 저장, 글에 연결하지 않은 첨부는 업로드 시각부터 계산해요.
UNPUBLISHED_RETENTION = timedelta(days=7)

# 처리 이의에 대응할 기간을 두고, 약 6개월을 일수로 명확하게 적용해요.
RESOLVED_REPORT_RETENTION = timedelta(days=180)
