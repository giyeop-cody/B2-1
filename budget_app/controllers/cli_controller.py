"""
CLI 컨트롤러
- 책임: argparse 입력 파싱 → UseCase 호출 → Presenter/View 결과 전달.
- 의존: interfaces (계약), usecases, views, presenters
- 교체: WebController, GUIController 등으로 교체 시 이 파일만 변경한다.
"""

from __future__ import annotations

import argparse
import shutil
from typing import Sequence

from budget_app.interfaces.presenter import IPresenter
from budget_app.interfaces.view import IView
from budget_app.interfaces.repository import (
    ITransactionRepository,
    ICategoryRepository,
    IBudgetRepository,
)
from budget_app.usecases.transaction_usecase import TransactionUseCase
from budget_app.usecases.category_usecase import CategoryUseCase
from budget_app.usecases.budget_usecase import BudgetUseCase
from budget_app.usecases.import_export_usecase import ImportExportUseCase
from budget_app.models.search_filters import SearchFilters
from budget_app.exceptions import ValidationError
from budget_app.infrastructure.jsonl_storage import ensure_data_paths, DataPaths
from budget_app.repositories import (
    JSONLTransactionRepository,
    JSONLCategoryRepository,
    JSONLBudgetRepository,
)
from budget_app.views import ConsoleView
from budget_app.presenters import ConsolePresenter


def build_controller(data_dir: str) -> "CLIController":
    """의존성을 주입하여 CLIController를 생성한다 (DI Container 역할)."""
    paths = ensure_data_paths(data_dir)

    # Repository (인터페이스 기반, 교체 가능)
    tx_repo: ITransactionRepository = JSONLTransactionRepository(paths.transactions)
    cat_repo: ICategoryRepository = JSONLCategoryRepository(paths.categories)
    budget_repo: IBudgetRepository = JSONLBudgetRepository(paths.budgets)

    # UseCase (비즈니스 로직, Repository 인터페이스만 알고 구현체는 모른다)
    tx_uc = TransactionUseCase(transaction_repo=tx_repo, category_repo=cat_repo)
    cat_uc = CategoryUseCase(category_repo=cat_repo, transaction_repo=tx_repo)
    budget_uc = BudgetUseCase(budget_repo=budget_repo, transaction_repo=tx_repo)
    import_uc = ImportExportUseCase(
        transaction_repo=tx_repo,
        category_repo=cat_repo,
        transaction_usecase=tx_uc,
    )

    # View & Presenter (UI, 교체 가능)
    view: IView = ConsoleView()
    presenter: IPresenter = ConsolePresenter()

    controller = CLIController(
        view=view,
        presenter=presenter,
        tx_uc=tx_uc,
        cat_uc=cat_uc,
        budget_uc=budget_uc,
        import_uc=import_uc,
        data_paths=paths,
    )

    # 초기 실행: 카테고리가 비어있으면 안내 메시지 출력 (미션 요구사항)
    if not cat_uc.list_all():
        presenter.show_message(
            "[안내] 카테고리가 비어 있습니다. 'category add --name <이름>'으로 먼저 카테고리를 추가하세요."
        )

    return controller


