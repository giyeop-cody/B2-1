"""
출력 구현 계층 (Presenter Adapters)
- 인터페이스 계층의 IPresenter를 구현한다.
- UseCase의 결과를 특정 형식(콘솔 텍스트, JSON, 테이블 등)으로 변환한다.
- 교체 가능성: ConsolePresenter → JSONPresenter, TablePresenter, WebPresenter 등
"""

from budget_app.presenters.console_presenter import ConsolePresenter

__all__ = ["ConsolePresenter"]
