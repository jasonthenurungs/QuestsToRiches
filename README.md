<p align="center"><img src="media/qtr_logo_square.png" width="160" alt="QuestsToRiches logo"></p>

# QuestsToRiches (골드퀘로 부자되기)

A World of Warcraft (Midnight) addon that tracks gold world quests and the special assignments they unlock
across all of your characters, runs them along the fastest route, and shows how soon you will reach your gold goal.

- Korean and English clients are supported.
- Available on CurseForge (author: Nurungs).
- 한국어 설명은 아래에 있습니다.

## Features

- Dashboard with four tabs
  - Gold Quests: gold world quests (500g or more) your current character can still do, grouped by zone
  - Riches: every current gold quest and special assignment on your account, with completion per character
    and the next character to play
  - Earnings: gold from gold quests and Pinnacle Caches by day, week, month or all time
  - Holdings: account gold history, per character, with day-over-day change
- Goal progress bar, 7-day average and estimated completion date
- Navigation: orders the remaining quests nearest-first, using portals, hearthstones and travel abilities
  when they are faster (TomTom if installed, otherwise the game waypoint)
- Special assignment tracking, unopened cache alerts and cache gold records
- Minimap button, addon compartment entry and account-wide keybindings

## Commands

- `/qtr` : open or close the window
- `/qtr gq`, `/qtr rich`, `/qtr stats`, `/qtr hold` : open a tab
- `/qtr set` : settings
- `/qtr route` : start navigation (`/qtr route clear` : stop)
- `/qtr hearth` : hearthstone and travel ability status
- `/qtr ban`, `/qtr unban` : exclude or restore a quest
- `/qtr list` : saved gold per character

## Repository layout

- `src/QuestsToRiches/` : the addon itself (copy this folder into `Interface/AddOns`)
- `tests/` : simulation tests that run the addon in Lua 5.1 (via Python and lupa) against a mock WoW API
- `docs/` : CurseForge description and changelogs
- `media/` : logo and icon sources
- `tools/navlog/` : scripts that analyze recorded navigation runs

## Development

- `pip install lupa`
- `python tests/check.py` : syntax check, main-chunk local headroom, and allowed characters
- `python tests/check_locale.py` : every on-screen string has an English translation
- `python tests/runNN.py` : feature simulations; compare the output with `tests/runNN.chk`
- Packaging: zip the `src/QuestsToRiches` folder itself, so the zip contains `QuestsToRiches/`.

## Credits

- Libraries: Ace3 (bundled in `src/QuestsToRiches/Libs`, under its own license, see `Libs/Ace3-LICENSE.txt`)
- Special Assignment quest IDs via GoldWQ by Marcus (Public Domain),
  originally from WeeklyRewards by cybertk (Copyright (c) 2025 Quanlong, MIT License)
- Hearthstone toy item IDs from RandomHearth by JamienAU
- Silvermoon weekly quest IDs from Apex Ledger by Andrew (MIT License)

## License

MIT License. See [LICENSE](LICENSE). The bundled Ace3 libraries keep their own license.

---

# 골드퀘로 부자되기 (QuestsToRiches)

월드 오브 워크래프트(한밤) 애드온입니다. 모든 캐릭터의 골드 전역퀘와 그로 열리는 특별 과제를 한곳에서 관리하고,
가장 빠른 동선으로 돌고, 목표 골드까지 언제 닿을지 보여 줍니다.

- 한국어와 영어 클라이언트를 지원합니다.
- 커스포지에서 받을 수 있습니다 (작성자: Nurungs).

## 기능

- 대시보드 4탭
  - 골드퀘: 지금 캐릭터가 할 수 있는 골드 전역퀘(500골드 이상)를 지역별로 표시
  - 부자되기: 계정 전체의 현재 골드퀘와 특별 과제별 캐릭터 완료 현황, 다음에 접속할 캐릭터 추천
  - 획득량: 골드퀘와 정점 보관함으로 번 골드를 일별, 주별, 월별, 전체로 집계
  - 보유량: 계정 보유 골드 기록, 캐릭터별 상세와 전일비
- 목표 골드 진행률, 최근 7일 하루 평균, 달성 예상일
- 내비게이션: 남은 퀘스트를 가까운 순서로 잇고, 더 빠르면 포탈, 귀환석, 이동 기술을 거쳐 가도록 편성
  (TomTom이 있으면 TomTom, 없으면 게임 웨이포인트)
- 특별 과제 추적, 열지 않은 보관함 알림, 보관함 골드 기록
- 미니맵 버튼, 애드온 보관함 등록, 계정 공통 단축키

## 명령어

- `/qtr` : 창 열기/닫기
- `/qtr gq`, `/qtr rich`, `/qtr stats`, `/qtr hold` : 탭 열기
- `/qtr set` : 설정창
- `/qtr route` : 내비게이션 시작 (`/qtr route clear` : 중지)
- `/qtr hearth` : 귀환석과 이동 기술 상태
- `/qtr ban`, `/qtr unban` : 추적 제외 추가, 해제
- `/qtr list` : 캐릭터별 저장된 보유 골드

## 폴더 구성

- `src/QuestsToRiches/` : 애드온 본체 (이 폴더를 `Interface/AddOns`에 넣으면 됩니다)
- `tests/` : 와우 API를 흉내 내 애드온을 Lua 5.1(Python과 lupa)로 돌리는 시뮬레이션 테스트
- `docs/` : 커스포지 설명문과 변경 내역
- `media/` : 로고와 아이콘 원본
- `tools/navlog/` : 내비게이션 기록 분석 스크립트

## 개발

- `pip install lupa`
- `python tests/check.py` : 문법 검사, 메인 청크 local 여유, 허용 문자 검사
- `python tests/check_locale.py` : 화면 문구마다 영어 번역이 있는지 확인
- `python tests/runNN.py` : 기능별 시뮬레이션, 출력을 `tests/runNN.chk`와 비교
- 배포 zip: `src/QuestsToRiches` 폴더 째로 압축 (zip 안에 `QuestsToRiches/` 폴더가 들어가게)

## 출처

- 사용 라이브러리: Ace3 (`src/QuestsToRiches/Libs`에 포함, Ace3 자체 라이선스, `Libs/Ace3-LICENSE.txt` 참고)
- 특별 과제 퀘스트 ID 표: GoldWQ (Marcus, Public Domain) 경유,
  원출처 WeeklyRewards by cybertk (Copyright (c) 2025 Quanlong, MIT License)
- 귀환석 장난감 아이템 ID: RandomHearth by JamienAU
- 실버문 주간 퀘스트 ID: Apex Ledger by Andrew (MIT License)

## 라이선스

MIT 라이선스입니다. [LICENSE](LICENSE)를 참고하세요. 포함된 Ace3 라이브러리는 Ace3 자체 라이선스를 따릅니다.
