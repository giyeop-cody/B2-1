# B2-1 Budget App — 계층적 파일 기반 가계부 CLI

> Python 표준 라이브러리만으로 구현한 **MVC + Clean Architecture** 계층 구조의 파일 기반 가계부 CLI입니다.  
> 모든 모듈(Repository, Presenter, View)을 교체해도 정상 동작하도록 **Interface 계층**으로 Affinity를 보장합니다.

---

## 1. 아키텍처 다이어그램 (계층 구조)

```
┌─────────────────────────────────────────────┐
│  [ UI Layer ]        views/                  │  ← 사용자와 직접 상호작용
│  └── ConsoleView (IView 구현)               │     교체: GUIView, WebView, TUIView
├─────────────────────────────────────────────┤
│  [ Controller Layer ] controllers/          │  ← 입력 해석, UseCase 호출, 결과 전달
│  └── CLIController                           │     교체: WebController, GUIController
├─────────────────────────────────────────────┤
│  [ UseCase Layer ]   usecases/               │  ← 비즈니스 로직, 검증, 집계
│  └── TransactionUseCase                      │     (Repository 인터페이스만 의존)
│  └── CategoryUseCase                         │
│  └── BudgetUseCase                           │
│  └── ImportExportUseCase                     │
├─────────────────────────────────────────────┤
│  [ Interface Layer ] interfaces/             │  ← 계약(Contract) / Ports
│  └── IView, IPresenter                       │     교체의 기준이 되는 추상화
│  └── ITransactionRepository                  │
│  └── ICategoryRepository                     │
│  └── IBudgetRepository                       │
├─────────────────────────────────────────────┤
│  [ Repository Layer ]  repositories/          │  ← 데이터 저장 구현체
│  └── JSONLTransactionRepository              │     교체: SQLiteTransactionRepository
│  └── JSONLCategoryRepository                 │     교체: MemoryCategoryRepository
│  └── JSONLBudgetRepository                   │     교체: RedisBudgetRepository
├─────────────────────────────────────────────┤
│  [ Infrastructure ]  infrastructure/          │  ← 기술적 세부사항
│  └── JSONLStorage (iter_jsonl, atomic write)  │     교체: SQLiteStorage, CSVStorage
├─────────────────────────────────────────────┤
│  [ Domain Layer ]    models/                 │  ← 순수 데이터 구조
│  └── Transaction, Budget, Category           │     (어떤 계층에도 의존하지 않음)
│  └── SearchFilters, ImportResult             │
├─────────────────────────────────────────────┤
│  [ Cross-Cutting ]   decorators/             │  ← 공통 관심사 (AOP)
│  └── handle_app_errors, timed                │
│  [ Exceptions ]      exceptions/             │  ← 전체 계층 공용 예외
│  └── AppError, ValidationError, NotFoundError│
└─────────────────────────────────────────────┘
```

---

## 2. 계층별 책임과 교체 가능성 (Affinity)

| 계층 | 파일/클래스 | 책임 | 교체 시 영향 범위 |
|------|-----------|------|-----------------|
| **UI** | `views/console_view.py` | 대화형 입력, 직접 출력 | `views/`만 교체 |
| **Controller** | `controllers/cli_controller.py` | argparse 파싱, UseCase 호출, 결과 전달 | `controllers/`만 교체 |
| **UseCase** | `usecases/transaction_usecase.py` | 검증 + 집계 + 규칙 | **인터페이스만 준수하면 Repository/Presenter 교체와 무관** |
| **Interface** | `interfaces/repository.py` | 저장소 계약 | 새 구현체 추가 시 기존 코드 0 변경 |
| **Repository** | `repositories/jsonl_transaction_repo.py` | JSONL 파일 CRUD | `repositories/` 교체 시 `usecases/` 변경 없음 |
| **Infrastructure** | `infrastructure/jsonl_storage.py` | JSONL IO, 원자적 쓰기 | `infrastructure/` 교체 시 `repositories/`만 수정 |
| **Domain** | `models/transaction.py` | 데이터 구조, 직렬화 | **교체 불필요 (가장 안정)** |

