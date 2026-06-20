"""
실행 진입점 (Entry Point)
- python -m budget_app 실행 시 이 파일이 실행된다.
- 실제 로직은 controller/cli_controller.py에 위임한다.
"""

from budget_app.controllers.cli_controller import build_controller, create_parser
from budget_app.decorators import handle_app_errors, timed
from typing import Sequence


@handle_app_errors
@timed
def main(argv: Sequence[str] | None = None, **kwargs: object) -> int:
    parser = create_parser()
    args = parser.parse_args(argv)
    controller = build_controller(args.data_dir)
    return controller.dispatch(args)


if __name__ == "__main__":
    raise SystemExit(main())
