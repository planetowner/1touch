from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StrictBool, StringConstraints

Scope = Literal['community', 'team', 'player']
SubjectId = Annotated[int, Field(gt=0, strict=True)]


class PreferenceBody(BaseModel):
    model_config = ConfigDict(extra='forbid')
    preferences: dict[str, StrictBool] = Field(min_length=1)
    # 생략하면 현재 팔로우한 대상 전체에 적용해요. 이후 새로 팔로우할 대상은 포함하지 않아요.
    subject_ids: list[SubjectId] | None = Field(default=None, min_length=1, max_length=1000)


class PushDeviceBody(BaseModel):
    model_config = ConfigDict(extra='forbid')
    token: Annotated[str, StringConstraints(strip_whitespace=True, min_length=20, max_length=4096)]
    platform: Literal['android', 'ios']
    locale: Annotated[str, StringConstraints(pattern=r'^[a-zA-Z]{2,3}([-_][a-zA-Z0-9]{2,8}){0,2}$')] = 'en'


class ReadNotificationsBody(BaseModel):
    model_config = ConfigDict(extra='forbid')
    through_id: SubjectId
