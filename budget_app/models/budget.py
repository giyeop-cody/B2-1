"""
예산 데이터 모델
- 책임: 월별 예산 레코드 구조와 직렬화를 표현한다.
- 입력: 월 문자열과 금액
- 반환: Budget 인스턴스
"""

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class Budget:
    month: str
    amount: int

    def to_dict(self) -> dict[str, Any]:
        return {"month": self.month, "amount": self.amount}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Budget":
        return cls(
            month=str(data["month"]),
            amount=int(data["amount"]),
        )
