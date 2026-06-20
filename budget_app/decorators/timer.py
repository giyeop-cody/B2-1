"""
실행 시간 측정 데코레이터
- 책임: 함수 실행 시간을 측정하고 선택적으로 출력한다.
- --show-timing 옵션이 True일 때만 출력한다.
"""

from __future__ import annotations

import functools
import time
from collections.abc import Callable
from typing import ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")


def timed(func: Callable[P, R]) -> Callable[P, R]:
    """함수 실행 시간을 측정하고 show_timing=True일 때 출력한다."""

    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        started = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - started
        if kwargs.get("show_timing"):
            print(f"실행 시간: {elapsed:.6f}초")
        return result

    return wrapper
