"""앱 실행 여부와 관계없이 연결된 Google 캘린더를 갱신해요."""
import argparse
import logging

from ..api.repos.calendar_repo import sync_user, users_to_sync
from ..api.services.google_calendar import configured, GoogleCalendarError


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="연결된 Google 캘린더의 일정을 갱신해요.")
    args = parser.parse_args()
    if not args.apply:
        parser.error("실제 캘린더를 갱신하려면 --apply를 지정해 주세요.")
    configured()
    failed = 0
    for user_id in users_to_sync():
        try:
            count = sync_user(user_id)
            logging.info("Calendar sync user=%s matches=%s", user_id, count)
        except GoogleCalendarError as error:
            failed += 1
            logging.error("Calendar sync user=%s code=%s", user_id, error.code)
        except Exception:
            # 예외 본문에 공급자 인증값이 포함될 수 있어 유형만 기록해요.
            failed += 1
            logging.error("Calendar sync user=%s code=internal_error", user_id)
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main()
