from typing import Literal
from pydantic import BaseModel


# 중국어는 확정된 간체 문구만 제공해요. 로그인 국가 코드 CN과 구분해요.
CommunityLanguage = Literal["ko", "en", "ja", "zh-Hans"]


class CommunityRule(BaseModel):
    title: str
    body: str


class CommunityRules(BaseModel):
    language: CommunityLanguage
    title: str
    items: list[CommunityRule]
    confirm_label: str


class CommunityRulesResponse(BaseModel):
    rules: CommunityRules