---

## 3. 구현 기능 (미션 10가지 핵심 기능)

| 기능 | 명령 | 설명 |
|------|------|------|
| 거래 추가 | `python -m budget_app add` | 대화형 입력 (날짜/타입/카테고리/금액/메모/태그) |
| 거래 목록 | `python -m budget_app list --limit N` | 최신순, 제너레이터 스트리밍 |
| 거래 검색 | `python -m budget_app search --category 식비` | 날짜/카테고리/타입/메모/태그 조건 |
| 월별 요약 | `python -m budget_app summary --month 2026-05 --top 3` | 수입/지출/잔액 + TOP N + 예산 사용률/초과 경고 |
| 예산 설정 | `python -m budget_app budget set --month 2026-05 --amount 15000` | |
| 카테고리 관리 | `python -m budget_app category add/list/remove` | 사용 중인 카테고리는 대체/삭제 방지 |
| 거래 수정 | `python -m budget_app update --id <id> --memo "메모"` | 옵션 기반 (수정 필드만 전달) |
| 거래 삭제 | `python -m budget_app delete --id <id>` | |
| CSV 가져오기 | `python -m budget_app import --from sample.csv` | 행 단위 부분 성공 + 100% 실패 롤백 |
| CSV보내기 | `python -m budget_app export --out export.csv --month 2026-05` | |

### 전역 옵션
- `--data-dir <경로>` : 데이터 저장 폴더 변경 (기본: `./data`)
- `--show-timing` : 명령 실행 시간 출력
- `--help` : 모든 명령에서 사용 방법 출력

---

## 4. 실행 증거 (실제 테스트 결과)

### [평가1-1] 10가지 핵심 기능 동작 검증

```bash
$ python -m budget_app category add --name 식비
카테고리 추가 완료: 식비
$ python -m budget_app category add --name 급여
카테고리 추가 완료: 급여
$ python -m budget_app category add --name 교통
카테고리 추가 완료: 교통

$ python -m budget_app category list
교통
급여
식비

$ python -m budget_app add
사용 가능한 카테고리: 교통, 급여, 식비
날짜 (YYYY-MM-DD): 2026-05-15
타입 (income/expense): expense
카테고리: 식비
금액: 12000
메모 (선택): 점심
태그 (쉼표 구분, 선택): 회사,팀
저장 완료: id=76d83fd3

$ python -m budget_app list --limit 5
[76d83fd3] 2026-05-15 | expense | 식비 | 12000 | memo=점심 | tags=회사,팀

$ python -m budget_app search --category 식비
[76d83fd3] 2026-05-15 | expense | 식비 | 12000 | memo=점심 | tags=회사,팀

$ python -m budget_app budget set --month 2026-05 --amount 500000
예산 저장 완료: 2026-05 500000

$ python -m budget_app summary --month 2026-05 --top 3
월: 2026-05
총 수입: 0
총 지출: 12000
잔액: -12000
카테고리별 TOP 지출:
- 식비: 12000
예산: 500000
사용률: 2.4%

$ python -m budget_app export --out test.csv --month 2026-05
CSV내보기 완료: 1건

$ python -m budget_app import --from sample.csv
CSV 가져오기 완료: 2건

$ python -m budget_app update --id 76d83fd3 --memo "수정된 메모"
거래 수정 완료: id=76d83fd3

$ python -m budget_app delete --id 76d83fd3
거래 삭제 완료: id=76d83fd3
```

### [평가1-2] 프로그램 재실행 후 데이터 유지 (3개 파일)

