"""
CSV Import 결과 데이터 모델
- 책임: CSV 가져오기의 성공/실패/롤백 상태를 집계한다.
- 입력: 성공/실패 건수와 실패 내역
- 반환: ImportResult 인스턴스
"""

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class ImportResult:
    imported: int
    failed: int
    total: int
    failures: list[dict[str, Any]]
    rolled_back: bool