class CLIController:
    """argparse 기반 CLI 입력 → UseCase 호출 → 결과 출력"""

    def __init__(
        self,
        view: IView,
        presenter: IPresenter,
        tx_uc: TransactionUseCase,
        cat_uc: CategoryUseCase,
        budget_uc: BudgetUseCase,
        import_uc: ImportExportUseCase,
        data_paths: DataPaths,
    ) -> None:
        self._view = view
        self._presenter = presenter
        self._tx_uc = tx_uc
        self._cat_uc = cat_uc
        self._budget_uc = budget_uc
        self._import_uc = import_uc
        self._paths = data_paths

    def dispatch(self, args: argparse.Namespace) -> int:
        """파싱된 인자를 보고 적절한 핸들러로 분기한다."""
        if args.command == "add":
            return self._handle_add()
        if args.command == "list":
            return self._handle_list(args)
        if args.command == "search":
            return self._handle_search(args)
        if args.command == "summary":
            return self._handle_summary(args)
        if args.command == "budget" and args.budget_command == "set":
            return self._handle_budget_set(args)
        if args.command == "category" and args.category_command == "add":
            return self._handle_category_add(args)
        if args.command == "category" and args.category_command == "list":
            return self._handle_category_list()
        if args.command == "category" and args.category_command == "remove":
            return self._handle_category_remove(args)
        if args.command == "update":
            return self._handle_update(args)
        if args.command == "delete":
            return self._handle_delete(args)
        if args.command == "import":
            return self._handle_import(args)
        if args.command == "export":
            return self._handle_export(args)
        raise ValidationError("지원하지 않는 명령입니다.", "--help로 지원 명령을 확인하세요.")

    def _handle_add(self) -> int:
        data = self._view.prompt_transaction_input(self._cat_uc.list_all())
        tx = self._tx_uc.add(
            date=data["date"],
            transaction_type=data["transaction_type"],
            category=data["category"],
            amount=data["amount"],
            memo=data["memo"],
            tags=data["tags"],
        )
        self._presenter.show_message(f"저장 완료: id={tx.id}")
        return 0

    def _handle_list(self, args: argparse.Namespace) -> int:
        if args.limit is not None and args.limit <= 0:
            raise ValidationError("--limit 값이 올바르지 않습니다.", "1 이상의 정수를 입력하세요.")
        for tx in self._tx_uc.list_latest(limit=args.limit):
            self._presenter.show_transaction(tx)
        return 0

    def _handle_search(self, args: argparse.Namespace) -> int:
        filters = SearchFilters(
            from_date=args.from_date,
            to_date=args.to_date,
            category=args.category,
            type=args.transaction_type,
            query=args.query,
            tag=args.tag,
        )
        for tx in self._tx_uc.search(filters):
            self._presenter.show_transaction(tx)
        return 0

    def _handle_summary(self, args: argparse.Namespace) -> int:
        if args.top <= 0:
            raise ValidationError("--top 값이 올바르지 않습니다.", "1 이상의 정수를 입력하세요.")
        summary = self._budget_uc.summarize(month=args.month, top=args.top)
        self._presenter.show_summary(summary)
        return 0

    def _handle_budget_set(self, args: argparse.Namespace) -> int:
        budget = self._budget_uc.set(month=args.month, amount=args.amount)
        self._presenter.show_message(f"예산 저장 완료: {budget.month} {budget.amount}")
        return 0

    def _handle_category_add(self, args: argparse.Namespace) -> int:
        self._cat_uc.add(args.name)
        self._presenter.show_message(f"카테고리 추가 완료: {args.name}")
        return 0

    def _handle_category_list(self) -> int:
        cats = self._cat_uc.list_all()
        self._presenter.show_category_list(cats)
        return 0

    def _handle_category_remove(self, args: argparse.Namespace) -> int:
        target = self._cat_uc.remove(args.name, args.replacement)
        if args.replacement:
            self._presenter.show_message(f"카테고리 삭제 완료: {args.name} -> {target}")
        else:
            self._presenter.show_message(f"카테고리 삭제 완료: {args.name}")
        return 0

    def _handle_update(self, args: argparse.Namespace) -> int:
        if all(
            v is None
            for v in (
                args.date,
                args.transaction_type,
                args.category,
                args.amount,
                args.memo,
                args.tags,
            )
        ):
            raise ValidationError(
                "수정할 항목이 없습니다.",
                "update 명령에 최소 한 개 이상의 수정 옵션을 전달하세요.",
            )
        tx = self._tx_uc.update(
            args.id,
            date=args.date,
            transaction_type=args.transaction_type,
            category=args.category,
            amount=args.amount,
            memo=args.memo,
            tags=[t.strip() for t in args.tags.split(",")] if args.tags else None,
        )
        self._presenter.show_message(f"거래 수정 완료: id={tx.id}")
        return 0

    def _handle_delete(self, args: argparse.Namespace) -> int:
        self._tx_uc.delete(args.id)
        self._presenter.show_message(f"거래 삭제 완료: id={args.id}")
        return 0

    def _handle_import(self, args: argparse.Namespace) -> int:
        # import 전 백업 생성 (롤백용)
        backup_path = self._paths.transactions.with_suffix(".jsonl.import_bak")
        if self._paths.transactions.exists():
            shutil.copy(self._paths.transactions, backup_path)

        try:
            result = self._import_uc.import_csv(args.from_path)
        except Exception:
            if backup_path.exists():
                backup_path.unlink(missing_ok=True)
            raise

        # 100% 실패 시 롤백
        if result.rolled_back and backup_path.exists():
            shutil.copy(backup_path, self._paths.transactions)

        if backup_path.exists():
            backup_path.unlink(missing_ok=True)

        self._presenter.show_import_result(result)
        return 0

    def _handle_export(self, args: argparse.Namespace) -> int:
        exported = self._import_uc.export_csv(
            args.out,
            month=args.month,
            from_date=args.from_date,
            to_date=args.to_date,
        )
        self._presenter.show_message(f"CSV내보기 완료: {exported}건")
        return 0