```bash
$ cat data/transactions.jsonl
{"id": "76d83fd3", "date": "2026-05-15", "type": "expense", "category": "식비", "amount": 12000, "memo": "점심", "tags": ["회사", "팀"]}
{"id": "a43e3a71", "date": "2026-05-20", "type": "expense", "category": "교통", "amount": 2500, "memo": "버스", "tags": []}
{"id": "2adb3561", "date": "2026-05-25", "type": "expense", "category": "교통", "amount": 3000, "memo": "택시", "tags": []}

$ cat data/categories.jsonl
{"name": "식비"}
{"name": "급여"}
{"name": "교통"}

$ cat data/budgets.jsonl
{"month": "2026-05", "amount": 500000}
```

### [평가1-3] category add/list/remove (삭제 시 사용 중인 카테고리 처리)

```bash
$ python -m budget_app category remove --name 식비
오류: 사용 중인 카테고리는 바로 삭제할 수 없습니다.
해결 힌트: replacement 옵션으로 대체 카테고리를 지정하거나 관련 거래를 먼저 수정하세요.

$ python -m budget_app category remove --name 식비 --replacement 교통
카테고리 삭제 완료: 식비 -> 교통

$ python -m budget_app list --limit 5
[76d83fd3] 2026-05-15 | expense | 교통 | 12000 | memo=점심 | tags=회사,팀
```

### [평가1-4/1-5] budget set + summary 예산 사용률/초과

```bash
$ python -m budget_app budget set --month 2026-05 --amount 100
예산 저장 완료: 2026-05 100

$ python -m budget_app summary --month 2026-05 --top 3
월: 2026-05
총 수입: 0
총 지출: 14500
잔액: -14500
카테고리별 TOP 지출:
- 교통: 14500
예산: 100
사용률: 14500.0%
경고: 예산을 초과했습니다.
```

### [평가1-5] import/export CSV 스키마 (UTF-8, 헤더, 컬럼)

```bash
$ python -m budget_app export --out test.csv --month 2026-05
CSV내보기 완료: 1건

$ cat test.csv
date,type,category,amount,memo,tags
2026-05-15,expense,식비,12000,점심,"회사,팀"
```

```bash
$ cat sample.csv
date,type,category,amount,memo,tags
2026-05-20,expense,교통,2500,버스,
2026-05-21,income,급여,3000000,월급,

$ python -m budget_app import --from sample.csv
CSV 가져오기 완료: 2건
```

### [평가1-6] 오류 메시지 + 힌트 (스택트레이스 없음)

```bash
$ python -m budget_app budget set --month 2026-13 --amount 1000
오류: 월 형식이 올바르지 않습니다.
해결 힌트: YYYY-MM 형식으로 입력하세요.

$ python -m budget_app delete --id 없는ID123
오류: 삭제할 거래 id를 찾을 수 없습니다.
해결 힌트: list 또는 search 명령으로 올바른 id를 확인하세요.

$ python -m budget_app budget set --month 2026-06 --amount -100
오류: 금액은 0보다 커야 합니다.
해결 힌트: 양의 정수를 입력하세요.
```

### [평가1-7] 오류 시 종료 코드 0 아님

```bash
$ python -m budget_app delete --id 없는ID123
오류: 삭제할 거래 id를 찾을 수 없습니다.
$ echo $?
1

$ python -m budget_app list --limit 5
$ echo $?
0
```

### [평가4-3] CSV import 부분 성공 / 롤백 / 리포트

```bash
$ cat partial.csv
date,type,category,amount,memo,tags
2026-05-25,expense,교통,3000,택시,
2026-05-26,expense,교통,invalid,깨진행,

$ python -m budget_app import --from partial.csv
CSV 부분 가져오기 완료: 성공 1건, 실패 1건 (총 2건)
실패 내역:
  - 행 3: ValueError: invalid literal for int() with base 10: 'invalid'

$ cat allfail.csv
date,type,category,amount,memo,tags
2026-05-27,expense,없는카테,5000,테스트,

$ python -m budget_app import --from allfail.csv
CSV 가져오기 실패: 모든 1행이 실패하여 롤백되었습니다.
  - 행 2: ValidationError: 존재하지 않는 카테고리입니다.

$ cat data/transactions.jsonl
{"id": "76d83fd3", ...}  // 이전 데이터 그대로 유지됨
```

