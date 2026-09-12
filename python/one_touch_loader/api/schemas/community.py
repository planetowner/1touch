from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


CommunityLanguage = Literal["ko", "en"]


class RulesBody(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    body: str = Field(min_length=1, max_length=10000)
