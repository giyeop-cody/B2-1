"""
카테고리 저장소 구현 (JSONL)
- 책임: 카테고리 목록의 파일 기반 CRUD를 담당한다.
- 의존: interfaces.repository (계약), infrastructure.jsonl_storage
- 교체: ICategoryRepository를 구현하는 SQLite, 메모리 캐시 등으로 교체 가능
"""

from pathlib import Path

from budget_app.interfaces.repository import ICategoryRepository
from budget_app.infrastructure import jsonl_storage as storage


class JSONLCategoryRepository(ICategoryRepository):
    def __init__(self, path: Path) -> None:
        self._path = path

    def list_all(self) -> list[str]:
        categories = [str(record["name"]) for record in storage.iter_jsonl(self._path)]
        categories.sort()
        return categories

    def exists(self, name: str) -> bool:
        return any(category == name for category in self.list_all())

    def add(self, name: str) -> None:
        storage.append_jsonl(self._path, {"name": name})

    def remove(self, name: str) -> bool:
        found = False
        records: list[dict[str, object]] = []
        for record in storage.iter_jsonl(self._path):
            if str(record["name"]) == name:
                found = True
                continue
            records.append({"name": str(record["name"])})
        if found:
            storage.rewrite_jsonl_atomic(self._path, records)
        return found
