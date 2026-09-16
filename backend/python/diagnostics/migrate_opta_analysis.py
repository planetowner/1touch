"""기본은 사전 검사예요. --apply를 직접 실행하면 백업 후 패스·수비 행동 테이블을 추가해요."""

from diagnostics.migrate_opta_shots import main


if __name__ == "__main__":
    main(dataset="analysis")
