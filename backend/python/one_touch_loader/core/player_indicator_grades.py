"""지표 계산과 API 응답이 같은 5단계 등급명을 사용해요."""
from typing import Literal, get_args


IndicatorGrade = Literal["Very Poor", "Poor", "Fair", "Good", "Very Good"]
GRADE_LABELS = get_args(IndicatorGrade)


def with_current_grade_labels(indicators: dict) -> dict:
    # 저장된 옛 등급명도 API와 배포 점검에서 같은 이름으로 읽어요. 점수는 다시 계산하지 않아요.
    result = dict(indicators)
    for key in ("form", "cost_effectiveness"):
        score = result[key]
        band = score["band"]
        result[key] = {**score, "grade": GRADE_LABELS[band] if band is not None else None}
    return result
