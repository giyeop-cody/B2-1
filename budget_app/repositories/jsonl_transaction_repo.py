"""
거래 저장소 구현 (JSONL)
- 책임: 거래 데이터의 파일 기반 CRUD를 담당한다.
- 의존: interfaces.repository (계약), models.transaction, infrastructure.jsonl_storage
- 교체: ITransactionRepository를 구현하는 SQLite, Redis 등으로 교체 가능
"""

from pathlib import Path
from typing import Iterator, Optional

from budget_app.interfaces.repository import ITransactionRepository
from budget_app.models.transaction import Transaction
from budget_app.infrastructure import jsonl_storage as storage


class JSONLTransactionRepository(ITransactionRepository):
    def __init__(self, path: Path) -> None:
        self._path = path

    def add(self, transaction: Transaction) -> None:
        storage.append_jsonl(self._path, transaction.to_dict())

    def iter_latest(self) -> Iterator[Transaction]:
        for record in storage.iter_jsonl_reverse(self._path):
            yield Transaction.from_dict(record)

    def iter_all(self) -> Iterator[Transaction]:
        for record in storage.iter_jsonl(self._path):
            yield Transaction.from_dict(record)

    def get_by_id(self, transaction_id: str) -> Optional[Transaction]:
        for transaction in self.iter_all():
            if transaction.id == transaction_id:
                return transaction
        return None

    def replace(self, transaction: Transaction) -> bool:
        found = False
        records: list[dict[str, object]] = []
        for current in self.iter_all():
            if current.id == transaction.id:
                records.append(transaction.to_dict())
                found = True
            else:
                records.append(current.to_dict())
        if found:
            storage.rewrite_jsonl_atomic(self._path, records)
        return found

    def delete(self, transaction_id: str) -> bool:
        found = False
        records: list[dict[str, object]] = []
        for current in self.iter_all():
            if current.id == transaction_id:
                found = True
                continue
            records.append(current.to_dict())
        if found:
            storage.rewrite_jsonl_atomic(self._path, records)
        return found
