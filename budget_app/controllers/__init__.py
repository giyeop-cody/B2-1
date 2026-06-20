"""
컨트롤러 계층 (Controller / Input Adapter Layer)
- 사용자 입력(argparse)을 해석하고 적절한 UseCase를 호출한다.
- UseCase의 결과를 Presenter/View에 전달한다.
- CLI, Web, GUI 등 어떤 입력 채널이든 이 계층만 교체하면 된다.
"""

from budget_app.controllers.cli_controller import CLIController, build_controller

__all__ = ["CLIController", "build_controller"]