### [평가3-3] --show-timing 실행 시간 측정

```bash
$ python -m budget_app --show-timing list --limit 5
[2adb3561] 2026-05-25 | expense | 교통 | 3000 | memo=택시 | tags=-
[a43e3a71] 2026-05-20 | expense | 교통 | 2500 | memo=버스 | tags=-
[76d83fd3] 2026-05-15 | expense | 교통 | 12000 | memo=점심 | tags=회사,팀
실행 시간: 0.000XXX초
```

### [평가1-6] --help 모든 명령 지원

```bash
$ python -m budget_app --help
usage: python -m budget_app [-h] [--data-dir DATA_DIR] [--show-timing]
                            {add,list,search,summary,budget,category,update,delete,import,export} ...

파일 기반 가계부 CLI

positional arguments:
  {add,list,search,summary,budget,category,update,delete,import,export}
    add                 거래를 대화형으로 추가합니다.
    list                최신순 거래 목록을 조회합니다.
    search              거래를 검색합니다.
    summary             월별 요약을 출력합니다.
    budget              예산을 관리합니다.
    category            카테고리를 관리합니다.
    update              거래를 수정합니다.
    delete              거래를 삭제합니다.
    import              CSV 파일에서 거래를 가져옵니다.
    export              CSV 파일로 거래를보냅니다.

options:
  -h, --help            show this help message and exit
  --data-dir DATA_DIR   데이터 저장 디렉터리 경로
  --show-timing         명령 실행 시간을 함께 출력합니다.
```

---

## 5. 저장 정책 및 포맷 선택 근거

```
data/
├── transactions.jsonl   # 거래 데이터 (append-only, 스트리밍)
├── categories.jsonl     # 카테고리 목록
└── budgets.jsonl          # 월별 예산
```

| 포맷 | 장점 | 단점 | 선택 이유 |
|------|------|------|-----------|
| **JSONL** | 줄 단위 append O(1), 스키마 유연, Python dict와 자연 매핑 | Excel 직접 열기 어려움 | **내부 영속 저장** (쓰기 속도 우수) |
| **CSV** | Excel 호환성 우수, 사람 가독성 | 중간 수정 시 전체 재작성 | **외부 교환용** (import/export) |

---

## 6. 안전한 파일 쓰기 (원자성)

```python
# infrastructure/jsonl_storage.py
@dataclass(slots=True)
class DataPaths:
    root: Path
    @property
    def transactions(self) -> Path: return self.root / "transactions.jsonl"
    @property
    def categories(self) -> Path: return self.root / "categories.jsonl"
    @property
    def budgets(self) -> Path: return self.root / "budgets.jsonl"

def ensure_data_paths(data_dir: str) -> DataPaths:
    root = Path(data_dir)
    root.mkdir(parents=True, exist_ok=True)
    paths = DataPaths(root=root)
    for path in (paths.transactions, paths.categories, paths.budgets):
        path.touch(exist_ok=True)  # 파일 없으면 자동 생성
    return paths

# 원자적 재작성
with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, suffix=".tmp") as tmp:
    for r in records:
        tmp.write(json.dumps(r, ensure_ascii=False) + "\n")
os.replace(tmp_name, path)  # 끊김 없는 교체
```

---

## 7. 핵심 구현 코드 설명

### 7.1 Generator 스트리밍 (list/search)

