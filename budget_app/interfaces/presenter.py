"""
출력 포트 인터페이스 (Presenter Port)
- 책임: UseCase의 결과를 사용자가 볼 수 있는 형태로 변환/출력하는 계약을 정의한다.
- 구현체: ConsolePresenter (텍스트 출력)
- 교체 예시: JSONPresenter, TablePresenter, WebJSONPresenter 등으로 교체 가능
"""

from abc import ABC, abstractmethod
from typing import Any

from budget_app.models.transaction import Transaction
from budget_app.models.import_result import ImportResult


class IPresenter(ABC):
    """출력 계약"""

    @abstractmethod
    def show_transaction(self, transaction: Transaction) -> None:
        """단일 거래를 출력 형식에 맞게 표시한다."""
        ...

    @abstractmethod
    def show_message(self, message: str) -> None:
        """일반 메시지를 표시한다."""
        ...

    @abstractmethod
    def show_error(self, message: str, hint: str) -> None:
        """오류 메시지와 해결 힌트를 표시한다."""
        ...

    @abstractmethod
    def show_summary(self, summary: dict[str, Any]) -> None:
        """월별 요약 결과를 표시한다."""
        ...

    @abstractmethod
    def show_import_result(self, result: ImportResult) -> None:
        """CSV Import 결과를 표시한다."""
        ...

    @abstractmethod
    def show_category_list(self, categories: list[str]) -> None:
        """카테고리 목록을 표시한다."""
        ...

    @abstractmethod
    def show_timing(self, elapsed: float) -> None:
        """실행 시간을 표시한다."""
        ...
