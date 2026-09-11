from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from ..db import fetch_all_dict, transaction
from ..deps import get_user_id
from ..repos.users_repo import get_user, lock_user, update_profile
from ..repos import users_repo
from ..schemas.users import DeleteAccountBody, UserProfileBody
from ..services.community_periods import public_row

router = APIRouter()


@router.get("/users/me")
def my_profile(user_id: int = Depends(get_user_id)):
    user = get_user(user_id)
    user["avatar_url"] = f"/v1/users/{user_id}/avatar" if fetch_all_dict(
        "SELECT 1 FROM user_avatars WHERE user_id=%s", (user_id,)) else None
    return {**public_row(user), "onboarding_complete": all(
        user[key] for key in ("username", "first_name", "last_name", "timezone", "favorite_team_id"))}


@router.put("/users/me/profile")
def put_profile(body: UserProfileBody, user_id: int = Depends(get_user_id)):
    update_profile(user_id, body.model_dump())
    return my_profile(user_id)


@router.delete("/users/me")
def delete_account(body: DeleteAccountBody | None = None, user_id: int = Depends(get_user_id)):
    users_repo.delete_account(user_id, body.model_dump(exclude_none=True) if body else None)
    return {"ok": True}


@router.get("/users/me/blocks")
def blocks(user_id: int = Depends(get_user_id)):
    return {"items": users_repo.list_blocks(user_id)}


@router.put("/users/me/blocks/{blocked_user_id}")
def block_user(blocked_user_id: int, user_id: int = Depends(get_user_id)):
    users_repo.set_block(user_id, blocked_user_id, True)
    return {"ok": True}


@router.delete("/users/me/blocks/{blocked_user_id}")
def unblock_user(blocked_user_id: int, user_id: int = Depends(get_user_id)):
    users_repo.set_block(user_id, blocked_user_id, False)
    return {"ok": True}


class FollowingPlayersBody(BaseModel):
    player_ids: list[int] = Field(max_length=1000)


@router.get("/users/me/following/players")
def following_players(user_id: int = Depends(get_user_id)):
    return {"items": fetch_all_dict("""SELECT p.player_id,p.display_name AS name,p.image_path
        FROM user_following_players f JOIN players p ON p.player_id=f.player_id
        WHERE f.user_id=%s ORDER BY f.position""", (user_id,))}


@router.put("/users/me/following/players")
def put_following_players(body: FollowingPlayersBody, user_id: int = Depends(get_user_id)):
    ids = body.player_ids
    if len(ids) != len(set(ids)):
        raise HTTPException(400, "Repeated player ID")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        if ids:
            cur.execute(f"SELECT player_id FROM players WHERE player_id IN ({','.join(['%s'] * len(ids))})", tuple(ids))
            if {row["player_id"] for row in cur.fetchall()} != set(ids):
                raise HTTPException(400, "Unknown player ID")
        cur.execute("DELETE FROM user_following_players WHERE user_id=%s", (user_id,))
        if ids:
            cur.executemany("INSERT INTO user_following_players VALUES (%s,%s,%s)",
                            [(user_id, player_id, position) for position, player_id in enumerate(ids)])
    return {"ok": True}
