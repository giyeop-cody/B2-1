"""
에러 핸들링 데코레이터
- 책임: 앱 예외와 예상 밖 예외를 사용자 친화적 출력으로 변환한다.
- 스택트레이스를 숨기고, 원인 + 해결 힌트만 출력한다.
- 종료 코드: 정상 0, 오류 1
"""

from __future__ import annotations

import functools
from collections.abc import Callable
from typing import ParamSpec, TypeVar

from budget_app.exceptions import AppError

P = ParamSpec("P")
R = TypeVar("R")


def handle_app_errors(func: Callable[P, R]) -> Callable[P, int | R]:
    """앱 예외를 사용자 친화적인 출력으로 변환하고 종료 코드를 반환한다."""

    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> int | R:
        try:
            return func(*args, **kwargs)
        except AppError as error:
            print(f"오류: {error.message}")
            print(f"해결 힌트: {error.hint}")
            return 1
        except KeyboardInterrupt:
            print("오류: 사용자가 작업을 중단했습니다.")
            print("해결 힌트: 필요한 경우 명령을 다시 실행하세요.")
            return 1
        except Exception as error:
            print(f"오류: 예상하지 못한 문제가 발생했습니다. ({type(error).__name__})")
            print("해결 힌트: 입력값과 데이터 파일 형식을 확인한 뒤 다시 시도하세요.")
            return 1

    return wrapper
