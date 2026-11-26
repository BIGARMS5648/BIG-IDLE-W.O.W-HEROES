# BIG IDLE HEROES

월드 오브 워크래프트: 포에버(WoW Forever)용 방치형 파티 RPG 애드온입니다. 전투 창에서 영웅 파티가 저절로 싸우고, 플레이어는 영웅·장비·대장간·룬을 관리합니다. 게임은 한국어만 씁니다.

## 설치

`BigIdleHeroes` 폴더를 와우의 `Interface/AddOns`에 복사합니다. 진행은 계정 공용 SavedVariables(`BigWowIdleDB`)에 저장됩니다.

## 명령어

- `/bih`: 메뉴 창 열기·닫기
- `/bih bar`: 전투 창 표시·숨김
- `/bih reset`: 전투 창 위치 초기화
- `/bih ground`: 땅 그림 확인

## 폴더

```
BigIdleHeroes/   애드온 본체 (Core, Data, Systems, UI, Media)
tests/           모의 WoW API, 테스트, 시뮬레이션, 화면 미리보기·배치 검사
tools/           그림 만들기·자르기, TBH 데이터 변환 스크립트 (tools/art: 원본 그림)
docs/            CurseForge 설명(영어), 전투 배경 그림 출처
```

## 테스트

`pip install lupa`가 필요합니다.

```
python3 tests/run.py systems     # 시스템 테스트
python3 tests/run.py ui          # 화면 테스트
python3 tests/run.py audit       # 전투 공식 점검
python3 tests/run.py pace 70     # 긴 진행 시뮬레이션
python3 tests/preview.py && node tests/layout_check.js   # 글자 잘림·겹침 검사
```

게임 규칙과 사용자 결정 사항은 `CLAUDE.md`에 있습니다.
