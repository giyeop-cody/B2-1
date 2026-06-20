"""
카테고리 유즈케이스 (Category UseCase)
- 책임: 카테고리 추가/목록/삭제의 비즈니스 로직과 검증을 담당한다.
- 삭제 시 사용 중인 카테고리는 대체하거나 막는다.
"""

from budget_app.interfaces.repository import ICategoryRepository, ITransactionRepository
from budget_app.exceptions import ValidationError, NotFoundError


class CategoryUseCase:
    def __init__(
        self,
        category_repo: ICategoryRepository,
        transaction_repo: ITransactionRepository,
    ) -> None:
        self._cat_repo = category_repo
        self._tx_repo = transaction_repo

    def add(self, name: str) -> None:
        cleaned = name.strip()
        if not cleaned:
            raise ValidationError(
                "카테고리 이름이 비어 있습니다.",
                "category add --name <이름> 형식으로 입력하세요.",
            )
        if self._cat_repo.exists(cleaned):
            raise ValidationError(
                "이미 존재하는 카테고리입니다.",
                "category list 명령으로 현재 카테고리를 확인하세요.",
            )
        self._cat_repo.add(cleaned)

    def list_all(self) -> list[str]:
        return self._cat_repo.list_all()

    def remove(self, name: str, replacement: str | None = None) -> str:
        if not self._cat_repo.exists(name):
            raise NotFoundError(
                "삭제할 카테고리를 찾을 수 없습니다.",
                "category list 명령으로 카테고리 이름을 다시 확인하세요.",
            )
        if replacement and not self._cat_repo.exists(replacement):
            raise ValidationError(
                "대체 카테고리가 존재하지 않습니다.",
                "먼저 대체 카테고리를 추가한 뒤 다시 시도하세요.",
            )
        from budget_app.models.transaction import Transaction
        affected = [tx for tx in self._tx_repo.iter_all() if tx.category == name]
        if affected and not replacement:
            raise ValidationError(
                "사용 중인 카테고리는 바로 삭제할 수 없습니다.",
                "replacement 옵션으로 대체 카테고리를 지정하거나 관련 거래를 먼저 수정하세요.",
            )
        if affected and replacement:
            for transaction in affected:
                transaction.category = replacement
                self._tx_repo.replace(transaction)
        self._cat_repo.remove(name)
        return replacement or name
