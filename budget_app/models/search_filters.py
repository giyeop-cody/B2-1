"""
검색 조건 데이터 모델
- 책임: search 명령의 다양한 조건을 한 객체로 구조화한다.
- 입력: 날짜 범위, 카테고리, 타입, 검색어, 태그
- 반환: SearchFilters 인스턴스
"""

from dataclasses import dataclass


@dataclass(slots=True)
class SearchFilters:
    from_date: str | None = None
    to_date: str | None = None
    category: str | None = None
    type: str | None = None
    query: str | None = None
    tag: str | None = None
