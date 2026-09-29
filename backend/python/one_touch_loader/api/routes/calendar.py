from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Response
from pydantic import BaseModel, Field

from ..deps import get_user_id
from ..repos import calendar_repo
from ..repos.teams_repo import get_team
from ..services.calendar_schedule import load_schedule, render_icalendar
from ..services.google_calendar import GoogleCalendarError

router = APIRouter()
TeamId = Annotated[int, Path(gt=0)]


class GoogleCalendarBody(BaseModel):
    server_auth_code: str = Field(min_length=1, max_length=4096)


def _google_action(action, *args):
    try:
        return action(*args)
    except GoogleCalendarError as error:
        raise HTTPException(error.status, {"code": error.code}) from error


@router.get("/calendars/teams/{team_id}.ics")
def team_calendar(team_id: TeamId):
    # 캘린더 앱은 1Touch 로그인 헤더를 보낼 수 없어요. 공개 경기 정보만 이 주소에 담아요.
    team = get_team(team_id)
    if team is None:
        raise HTTPException(404, "Team not found")
    now = datetime.now(timezone.utc)
    return Response(render_icalendar(team["name"], load_schedule([team_id], now), now),
                    media_type="text/calendar", headers={"Cache-Control": "public, max-age=300"})


@router.get("/users/me/calendar/teams/{team_id}")
def calendar_status(team_id: TeamId, user_id: int = Depends(get_user_id)):
    return calendar_repo.status(user_id, team_id)


@router.post("/users/me/calendar/google")
def connect_calendar(body: GoogleCalendarBody, user_id: int = Depends(get_user_id)):
    _google_action(calendar_repo.connect, user_id, body.server_auth_code)
    return {"ok": True}


@router.put("/users/me/calendar/teams/{team_id}")
def subscribe(team_id: TeamId, user_id: int = Depends(get_user_id)):
    count = _google_action(calendar_repo.set_subscription, user_id, team_id, True)
    return {"synced_matches": count}


@router.delete("/users/me/calendar/teams/{team_id}")
def unsubscribe(team_id: TeamId, user_id: int = Depends(get_user_id)):
    _google_action(calendar_repo.set_subscription, user_id, team_id, False)
    return {"ok": True}


@router.delete("/users/me/calendar/google")
def disconnect_calendar(user_id: int = Depends(get_user_id)):
    calendar_repo.disconnect(user_id)
    return {"ok": True}
