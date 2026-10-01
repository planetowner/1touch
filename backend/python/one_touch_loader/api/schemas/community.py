from pydantic import BaseModel


class CommunityRule(BaseModel):
    title: str
    body: str


class CommunityRules(BaseModel):
    title: str
    items: list[CommunityRule]


class CommunityRulesResponse(BaseModel):
    rules: CommunityRules