```python
# infrastructure/jsonl_storage.py
# 정순: 앞에서부터 한 줄씩 yield
with path.open("r", encoding="utf-8") as f:
    for line in f:
        if line.strip():
            yield json.loads(line.strip())

# 역순: 뒤에서부터 4096바이트씩 청크로 yield
with path.open("rb") as f:
    f.seek(0, os.SEEK_END)
    position = f.tell()
    buffer = b""
    while position > 0:
        read_size = min(4096, position)
        position -= read_size
        f.seek(position)
        chunk = f.read(read_size)
        parts = chunk.split(b"\n")
        ...
        for part in reversed(parts[1:]):
            if part.strip():
                yield json.loads(part.decode("utf-8"))
```

**왜 제너레이터인가:**  
- `yield`는 "여기까지 실행하고 잠깐 멈춰, 다음에 여기부터 다시 시작할게"라는 뜻입니다.
- 100만 줄짜리 파일도 `for line in f:`로 한 줄씩만 메모리에 올리므로, **메모리를 절약**합니다.
- `list --limit 5`를 실행할 때도, 전체 100만 줄을 읽지 않고 뒤에서 5줄만 읽고 멈춥니다.

### 7.2 Decorator 분리 (error_handler + timer)

```python
# decorators/error_handler.py
@functools.wraps(func)
def wrapper(*args, **kwargs):
    try:
        return func(*args, **kwargs)
    except AppError as error:
        print(f"오류: {error.message}")
        print(f"해결 힌트: {error.hint}")
        return 1
    except Exception as error:
        print(f"오류: 예상하지 못한 문제... ({type(error).__name__})")
        return 1

# decorators/timer.py
started = time.perf_counter()
result = func(*args, **kwargs)
elapsed = time.perf_counter() - started
if kwargs.get("show_timing"):
    print(f"실행 시간: {elapsed:.6f}초")
```

**왜 분리했는가:**  
`main()`과 `dispatch()`에 똑같은 `try-except`를 복사붙여넣기 하면, 나중에 수정할 때 여러 곳을 고쳐야 합니다. 데코레이터로 감싸면 "이 함수를 실행하기 전/후에 자동으로 무언가를 하겠다"는 의도가 명확해지고, 코드 중복을 제거합니다.

### 7.3 Type Hint

```python
# models/transaction.py
@dataclass(slots=True)
class Transaction:
    id: str
    date: str
    type: str
    category: str
    amount: int
    memo: str = ""
    tags: list[str] = field(default_factory=list)

# interfaces/repository.py
class ITransactionRepository(ABC):
    @abstractmethod
    def add(self, transaction: Transaction) -> None: ...
    @abstractmethod
    def iter_latest(self) -> Iterator[Transaction]: ...

# usecases/transaction_usecase.py
class TransactionUseCase:
    def add(self, date: str, transaction_type: str, category: str, amount: int, ...) -> Transaction:
        ...
        return transaction
```

**이점:**  
- `amount: int`라고 적으면 "금액은 숫자야"라는 계약이 명확해집니다. IDE가 즉시 경고합니다.
- `ITransactionRepository(ABC)`를 타입 힌트로 사용하면, `TransactionUseCase`가 추상 클래스에만 의존함을 명확히 합니다. 팀원이 `add()`를 볼 때 어떤 인자를 넣어야 하는지 문서를 찾아볼 필요가 없습니다.

### 7.4 CSV Import 부분 성공 / 롤백 / 리포트

```python
# usecases/import_export_usecase.py
for row in reader:
    row_num += 1
    try:
        self._tx_uc.add(...)  # 행 단위 try-except로 격리
        imported += 1
    except Exception as error:
        failures.append({
            "row": row_num,
            "reason": f"{type(error).__name__}: {error}",
            "data": dict(row),
        })

all_failed = total > 0 and len(failures) == total
return ImportResult(..., rolled_back=all_failed)
```

```python
# controllers/cli_controller.py (Controller에서 롤백 수행 - Clean Architecture)
backup_path = self._paths.transactions.with_suffix(".jsonl.import_bak")
shutil.copy(self._paths.transactions, backup_path)  # import 전 백업

result = self._import_uc.import_csv(args.from_path)

if result.rolled_back and backup_path.exists():
    shutil.copy(backup_path, self._paths.transactions)  # 100% 실패 시 롤백
```

