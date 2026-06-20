"""
예외 계층 (Domain / Application 공통)
- 모든 계층에서 사용하는 사용자 친화적 예외 타입
"""

from dataclasses import dataclass


@dataclass(slots=True)
class AppError(Exception):
    """앱 전체의 기본 예외. 스택트레이스 대신 메시지와 힌트를 제공."""
    message: str
    hint: str

    def __str__(self) -> str:
        return self.message


class ValidationError(AppError):
    """입력 검증 실패"""
    pass


class NotFoundError(AppError):
    """리소스 미존재"""
    pass
