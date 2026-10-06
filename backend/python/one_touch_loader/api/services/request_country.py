"""로그인 추천·하이라이트·포인트 적립에서 같은 접속 국가를 사용해요."""
from ipaddress import ip_address
import logging
import os

from fastapi import HTTPException, Request, Response
import maxminddb


logger = logging.getLogger(__name__)


def country_for_ip(client_ip: str | None) -> str | None:
    if client_ip is None:
        return None
    try:
        address = ip_address(client_ip)
    except ValueError:
        return None
    if address.version == 6 and address.ipv4_mapped is not None:
        address = address.ipv4_mapped
    if not address.is_global:
        return None

    database_path = os.environ.get("GEOIP_COUNTRY_DATABASE")
    if not database_path:
        raise HTTPException(503, "Request country database is not configured")
    try:
        # 갱신 도구가 교체한 DB를 다음 요청부터 읽어요. 사용자 IP는 외부로 보내지 않아요.
        with maxminddb.open_database(database_path) as database:
            record = database.get(address)
    except (OSError, maxminddb.InvalidDatabaseError) as exc:
        logger.exception("Request country database could not be read")
        raise HTTPException(503, "Request country database is unavailable") from exc

    # registered_country는 IP 소유자의 등록 국가라 실제 접속 국가 대신 쓰지 않아요.
    return (record or {}).get("country", {}).get("iso_code")


def get_request_country(request: Request, response: Response) -> str | None:
    response.headers["Cache-Control"] = "private, no-store"
    # Caddy와 Uvicorn이 확인한 IP만 써요. 앱의 국가값·전달 헤더는 직접 신뢰하지 않아요.
    return country_for_ip(request.client.host if request.client else None)
