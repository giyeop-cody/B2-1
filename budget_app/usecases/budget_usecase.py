"""
예산 유즈케이스 (Budget UseCase)
- 책임: 월별 예산 설정과 월별 요약(수입/지출/잔액/TOP N/예산 사용률) 집계를 담당한다.
"""

from collections import defaultdict
from datetime import datetime
from typing import Any

from budget_app.interfaces.repository import IBudgetRepository, ITransactionRepository
from budget_app.models.budget import Budget
from budget_app.exceptions import ValidationError


class BudgetUseCase:
    def __init__(
        self,
        budget_repo: IBudgetRepository,
        transaction_repo: ITransactionRepository,
    ) -> None:
        self._budget_repo = budget_repo
        self._tx_repo = transaction_repo

    def set(self, month: str, amount: int) -> Budget:
        normalized_month = self._validate_month(month)
        normalized_amount = self._validate_amount(amount)
        budget = Budget(month=normalized_month, amount=normalized_amount)
        self._budget_repo.set(budget)
        return budget

    def summarize(self, month: str, top: int) -> dict[str, Any]:
        normalized_month = self._validate_month(month)
        expense_by_category: dict[str, int] = defaultdict(int)
        income_total = 0
        expense_total = 0

        for transaction in self._tx_repo.iter_all():
            if not transaction.date.startswith(normalized_month):
                continue
            if transaction.type == "income":
                income_total += transaction.amount
            else:
                expense_total += transaction.amount
                expense_by_category[transaction.category] += transaction.amount

        if income_total == 0 and expense_total == 0:
            return {"month": normalized_month, "empty": True}

        top_expenses = sorted(
            expense_by_category.items(),
            key=lambda item: (-item[1], item[0]),
        )[:top]

        budget = self._budget_repo.get(normalized_month)
        usage = None
        over_budget = False
        if budget is not None and budget.amount > 0:
            usage = round((expense_total / budget.amount) * 100, 2)
            over_budget = expense_total > budget.amount

        return {
            "month": normalized_month,
            "empty": False,
            "income_total": income_total,
            "expense_total": expense_total,
            "balance": income_total - expense_total,
            "top_expenses": top_expenses,
            "budget": budget.amount if budget else None,
            "usage": usage,
            "over_budget": over_budget,
        }

    def _validate_month(self, value: str) -> str:
        try:
            return datetime.strptime(value, "%Y-%m").strftime("%Y-%m")
        except ValueError as error:
            raise ValidationError("월 형식이 올바르지 않습니다.", "YYYY-MM 형식으로 입력하세요.") from error

    def _validate_amount(self, value: int) -> int:
        amount = int(value)
        if amount <= 0:
            raise ValidationError("금액은 0보다 커야 합니다.", "양의 정수를 입력하세요.")
        return amount
