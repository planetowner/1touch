from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from ..deps import get_token, get_user_id
from ..repos import notifications_repo as repo
from ..schemas.notifications import PreferenceBody, PushDeviceBody, ReadNotificationsBody, Scope

router = APIRouter()


@router.get('/users/me/notification-preferences')
def preferences(user_id: int = Depends(get_user_id)):
    return repo.preference_snapshot(user_id)


@router.patch('/users/me/notification-preferences/{scope}')
def change_preferences(scope: Scope, body: PreferenceBody, user_id: int = Depends(get_user_id)):
    repo.update_preferences(user_id, scope, body.preferences, body.subject_ids)
    return repo.preference_snapshot(user_id)


@router.put('/users/me/push-devices/{device_id}')
def register_device(device_id: UUID, body: PushDeviceBody, user_id: int = Depends(get_user_id),
                    token: str = Depends(get_token)):
    repo.register_device(user_id, token, str(device_id), body.model_dump())
    return {'ok': True}


@router.delete('/users/me/push-devices/{device_id}')
def unregister_device(device_id: UUID, user_id: int = Depends(get_user_id)):
    repo.unregister_device(user_id, str(device_id))
    return {'ok': True}


@router.get('/users/me/notifications')
def notifications(user_id: int = Depends(get_user_id), before_id: Annotated[int | None, Query(gt=0)] = None,
                  limit: Annotated[int, Query(ge=1, le=100)] = 30,
                  team_id: Annotated[int | None, Query(gt=0)] = None):
    return repo.list_community(user_id, before_id=before_id, limit=limit, team_id=team_id)


@router.post('/users/me/notifications/read')
def read_notifications(body: ReadNotificationsBody, user_id: int = Depends(get_user_id)):
    repo.mark_read(user_id, body.through_id)
    return {'ok': True}
