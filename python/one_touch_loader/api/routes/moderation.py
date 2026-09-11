from datetime import datetime, timezone
from typing import Literal
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator
from ..deps import get_user_id
from ..repos import community_repo, moderation_repo

router = APIRouter()


def get_admin_id(user_id: int = Depends(get_user_id)) -> int:
    return moderation_repo.require_admin(user_id)


class ResolutionBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resolution: Literal["dismissed", "hidden"]


class RulesBody(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    body: str = Field(min_length=1, max_length=10000)


class SuspensionBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    suspended_until: datetime | None

    @field_validator("suspended_until")
    @classmethod
    def utc_end(cls, value):
        if value is not None:
            if value.tzinfo is None:
                raise ValueError("Include a timezone offset")
            return value.astimezone(timezone.utc).replace(tzinfo=None)
        return None


@router.get("/admin/reports")
def reports(resolved: bool = False, after_id: int = Query(default=0, ge=0),
            limit: int = Query(default=50, ge=1, le=100), admin_id: int = Depends(get_admin_id)):
    return {"items": moderation_repo.list_reports(admin_id, resolved, after_id, limit)}


@router.get("/admin/community/rules")
def rules(admin_id: int = Depends(get_admin_id)):
    return {"rules": community_repo.read_rules()}


@router.put("/admin/community/rules")
def save_rules(body: RulesBody, admin_id: int = Depends(get_admin_id)):
    community_repo.set_rules(admin_id, body.body)
    return {"ok": True}


@router.put("/admin/reports/{report_id}")
def resolve(report_id: int, body: ResolutionBody, admin_id: int = Depends(get_admin_id)):
    moderation_repo.resolve_report(admin_id, report_id, body.resolution)
    return {"ok": True}


@router.put("/admin/users/{user_id}/suspension")
def suspend(user_id: int, body: SuspensionBody, admin_id: int = Depends(get_admin_id)):
    moderation_repo.set_suspension(admin_id, user_id, body.suspended_until)
    return {"ok": True}
