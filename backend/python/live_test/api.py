"""운영과 같은 API를 별도 테스트 DB에 연결해요."""
from . import require_test_database

require_test_database()

from one_touch_loader.api.main import app  # noqa: E402

app.title = '1touch Live Test API'
