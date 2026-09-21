"""기본 실행은 역할 미리보기예요. --apply를 지정할 때만 기존 역할 컬럼을 갱신해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from one_touch_loader.loaders.squad_roles_loader import preview_squad_roles, save_current_squad_roles


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='계산한 현재 시즌 역할만 DB에 저장해요.')
    parser.add_argument('--report', type=Path, required=True, help='선수별 계산 근거를 저장할 로컬 JSON 경로예요.')
    parser.add_argument('--calibration-output', type=Path, help='직전 5개 시즌으로 새 기준을 학습해 저장할 경로예요.')
    args = parser.parse_args()
    if args.apply and args.calibration_output is not None:
        parser.error('Deploy the recalibrated model before applying current roles')
    report = preview_squad_roles(recalibrate=args.calibration_output is not None)
    if args.calibration_output is not None:
        # 학습 모델을 검토해 배포한 뒤 같은 모델로 역할을 저장하도록 학습과 적용을 분리해요.
        args.calibration_output.parent.mkdir(parents=True, exist_ok=True)
        model = dict(report['model'], calibrated_at=report['as_of'])
        args.calibration_output.write_text(json.dumps(model, indent=2)+'\n', encoding='utf-8')
    report['applied'] = False
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    if args.apply:
        report['updated_rows'] = save_current_squad_roles(report['players'])
        report['applied'] = True
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('as_of', 'applied', 'role_counts', 'current_unavailable')}, indent=2))


if __name__ == '__main__':
    main()
