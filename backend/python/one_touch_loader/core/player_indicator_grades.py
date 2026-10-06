"""지표 계산과 API 응답이 같은 5단계 등급명을 사용해요."""
from typing import Literal, get_args


IndicatorGrade = Literal["Very Poor", "Poor", "Fair", "Good", "Very Good"]
GRADE_LABELS = get_args(IndicatorGrade)
