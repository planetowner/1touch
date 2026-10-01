from enum import Enum

from pydantic import AwareDatetime, BaseModel


class CommunityBanReason(str, Enum):
    harassment = "harassment"
    hate_speech = "hate_speech"
    violent_language = "violent_language"
    spam = "spam"
    disruption = "disruption"
    personal_information = "personal_information"
    inappropriate_content = "inappropriate_content"
    harmful_to_minors = "harmful_to_minors"
    impersonation = "impersonation"
    illegal_content = "illegal_content"
    service_misuse = "service_misuse"
    guidelines_violation = "guidelines_violation"


class CommunitySuspension(BaseModel):
    # 기존 제재에는 사유가 없으므로 임의의 위반 사유로 채우지 않아요.
    reason: CommunityBanReason | None
    ends_at: AwareDatetime


class CommunitySuspensionResponse(BaseModel):
    suspension: CommunitySuspension | None


class CommunityRule(BaseModel):
    title: str
    body: str


class CommunityRules(BaseModel):
    title: str
    items: list[CommunityRule]


class CommunityRulesResponse(BaseModel):
    rules: CommunityRules
