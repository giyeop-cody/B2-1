"""
예산 저장소 구현 (JSONL)
- 책임: 월별 예산의 파일 기반 저장과 조회를 담당한다.
- 의존: interfaces.repository (계약), models.budget, infrastructure.jsonl_storage
- 교체: IBudgetRepository를 구현하는 SQLite, Redis 등으로 교체 가능
"""

from pathlib import Path
from typing import Optional

from budget_app.interfaces.repository import IBudgetRepository
from budget_app.models.budget import Budget
from budget_app.infrastructure import jsonl_storage as storage


class JSONLBudgetRepository(IBudgetRepository):
    def __init__(self, path: Path) -> None:
        self._path = path

    def get(self, month: str) -> Optional[Budget]:
        for record in storage.iter_jsonl(self._path):
            if str(record["month"]) == month:
                return Budget.from_dict(record)
        return None

    def set(self, budget: Budget) -> None:
        found = False
        records: list[dict[str, object]] = []
        for current in storage.iter_jsonl(self._path):
            if str(current["month"]) == budget.month:
                records.append(budget.to_dict())
                found = True
            else:
                records.append(Budget.from_dict(current).to_dict())
        if not found:
            records.append(budget.to_dict())
        storage.rewrite_jsonl_atomic(self._path, records)
