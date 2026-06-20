"""
Budget App 패키지

계층 구조:
  [ UI Layer ]          views/          - ConsoleView, GUIView, WebView 등
  [ Controller Layer ]  controllers/    - CLIController, WebController 등
  [ UseCase Layer ]     usecases/       - 비즈니스 로직, 검증, 집계
  [ Interface Layer ]   interfaces/     - Repository, Presenter, View 계약
  [ Repository Layer ]  repositories/    - JSONLTransactionRepository 등 (교체 가능)
  [ Infrastructure ]    infrastructure/ - JSONLStorage, FileUtils
  [ Domain Layer ]      models/          - Transaction, Budget, Category 등
  [ Exceptions ]        exceptions/      - AppError, ValidationError, NotFoundError
  [ Decorators ]        decorators/      - handle_app_errors, timed

Affinity (교체 가능성):
  - Repository: JSONL → SQLite, CSV, Redis (interfaces/repository.py 계약 준수)
  - Presenter: Console → JSON, Table, Web (interfaces/presenter.py 계약 준수)
  - View: Console → GUI, Web, TUI (interfaces/view.py 계약 준수)
  - Controller: CLI → Web, GUI (controller layer 전체 교체)
"""

__version__ = "1.0.0"