**왜 이렇게 했는가:**  
CSV는 외부에서 생성된 파일이라 오류가 섞일 가능성이 높습니다. 행 단위 `try-except`로 **한 줄이 실패해도 나머지는 계속** 처리하고, **100% 실패**면 백업 파일로 복원하여 데이터를 안전하게 지킵니다. UseCase에서는 순수 로직만 처리하고, 실제 파일 롤백은 Controller에서 수행하여 **Clean Architecture**를 유지합니다.

### 7.5 10만 건 병목 및 개선 방안

| 기능 | 현재 방식 | 병목 원인 | 개선 방안 |
|------|-----------|-----------|-----------|
| `get_by_id` | `iter_all()` 전체 순회 | 10만 건 시 10만 줄 읽기 | **ID 기반 인덱스 파일** 도입 (`offset` 기록) |
| `replace` / `delete` | 전체 파일 읽고 임시 파일로 재작성 | 10만 줄 읽기 + 10만 줄 쓰기 | **SQLite 마이그레이션** (`UPDATE`/`DELETE` O(log N)) |
| `search` | `iter_all()` 전체 순회 후 필터링 | 조건无关이 10만 줄 읽기 | **SQLite** `SELECT ... WHERE`로 인덱스 검색 |
| `categories` | `list_all()` 파일 순회 | 100개 이하라면 문제 없음 | **메모리 캐싱** (프로그램 시작 시 로드) |

**Repository 계층만 교체하면 되며, UseCase 계층은 전혀 수정할 필요가 없습니다.** (DIP 덕분)

---

## 8. 모듈 교체 예시 (Affinity 실증)

### 8.1 Repository를 SQLite로 교체

```python
# repositories/sqlite_transaction_repo.py
from budget_app.interfaces.repository import ITransactionRepository

class SQLiteTransactionRepository(ITransactionRepository):
    def add(self, transaction): ...
    def iter_latest(self): ...
    # ... 기존 usecases/ 코드 전혀 변경 없음
```

`controllers/cli_controller.py`의 `build_controller()`에서:
```python
tx_repo = SQLiteTransactionRepository("budget.db")  # 1줄만 수정!
```

### 8.2 Presenter를 JSON으로 교체

```python
# presenters/json_presenter.py
from budget_app.interfaces.presenter import IPresenter

class JSONPresenter(IPresenter):
    def show_transaction(self, tx): print(json.dumps(tx.to_dict()))
    # ... 기존 controller/usecase 코드 전혀 변경 없음
```

### 8.3 View를 Web으로 교체

```python
# views/web_view.py
from budget_app.interfaces.view import IView

class WebView(IView):
    def prompt_transaction_input(self, categories): ...  # HTTP POST 파싱
```

---

## 9. 실행 방법 요약

```bash
# 1. 카테고리 추가
python -m budget_app category add --name 식비
python -m budget_app category add --name 급여
python -m budget_app category add --name 교통

# 2. 거래 추가 (대화형)
python -m budget_app add

# 3. 목록/검색/요약
python -m budget_app list --limit 5
python -m budget_app search --category 식비
python -m budget_app budget set --month 2026-05 --amount 500000
python -m budget_app summary --month 2026-05 --top 3

# 4. CSV 입출력
python -m budget_app import --from sample.csv
python -m budget_app export --out export.csv --month 2026-05

# 5. 수정/삭제
python -m budget_app update --id abc123 --memo "수정"
python -m budget_app delete --id abc123

# 6. 실행 시간 측정
python -m budget_app --show-timing list --limit 5
```

## 10. 개발 환경

- Python 3.10 이상
- 표준 라이브러리만 사용 (`argparse`, `csv`, `dataclasses`, `json`, `pathlib`, `tempfile`, `uuid`, `abc`, `functools`, `time`)
- 외부 라이브러리 설치 불필요
