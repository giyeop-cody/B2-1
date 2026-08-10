# B2-1: 나만의 용돈 기입장 프로그램 만들기

## 📋 과제 정보

| 항목 | 내용 |
|------|------|
| **과목** | Python과 Git 심화 |
| **난이도** | ★★☆ (Lv.2) |
| **학습 시간** | 60분 |
| **과제 번호** | 185006 |

---

## 🎯 미션 소개

Python 표준 라이브러리만으로 MVC + Clean Architecture 계층 구조의 파일 기반 가계부 CLI를 만듭니다. 거래 추가/조회/수정/삭제, 카테고리 관리, 예산 설정 기능을 구현합니다.

---

## 🎓 학습 목표

이 과제를 완료한 뒤, 다음을 설명할 수 있어야 한다:

1. MVC 패턴으로 UI/비즈니스로직/데이터저장을 분리할 수 있다
2. 계층 구조(View → Controller → UseCase → Repository)를 설계할 수 있다
3. JSONL/CSV 파일 기반 데이터 저장을 구현할 수 있다
4. 인터페이스 기반 의존성 역전으로 모듈 교환 가능성을 확보할 수 있다

---

## 📦 최종 결과물

1. Python 가계부 CLI 프로그램 (표준 라이브러리만 사용)
2. MVC + Clean Architecture 계층 구조
3. transactions/categories/budgets 3개 이상 파일 분리
4. README (실행 방법, 아키텍처 다이어그램)

---

## 🛠️ 개발 환경

### 6\. 개발 환경

*   Python 3.10 이상

---

## ⚠️ 제약 사항

### 7\. 제약 사항

*   라이브러리
    *   표준 라이브러리만 사용 가능
    *   별도 `pip install`이 필요한 외부 라이브러리 사용 금지
*   저장 방식
    *   JSONL 또는 CSV 중 1개를 선택해 사용
    *   저장 파일은 3개 이상(transactions/categories/budgets)으로 분리
*   CLI 규칙
    *   옵션 표기는 `-`로 통일
*   오류 처리
    *   스택트레이스 출력 금지(원인 + 해결 힌트 출력)
    *   오류 종료 시 exit code는 0이 아니어야 함

---

## 📝 결과 예시

### 8\. 결과 예시

아래는 정답이 아니라 참고 예시다. 실제 문구와 디자인은 달라도 된다.

*   add(거래 추가) 화면:
    
    ```css
    $ python -m budget_app add
    날짜(YYYY-MM-DD): 2024-01-15
    타입(income/expense): expense
    카테고리: food
    금액(양수): 15000
    메모(선택): 점심
    태그(쉼표로 구분, 없으면 엔터): meal
    [저장 완료] id=TX-000012
    ```
    
*   list(거래 목록) 화면:
    
    ```css
    $ python -m budget_app list --limit 3
    TX-000012 | 2024-01-15 | expense | food | 15000 | 점심
    TX-000011 | 2024-01-14 | income  | salary | 3000000 |
    TX-000010 | 2024-01-12 | expense | transport | 20000 |
    ```
    
*   category(카테고리 관리) 화면:
    
    ```css
    $ python -m budget_app category add
    카테고리명: food
    [저장 완료] category=food
    
    $ python -m budget_app category list
    - food
    - transport
    ```
    
*   budget + summary(예산 + 월별 요약) 화면:
    
    ```css
    $ python -m budget_app budget set --month 2024-01 --amount 500000
    [저장 완료] 2024-01 예산 500000원
    
    $ python -m budget_app summary --month 2024-01 --top 3
    총 수입: 3000000원
    총 지출: 215000원
    잔액: 2785000원
    예산: 500000원 (사용률 43.0%)
    
    지출 TOP 3
    1) rent 150000원
    2) food 45000원
    3) transport 20000원
    ```
    
*   export / import(CSV 내보내기/가져오기) 화면:
    
    ```css
    $ python -m budget_app export --out export.csv --month 2024-01
    [완료] export.csv (12 records)
    
    $ python -m budget_app import --from import.csv
    [완료] imported=5, skipped=0
    ```
    
*   오류 출력(예시) 화면:
    
    ```css
    $ python -m budget_app add
    날짜(YYYY-MM-DD): 2024-13-40
    [오류] 날짜 형식이 올바르지 않습니다 (YYYY-MM-DD).
    [힌트] 예: 2024-01-15
    ```

---

> *이 문서는 Codyssey AI/SW 기초 과정의 과제 내용을 기반으로 작성되었습니다.*
