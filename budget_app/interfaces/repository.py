"""
저장소 인터페이스 (Repository Ports)
- 책임: 데이터 저장/조회/수정/삭제에 대한 계약을 정의한다.
- 구현체: JSONLTransactionRepository, JSONLCategoryRepository, JSONLBudgetRepository
- 교체 예시: SQLiteTransactionRepository, RedisTransactionRepository 등으로 교체 가능
"""

from abc import ABC, abstractmethod
from typing import Iterator, Optional

from budget_app.models.transaction import Transaction
from budget_app.models.budget import Budget


class ITransactionRepository(ABC):
    """거래 저장소 계약"""

    @abstractmethod
    def add(self, transaction: Transaction) -> None:
        """거래를 영구 저장소에 추가한다 (append-only)."""
        ...

    @abstractmethod
    def iter_latest(self) -> Iterator[Transaction]:
        """최신순(역순)으로 거래를 스트리밍 반환한다."""
        ...

    @abstractmethod
    def iter_all(self) -> Iterator[Transaction]:
        """과거순(정순)으로 거래를 스트리밍 반환한다."""
        ...

    @abstractmethod
    def get_by_id(self, transaction_id: str) -> Optional[Transaction]:
        """ID로 단일 거래를 조회한다. 없으면 None."""
        ...

    @abstractmethod
    def replace(self, transaction: Transaction) -> bool:
        """해당 ID의 거래를 치환한다. 성공 여부를 반환한다."""
        ...

    @abstractmethod
    def delete(self, transaction_id: str) -> bool:
        """해당 ID의 거래를 삭제한다. 성공 여부를 반환한다."""
        ...


class ICategoryRepository(ABC):
    """카테고리 저장소 계약"""

    @abstractmethod
    def list_all(self) -> list[str]:
        """모든 카테고리 이름을 정렬하여 반환한다."""
        ...

    @abstractmethod
    def exists(self, name: str) -> bool:
        """해당 이름의 카테고리가 존재하는지 확인한다."""
        ...

    @abstractmethod
    def add(self, name: str) -> None:
        """새 카테고리를 추가한다."""
        ...

    @abstractmethod
    def remove(self, name: str) -> bool:
        """해당 이름의 카테고리를 삭제한다. 성공 여부를 반환한다."""
        ...


class IBudgetRepository(ABC):
    """예산 저장소 계약"""

    @abstractmethod
    def get(self, month: str) -> Optional[Budget]:
        """해당 월의 예산을 조회한다. 없으면 None."""
        ...

    @abstractmethod
    def set(self, budget: Budget) -> None:
        """예산을 저장(추가 또는 덮어쓰기)한다."""
        ...
