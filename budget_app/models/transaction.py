"""
거래 데이터 모델
- 책임: 단일 거래 레코드의 구조와 직렬화를 표현한다.
- 입력: 거래 식별자와 날짜, 타입, 카테고리, 금액, 메모, 태그
- 반환: Transaction 인스턴스
- 예외/실패: 입력 검증은 Application 계층(UseCase)에서 처리한다.
"""

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class Transaction:
    id: str
    date: str
    type: str
    category: str
    amount: int
    memo: str = ""
    tags: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "date": self.date,
            "type": self.type,
            "category": self.category,
            "amount": self.amount,
            "memo": self.memo,
            "tags": self.tags,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Transaction":
        return cls(
            id=str(data["id"]),
            date=str(data["date"]),
            type=str(data["type"]),
            category=str(data["category"]),
            amount=int(data["amount"]),
            memo=str(data.get("memo", "")),
            tags=[str(tag) for tag in data.get("tags", [])],
        )
