"""운영 데이터를 읽거나 쓰지 않고 배포 이미지의 브라우저 실행을 확인해요."""
from one_touch_loader.loaders.opta_shots_loader import open_browser


def main():
    with open_browser() as browser:
        browser.get("data:text/html,<title>1Touch Opta browser check</title>")
        if browser.title != "1Touch Opta browser check":
            raise RuntimeError("브라우저가 점검 페이지를 표시하지 못했어요.")
    print("PASS: Opta browser starts as the job user. No database changes.")


if __name__ == "__main__":
    main()
