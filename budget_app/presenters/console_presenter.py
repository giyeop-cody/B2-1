"""
콘솔 출력 구현 (Console Presenter)
- 책임: IPresenter 계약을 구현하여 텍스트 기반 출력을 제공한다.
- 의존: interfaces.presenter, models.transaction, models.import_result
- 교체: IPresenter를 구현하는 다른 클래스로 교체 시 전체 출력 형식이 변경된다.
"""

from typing import Any

from budget_app.interfaces.presenter import IPresenter
from budget_app.models.transaction import Transaction
from budget_app.models.import_result import ImportResult


class ConsolePresenter(IPresenter):
    def show_transaction(self, transaction: Transaction) -> None:
        print(
            f"[{transaction.id}] {transaction.date} | {transaction.type} | "
            f"{transaction.category} | {transaction.amount} | "
            f"memo={transaction.memo or '-'} | "
            f"tags={','.join(transaction.tags) if transaction.tags else '-'}"
        )

    def show_message(self, message: str) -> None:
        print(message)

    def show_error(self, message: str, hint: str) -> None:
        print(f"오류: {message}")
        print(f"해결 힌트: {hint}")

    def show_summary(self, summary: dict[str, Any]) -> None:
        if summary.get("empty"):
            print("데이터 없음")
            return
        print(f"월: {summary['month']}")
        print(f"총 수입: {summary['income_total']}")
        print(f"총 지출: {summary['expense_total']}")
        print(f"잔액: {summary['balance']}")
        print("카테고리별 TOP 지출:")
        for category, amount in summary["top_expenses"]:
            print(f"- {category}: {amount}")
        if summary.get("budget") is not None:
            print(f"예산: {summary['budget']}")
            print(f"사용률: {summary['usage']}%")
            if summary.get("over_budget"):
                print("경고: 예산을 초과했습니다.")

    def show_import_result(self, result: ImportResult) -> None:
        if result.rolled_back:
            print(f"CSV 가져오기 실패: 모든 {result.total}행이 실패하여 롤백되었습니다.")
            for f in result.failures:
                print(f"  - 행 {f['row']}: {f['reason']}")
        elif result.failed > 0:
            print(f"CSV 부분 가져오기 완료: 성공 {result.imported}건, 실패 {result.failed}건 (총 {result.total}건)")
            print("실패 내역:")
            for f in result.failures:
                print(f"  - 행 {f['row']}: {f['reason']}")
        else:
            print(f"CSV 가져오기 완료: {result.imported}건")

    def show_category_list(self, categories: list[str]) -> None:
        for category in categories:
            print(category)

    def show_timing(self, elapsed: float) -> None:
        print(f"실행 시간: {elapsed:.6f}초")
