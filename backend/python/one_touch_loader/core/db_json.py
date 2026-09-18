"""DB 드라이버와 시험 DB가 반환하는 JSON을 같은 방식으로 읽어요."""
import json


def decoded(value):
    return json.loads(value) if isinstance(value, (str, bytes)) else value
