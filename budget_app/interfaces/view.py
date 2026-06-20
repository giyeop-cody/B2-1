"""
뷰 인터페이스 (View Port)
- 책임: 사용자와의 직접적인 입출력 계약을 정의한다.
- 구현체: ConsoleView (터미널 대화형)
- 교체 예시: WebView, GUIView, TUIView 등으로 교체 가능
"""

from abc import ABC, abstractmethod
from typing import Any


class IView(ABC):
    """UI 계약"""

    @abstractmethod
    def prompt_transaction_input(self, categories: list[str]) -> dict[str, Any]:
        """대화형으로 거래 입력을 받아 dict로 반환한다."""
        ...

    @abstractmethod
    def show_line(self, text: str) -> None:
        """한 줄을 표시한다."""
        ...

    @abstractmethod
    def show_result(self, text: str) -> None:
        """결과 메시지를 표시한다."""
        ...

    @abstractmethod
    def show_error(self, message: str, hint: str) -> None:
        """오류 메시지를 표시한다."""
        ...

    @abstractmethod
    def show_categories(self, categories: list[str]) -> None:
        """카테고리 목록을 표시한다."""
        ...
