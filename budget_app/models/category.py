"""
카테고리 데이터 모델
- 책임: 카테고리 이름의 구조와 직렬화를 표현한다.
"""

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class Category:
    name: str

    def to_dict(self) -> dict[str, Any]:
        return {"name": self.name}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Category":
        return cls(name=str(data["name"]))
