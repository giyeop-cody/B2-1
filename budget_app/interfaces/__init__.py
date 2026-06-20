"""
인터페이스 계층 (Interface / Port Layer)
- 모든 구현체(Repository, Presenter, View)가 지켜야 할 계약(Contract)
- 이 계층을 교체하면 전체 시스템이 정상 동작하도록 보장한다 (Affinity)
"""

from budget_app.interfaces.repository import ITransactionRepository, ICategoryRepository, IBudgetRepository
from budget_app.interfaces.presenter import IPresenter
from budget_app.interfaces.view import IView

__all__ = [
    "ITransactionRepository",
    "ICategoryRepository",
    "IBudgetRepository",
    "IPresenter",
    "IView",
]
