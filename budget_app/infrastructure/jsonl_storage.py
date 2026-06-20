"""
JSONL 파일 IO 유틸리티
- 책임: JSONL 파일의 생성, 스트리밍 읽기, 원자적 재작성을 제공한다.
- 범위: 표준 라이브러리만 사용하는 저수준 파일 처리.
- 제약: list/search는 전체 로드 없이 스트리밍을 지원해야 한다.
"""

from __future__ import annotations

import json
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator


@dataclass(slots=True)
class DataPaths:
    """데이터 디렉터리 내 파일 경로를 관리한다."""
    root: Path

    @property
    def transactions(self) -> Path:
        return self.root / "transactions.jsonl"

    @property
    def categories(self) -> Path:
        return self.root / "categories.jsonl"

    @property
    def budgets(self) -> Path:
        return self.root / "budgets.jsonl"


def ensure_data_paths(data_dir: str) -> DataPaths:
    """데이터 디렉터리와 필수 파일을 생성한다."""
    root = Path(data_dir)
    root.mkdir(parents=True, exist_ok=True)
    paths = DataPaths(root=root)
    for path in (paths.transactions, paths.categories, paths.budgets):
        path.touch(exist_ok=True)
    return paths


def iter_jsonl(path: Path) -> Iterator[dict[str, object]]:
    """JSONL 파일을 앞에서부터 한 줄씩 스트리밍 읽는다."""
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            yield json.loads(stripped)


def iter_jsonl_reverse(path: Path) -> Iterator[dict[str, object]]:
    """JSONL 파일을 뒤에서부터 한 줄씩 스트리밍 읽는다.
    - 최신 레코드가 파일 끝에 있으므로 list/search 최신순에 사용한다.
    - 4096바이트 단위로 청크를 읽어 메모리를 절약한다.
    """
    with path.open("rb") as handle:
        handle.seek(0, os.SEEK_END)
        position = handle.tell()
        buffer = b""
        while position > 0:
            read_size = min(4096, position)
            position -= read_size
            handle.seek(position)
            chunk = handle.read(read_size)
            parts = chunk.split(b"\n")
            if buffer:
                parts[-1] += buffer
            buffer = parts[0]
            for part in reversed(parts[1:]):
                stripped = part.strip()
                if stripped:
                    yield json.loads(stripped.decode("utf-8"))
        stripped = buffer.strip()
        if stripped:
            yield json.loads(buffer.decode("utf-8"))


def append_jsonl(path: Path, record: dict[str, object]) -> None:
    """단일 레코드를 JSONL 파일 끝에 append한다."""
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def rewrite_jsonl_atomic(path: Path, records: Iterable[dict[str, object]]) -> None:
    """전체 레코드로 JSONL 파일을 원자적(atomic)하게 재작성한다.
    - 임시 파일에 먼저 쓰고 os.replace로 교체하여 쓰기 중 손상을 방지한다.
    """
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=path.parent,
        delete=False,
        suffix=".tmp",
    ) as temp_handle:
        for record in records:
            temp_handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        temp_name = temp_handle.name
    os.replace(temp_name, path)
