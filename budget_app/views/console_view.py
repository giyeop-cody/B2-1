"""
콘솔 UI 구현 (Console View)
- 책임: IView 계약을 구현하여 터미널 대화형 입출력을 제공한다.
- 의존: interfaces.view, exceptions (ValidationError)
- 교체: IView를 구현하는 GUI, Web, TUI 등으로 교체 가능
"""

from typing import Any

from budget_app.interfaces.view import IView
from budget_app.exceptions import ValidationError


class ConsoleView(IView):
    def prompt_transaction_input(self, categories: list[str]) -> dict[str, Any]:
        if not categories:
            raise ValidationError(
                "등록된 카테고리가 없습니다.",
                "먼저 category add --name <이름> 명령으로 카테고리를 추가하세요.",
            )
        print("사용 가능한 카테고리:", ", ".join(categories))
        date = input("날짜 (YYYY-MM-DD): ").strip()
        transaction_type = input("타입 (income/expense): ").strip()
        category = input("카테고리: ").strip()
        amount_text = input("금액: ").strip()
        try:
            amount = int(amount_text)
        except ValueError as error:
            raise ValidationError("금액은 숫자로 입력해야 합니다.", "예: 15000") from error
        memo = input("메모 (선택): ").strip()
        tags = input("태그 (쉼표 구분, 선택): ").strip()
        return {
            "date": date,
            "transaction_type": transaction_type,
            "category": category,
            "amount": amount,
            "memo": memo,
            "tags": [tag.strip() for tag in tags.split(",") if tag.strip()],
        }

    def show_line(self, text: str) -> None:
        print(text)

    def show_result(self, text: str) -> None:
        print(text)

    def show_error(self, message: str, hint: str) -> None:
        print(f"오류: {message}")
        print(f"해결 힌트: {hint}")

    def show_categories(self, categories: list[str]) -> None:
        for category in categories:
            print(category)
