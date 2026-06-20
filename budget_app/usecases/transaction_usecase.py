"""
거래 유즈케이스 (Transaction UseCase)
- 책임: 거래 추가/조회/검색/수정/삭제의 비즈니스 로직과 입력 검증을 담당한다.
- 의존: interfaces.repository (계약만)
- 반환: Domain 모델 또는 Iterator (Presenter에 의존하지 않음)
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Iterator, Optional

from budget_app.interfaces.repository import ITransactionRepository, ICategoryRepository
from budget_app.models.transaction import Transaction
from budget_app.models.search_filters import SearchFilters
from budget_app.exceptions import ValidationError, NotFoundError


class TransactionUseCase:
    def __init__(
        self,
        transaction_repo: ITransactionRepository,
        category_repo: ICategoryRepository,
    ) -> None:
        self._tx_repo = transaction_repo
        self._cat_repo = category_repo

    def add(
        self,
        date: str,
        transaction_type: str,
        category: str,
        amount: int,
        memo: str = "",
        tags: list[str] | None = None,
    ) -> Transaction:
        normalized_date = self._validate_date(date)
        normalized_type = self._validate_type(transaction_type)
        normalized_category = self._validate_category(category)
        normalized_amount = self._validate_amount(amount)
        transaction = Transaction(
            id=self._generate_id(),
            date=normalized_date,
            type=normalized_type,
            category=normalized_category,
            amount=normalized_amount,
            memo=memo.strip(),
            tags=[t.strip() for t in (tags or []) if t.strip()],
        )
        self._tx_repo.add(transaction)
        return transaction

    def list_latest(self, limit: int | None = None) -> Iterator[Transaction]:
        count = 0
        for transaction in self._tx_repo.iter_latest():
            yield transaction
            count += 1
            if limit is not None and count >= limit:
                break

    def search(self, filters: SearchFilters) -> Iterator[Transaction]:
        self._validate_optional_dates(filters.from_date, filters.to_date)
        if filters.type is not None:
            filters.type = self._validate_type(filters.type)
        if filters.category is not None and not self._cat_repo.exists(filters.category):
            raise ValidationError(
                "존재하지 않는 카테고리입니다.",
                "category list 명령으로 유효한 카테고리를 확인하세요.",
            )
        for transaction in self._tx_repo.iter_latest():
            if filters.from_date and transaction.date < filters.from_date:
                continue
            if filters.to_date and transaction.date > filters.to_date:
                continue
            if filters.category and transaction.category != filters.category:
                continue
            if filters.type and transaction.type != filters.type:
                continue
            if filters.tag and filters.tag not in transaction.tags:
                continue
            if filters.query:
                query = filters.query.lower()
                haystack = " ".join([transaction.memo, transaction.category, " ".join(transaction.tags)]).lower()
                if query not in haystack:
                    continue
            yield transaction

    def update(
        self,
        transaction_id: str,
        *,
        date: str | None = None,
        transaction_type: str | None = None,
        category: str | None = None,
        amount: int | None = None,
        memo: str | None = None,
        tags: list[str] | None = None,
    ) -> Transaction:
        current = self._tx_repo.get_by_id(transaction_id)
        if current is None:
            raise NotFoundError(
                "수정할 거래 id를 찾을 수 없습니다.",
                "list 또는 search 명령으로 올바른 id를 확인하세요.",
            )
        if date is not None:
            current.date = self._validate_date(date)
        if transaction_type is not None:
            current.type = self._validate_type(transaction_type)
        if category is not None:
            current.category = self._validate_category(category)
        if amount is not None:
            current.amount = self._validate_amount(amount)
        if memo is not None:
            current.memo = memo.strip()
        if tags is not None:
            current.tags = [t.strip() for t in tags if t.strip()]
        self._tx_repo.replace(current)
        return current

    def delete(self, transaction_id: str) -> None:
        if not self._tx_repo.delete(transaction_id):
            raise NotFoundError(
                "삭제할 거래 id를 찾을 수 없습니다.",
                "list 또는 search 명령으로 올바른 id를 확인하세요.",
            )

    def _generate_id(self) -> str:
        return uuid.uuid4().hex[:8]

    def _validate_date(self, value: str) -> str:
        try:
            return datetime.strptime(value, "%Y-%m-%d").strftime("%Y-%m-%d")
        except ValueError as error:
            raise ValidationError("날짜 형식이 올바르지 않습니다.", "YYYY-MM-DD 형식으로 입력하세요.") from error

    def _validate_month(self, value: str) -> str:
        try:
            return datetime.strptime(value, "%Y-%m").strftime("%Y-%m")
        except ValueError as error:
            raise ValidationError("월 형식이 올바르지 않습니다.", "YYYY-MM 형식으로 입력하세요.") from error

    def _validate_optional_dates(self, from_date: str | None, to_date: str | None) -> None:
        if from_date is not None:
            self._validate_date(from_date)
        if to_date is not None:
            self._validate_date(to_date)
        if from_date and to_date and from_date > to_date:
            raise ValidationError("날짜 범위가 올바르지 않습니다.", "--from 값은 --to 값보다 이전이거나 같아야 합니다.")

    def _validate_type(self, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"income", "expense"}:
            raise ValidationError("type 값이 올바르지 않습니다.", "income 또는 expense 중 하나를 사용하세요.")
        return normalized

    def _validate_category(self, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValidationError("카테고리 값이 비어 있습니다.", "유효한 카테고리 이름을 입력하세요.")
        if not self._cat_repo.exists(cleaned):
            raise ValidationError("존재하지 않는 카테고리입니다.", "먼저 category add 명령으로 카테고리를 추가하세요.")
        return cleaned

    def _validate_amount(self, value: int) -> int:
        amount = int(value)
        if amount <= 0:
            raise ValidationError("금액은 0보다 커야 합니다.", "양의 정수를 입력하세요.")
        return amount
