"""
저장소 구현 계층 (Repository Adapters)
- 인터페이스 계층의 계약을 구현한다.
- Infrastructure 계층의 JSONL 유틸리티를 사용한다.
- 교체 가능성: JSONL → SQLite, CSV, Redis 등으로 교체 시 이 폴더만 변경한다.
"""

from budget_app.repositories.jsonl_transaction_repo import JSONLTransactionRepository
from budget_app.repositories.jsonl_category_repo import JSONLCategoryRepository
from budget_app.repositories.jsonl_budget_repo import JSONLBudgetRepository

__all__ = [
    "JSONLTransactionRepository",
    "JSONLCategoryRepository",
    "JSONLBudgetRepository",
]