def create_parser() -> argparse.ArgumentParser:
    """argparse 인스턴스를 생성한다."""
    parser = argparse.ArgumentParser(
        prog="python -m budget_app",
        description="파일 기반 가계부 CLI",
    )
    parser.add_argument("--data-dir", default="./data", help="데이터 저장 디렉터리 경로")
    parser.add_argument(
        "--show-timing",
        action="store_true",
        help="명령 실행 시간을 함께 출력합니다.",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("add", help="거래를 대화형으로 추가합니다.")

    list_parser = subparsers.add_parser("list", help="최신순 거래 목록을 조회합니다.")
    list_parser.add_argument(
        "--limit", type=int, default=None, help="출력할 최대 거래 수 (양의 정수)"
    )

    search_parser = subparsers.add_parser("search", help="거래를 검색합니다.")
    search_parser.add_argument("--from", dest="from_date", help="시작 날짜 (YYYY-MM-DD)")
    search_parser.add_argument("--to", dest="to_date", help="종료 날짜 (YYYY-MM-DD)")
    search_parser.add_argument("--category", help="카테고리")
    search_parser.add_argument(
        "--type", dest="transaction_type", help="income 또는 expense"
    )
    search_parser.add_argument("--q", dest="query", help="메모/카테고리/태그 검색어")
    search_parser.add_argument("--tag", help="태그")

    summary_parser = subparsers.add_parser("summary", help="월별 요약을 출력합니다.")
    summary_parser.add_argument("--month", required=True, help="대상 월 (YYYY-MM)")
    summary_parser.add_argument(
        "--top", type=int, default=3, help="상위 지출 카테고리 개수 (양의 정수)"
    )

    budget_parser = subparsers.add_parser("budget", help="예산을 관리합니다.")
    budget_subparsers = budget_parser.add_subparsers(
        dest="budget_command", required=True
    )
    budget_set_parser = budget_subparsers.add_parser("set", help="월별 예산을 설정합니다.")
    budget_set_parser.add_argument("--month", required=True, help="대상 월 (YYYY-MM)")
    budget_set_parser.add_argument(
        "--amount", type=int, required=True, help="예산 금액"
    )

    category_parser = subparsers.add_parser("category", help="카테고리를 관리합니다.")
    category_subparsers = category_parser.add_subparsers(
        dest="category_command", required=True
    )
    category_add_parser = category_subparsers.add_parser("add", help="카테고리를 추가합니다.")
    category_add_parser.add_argument("--name", required=True, help="카테고리 이름")
    category_subparsers.add_parser("list", help="카테고리 목록을 출력합니다.")
    category_remove_parser = category_subparsers.add_parser(
        "remove", help="카테고리를 삭제합니다."
    )
    category_remove_parser.add_argument(
        "--name", required=True, help="삭제할 카테고리 이름"
    )
    category_remove_parser.add_argument(
        "--replacement", help="대체할 카테고리 이름"
    )

    update_parser = subparsers.add_parser("update", help="거래를 수정합니다.")
    update_parser.add_argument("--id", required=True, help="수정할 거래 id")
    update_parser.add_argument("--date", help="날짜 (YYYY-MM-DD)")
    update_parser.add_argument(
        "--type", dest="transaction_type", help="income 또는 expense"
    )
    update_parser.add_argument("--category", help="카테고리")
    update_parser.add_argument("--amount", type=int, help="금액")
    update_parser.add_argument("--memo", help="메모")
    update_parser.add_argument("--tags", help="쉼표로 구분한 태그 목록")

    delete_parser = subparsers.add_parser("delete", help="거래를 삭제합니다.")
    delete_parser.add_argument("--id", required=True, help="삭제할 거래 id")

    import_parser = subparsers.add_parser(
        "import", help="CSV 파일에서 거래를 가져옵니다."
    )
    import_parser.add_argument(
        "--from", dest="from_path", required=True, help="가져올 CSV 파일 경로"
    )

    export_parser = subparsers.add_parser(
        "export", help="CSV 파일로 거래를보냅니다."
    )
    export_parser.add_argument("--out", required=True, help="저장할 CSV 파일 경로")
    export_parser.add_argument("--month", help="대상 월 (YYYY-MM)")
    export_parser.add_argument("--from", dest="from_date", help="시작 날짜 (YYYY-MM-DD)")
    export_parser.add_argument("--to", dest="to_date", help="종료 날짜 (YYYY-MM-DD)")

    return parser
