# B2-1 동료평가 대비 가이드

## 1. 이 과제가 뭔가요?
Python 표준 라이브러리만으로 가계부 CLI 프로그램을 만들고, MVC + Clean Architecture 계층 구조로 설계하는 과제.

## 2. 평가 예상 질문

### 학습 목표 #1: MVC 패턴 (UI/비즈니스로직/데이터저장 분리)

Q1. MVC 패턴으로 어떻게 분리했나요?
A. 세 가지 역할을 명확히 나눴습니다:
- **Model** (`models/`): Transaction, Budget, Category — 데이터 구조만 정의 (비즈니스 로직 없음)
- **View** (`views/console_view.py`): 사용자에게 보여주는 화면만 담당 (데이터 처리 없음)
- **Controller** (`controllers/cli_controller.py`): 사용자 입력을 받아 UseCase를 호출하고 View로 전달

이렇게 분리하면 UI를 콘솔에서 GUI로 바꿔도 Model과 비즈니스 로직은 그대로 재사용할 수 있습니다.

### 학습 목표 #2: 계층 구조 (View→Controller→UseCase→Repository)

Q2. 4계층 구조의 데이터 흐름을 설명해주세요.
A. 요청이 바깥에서 안쪽으로 흐릅니다:
1. **View**: 사용자 입력 표시 (console_view.py)
2. **Controller**: CLI 명령 파싱, UseCase 호출 (cli_controller.py)
3. **UseCase**: 비즈니스 로직, 검증, 집계 (transaction_usecase.py 등)
4. **Repository**: 실제 파일 I/O (jsonl_transaction_repo.py)

의존성 방향이 항상 바깥→안쪽이므로, Repository를 JSONL에서 SQLite로 교체해도 UseCase 이상은 변경할 필요가 없습니다.

### 학습 목표 #3: JSONL/CSV 파일 기반 데이터 저장

Q3. JSONL과 CSV를 어떻게 구현했나요? 왜 JSONL을 기본으로 선택했나요?
A. 기본 저장은 **JSONL**(JSON Lines)을 사용합니다 — 한 줄에 하나의 JSON 객체를 append합니다. CSV보다 JSONL을 선택한 이유는:
1. 구조화된 데이터: 트랜잭션에 중첩 필드(category 객체 등)가 있어 JSON이 적합
2. 확장성: 새 필드 추가 시 기존 데이터와 호환
3. append 가능: 한 줄씩 추가하므로 전체 파일 재작성 불필요

CSV는 `import_export_usecase.py`에서 import/export 기능으로 구현했습니다 — 다른 시스템과 데이터 교환할 때 CSV 형식을 지원합니다.

### 학습 목표 #4: 인터페이스 기반 의존성 역전

Q4. 의존성 역전으로 모듈 교환 가능성을 어떻게 확보했나요?
A. `interfaces/` 디렉터리에 추상 인터페이스를 정의했습니다:
- `interfaces/repository.py`: Repository 계약 (save, find_by_id, find_all 등)
- `interfaces/presenter.py`: Presenter 계약 (출력 형식)
- `interfaces/view.py`: View 계약

UseCase는 구체적인 `JsonlTransactionRepository`가 아니라 `Repository` 인터페이스에 의존합니다. 그래서 Repository를 JSONL→SQLite→Redis로 교체할 때, UseCase 코드는 전혀 수정하지 않고 새 Repository만 추가하면 됩니다. 이것이 의존성 역전 원칙(DIP)입니다.

### 기타

Q5. 외부 라이브러리 금지 영향?
A. 표준 라이브러리만 사용 — 기본기 점검, 의존성 최소화. argparse, json, csv, pathlib 등 표준 라이브러리만으로 충분히 구현 가능함을 체득.

Q6. 예외 처리 방식?
A. try/except로 에러를 잡고 사용자 친화적 메시지 출력. 스택트레이스 출력 금지. 커스텀 예외(AppError, ValidationError, NotFoundError)로 상황별 처리.
