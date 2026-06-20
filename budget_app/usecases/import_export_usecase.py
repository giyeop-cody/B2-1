"""
Import/Export 유즈케이스
- 책임: CSV 파일의 가져오기/보내기 비즈니스 로직을 담당한다.
- import 시 행 단위 try-except로 부분 성공을 지원하고, 실패 내역을 리포트한다.
- 실제 롤백은 Controller 계층에서 ImportResult를 보고 수행한다 (Clean Architecture).
"""

import csv
from pathlib import Path
from typing import Any

from budget_app.interfaces.repository import ITransactionRepository, ICategoryRepository
from budget_app.models.import_result import ImportResult
from budget_app.models.search_filters import SearchFilters
from budget_app.exceptions import ValidationError, NotFoundError
from budget_app.usecases.transaction_usecase import TransactionUseCase


class ImportExportUseCase:
    def __init__(
        self,
        transaction_repo: ITransactionRepository,
        category_repo: ICategoryRepository,
        transaction_usecase: TransactionUseCase,
    ) -> None:
        self._tx_repo = transaction_repo
        self._cat_repo = category_repo
        self._tx_uc = transaction_usecase

    def import_csv(self, csv_path: str) -> ImportResult:
        """CSV를 읽어 거래를 일괄 등록한다. 행 단위 오류는 격리하고 결과를 집계한다."""
        path = Path(csv_path)
        if not path.exists():
            raise NotFoundError("가져올 CSV 파일을 찾을 수 없습니다.", "파일 경로를 다시 확인하세요.")

        imported = 0
        failures: list[dict[str, Any]] = []
        row_num = 1
        expected_fields = ["date", "type", "category", "amount", "memo", "tags"]

        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames != expected_fields:
                raise ValidationError(
                    "CSV 스키마가 올바르지 않습니다.",
                    "헤더를 date,type,category,amount,memo,tags 순서로 맞추세요.",
                )
            for row in reader:
                row_num += 1
                try:
                    tags = [tag.strip() for tag in str(row["tags"]).split(",") if tag.strip()]
                    self._tx_uc.add(
                        date=str(row["date"]),
                        transaction_type=str(row["type"]),
                        category=str(row["category"]),
                        amount=int(row["amount"]),
                        memo=str(row["memo"]),
                        tags=tags,
                    )
                    imported += 1
                except Exception as error:
                    failures.append({
                        "row": row_num,
                        "reason": f"{type(error).__name__}: {error}",
                        "data": dict(row),
                    })

        total = imported + len(failures)
        # UseCase는 순수 로직만: 100% 실패 여부만 표시, 실제 파일 롤백은 Controller에서 수행
        all_failed = total > 0 and len(failures) == total
        return ImportResult(
            imported=imported,
            failed=len(failures),
            total=total,
            failures=failures,
            rolled_back=all_failed,
        )

    def export_csv(
        self,
        csv_path: str,
        *,
        month: str | None = None,
        from_date: str | None = None,
        to_date: str | None = None,
    ) -> int:
        """조건에 맞는 거래를 CSV로보낸다."""
        if month is None and (from_date is None or to_date is None):
            raise ValidationError(
                "export에는 --month 또는 --from/--to가 필요합니다.",
                "예: export --month 2026-05 또는 export --from 2026-05-01 --to 2026-05-31",
            )
        if month is not None:
            normalized_month = self._tx_uc._validate_month(month)  # type: ignore
            from_date = f"{normalized_month}-01"
            to_date = f"{normalized_month}-31"
        else:
            self._tx_uc._validate_optional_dates(from_date, to_date)  # type: ignore

        exported = 0
        with Path(csv_path).open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=["date", "type", "category", "amount", "memo", "tags"],
            )
            writer.writeheader()
            for transaction in self._tx_uc.search(
                SearchFilters(from_date=from_date, to_date=to_date)
            ):
                writer.writerow({
                    "date": transaction.date,
                    "type": transaction.type,
                    "category": transaction.category,
                    "amount": transaction.amount,
                    "memo": transaction.memo,
                    "tags": ",".join(transaction.tags),
                })
                exported += 1
        return exported
