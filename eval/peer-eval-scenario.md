# B2-1 동료평가 시나리오

## 1. 학습
- Python 기본 문법 (변수, 조건, 반복, 함수, 클래스)
- 파일 I/O (JSONL 저장/로드)
- 예외 처리 (try/except, 사용자 메시지)
- Git 워크플로우 (commit, branch, push)

## 2. 고찰
- "문법을 배우는 것이 아니라 문법으로 무언가를 만드는 것"
- "예외 처리는 UX — 사용자가 에러를 보면 당황"

## 3. 시도
- Entry 클래스 (date, amount, type, category, memo)
- CRUD: 입력/조회/수정/삭제
- JSONL 파일 저장 (한 줄에 하나의 JSON)
- 통계: 수입/지출 합계
- Git: 기능별 커밋

## 4. 수정
- CSV → JSONL (구조화된 데이터, 확장성)
- 스택트레이스 → 사용자 메시지 (UX 개선)

## 5. 선택과 선정
- JSONL vs CSV: JSONL (구조화, 확장성)
- 클래스 vs 함수: 클래스 (데이터+로직 묶음)
- 외부 라이브러리 금지: 표준 라이브러리만 (기본기)

## 6. 트러블슈팅
- 파일이 없을 때 에러 → try/except로 빈 리스트 반환
- JSON 파싱 에러 → 잘못된 줄 건너뛰기
- 금액 입력 시 문자열 → int() 변환 + ValueError 처리

## 7. 평가 예상 질문
- 데이터 저장 방식? → JSONL (구조화, 확장성)
- 예외 처리? → try/except + 사용자 메시지
- CRUD 설명? → Create/Read/Update/Delete 기본 패턴
