# QuestsToRiches (골드퀘로 부자되기)

Track gold world quests and the special assignments they unlock across all of your characters,
run them along the fastest route, and see how soon you will reach your gold goal.

Works on Korean and English clients (all windows, settings and messages are translated).

## Dashboard
- Header: progress bar toward your gold goal, 7-day average,
  and estimated completion date by earnings trend and by net holdings trend.
- 1. Gold Quests: gold world quests (500g or more) your current character can still do,
  grouped by zone, with time left and reward (War Mode bonus included).
  Unlocked special assignments are listed separately; locked ones show unlock progress.
  Click a quest to set a waypoint (TomTom if installed). Hover for objectives and rewards.
- 2. Riches: every current gold quest and special assignment on your account,
  with how many max-level characters have completed each. Click a line for per-character status.
  Special assignments show whether each character has unlocked them ("Locked (n/3)"),
  and Silvermoon weeklies show each character's progress ("35/100").
  Also recommends the next character to play. Sort classes into Preferred, Normal and Avoid by dragging them in Settings,
  and hover over the recommended name to see why it was picked.
- 3. Earnings: gold from gold quests and special assignment caches by day, week, month or all time,
  per-character contribution and recent trend.
- 4. Holdings: account gold history. Summary by day, or detail per character
  with day-over-day change, rank change and share.
- While the mouse is over the window: number keys 1 to 4 switch tabs, and each tab's buttons have
  shortcuts (R, Q W E R, T, comma and period, mouse wheel).
- Pin the dashboard to keep it open through Esc. Window size can be set from 80% to 150%
  (dashboard and navigation window separately).

## Navigation
- Press "Start Navigation!" (or R) on the Gold Quests tab, or set a key binding that starts it directly.
- Orders all remaining gold quests and unlocked special assignments nearest-first,
  using portals when they are faster, and plans locked special assignments after the quests that unlock them.
- Hearthstone: when it saves time, a hearthstone (or a hearthstone toy) is added to the route,
  and the order of stops is planned around it. Guild perk and Human racial (two charges) are taken into account,
  and one charge can be kept for when you finish.
- Travel abilities: Mage Teleport: Silvermoon, Shaman Astral Recall, the Personal Key to the Arcantina
  and the Maisara Caverns Mythic+ teleport (to Zul'Aman) are used when they are faster. Each can be turned off
  (the Mythic+ teleport is off by default, turn it on in Settings).
  When two of them save almost the same time, the one with the shorter cooldown is used.
- Haranir Rootwalking (experimental, off by default): used like a portal to the Cradle in Harandar when it is faster.
- Delve-O-Bot 7001 to the Labyrinth of Kindo'jan (off by default, needs the Labyrinth update chip):
  the Labyrinth is picked automatically when you talk to the bot on that step.
- Dundun's Abundant Travel Method (experimental, off by default): goes to the cave where Abundance is currently active.
- Optional chat lines at the start of navigation: which travel methods were added, and why the others were not.
- Use button: when the next step is a hearthstone or a travel ability, click the small window to use it.
- Quests about to expire are shown in orange and moved earlier; expired quests are removed.
- Right-click a quest line: do it first, do it last, skip it this time, or never show it again.
- With TomTom the whole route is registered; without it, the game waypoint guides you one stop at a time.
- Moves to the next stop when you turn in a quest, take a portal, hearth or teleport.
  Re-plans automatically after a teleport, when a special assignment unlocks, or when you turn War Mode on or off.
- Navigation window: completed stops with time, next stop, remaining stops, portals,
  gold earned and remaining. Pin it to keep it open through Esc, and let it fade when the mouse is away.
  Size and fade: Settings > Navigation > "Navigation window size", "Small text", "Background opacity",
  "Fade the navigation window when the mouse is away", "Opacity when faded".
- When every stop is done: elapsed time, quest count, gold earned, goal progress,
  the next character to play, and a victory sound (DBM's FF Fanfare if DBM is installed).

## Special Assignments
- Tracks the special assignments unlocked by world quests and their two Pinnacle Cache rewards.
- Alert window for unopened caches in your bags (click to open).
- Records the gold from each cache you open.
- Other Pinnacle Caches (such as the Silvermoon weekly cache) are recorded on the Earnings tab, and the Riches tab shows
  which characters received them this week. Jackpots (3,000 gold or more, silver star) and mega jackpots
  (10,000 gold or more, gold star) are marked.

## Other
- Minimap button and addon compartment entry.
- Account-wide keybindings: dashboard, settings, navigation window, start navigation.
- Exclude quests you never do (/qtr ban).
- Optional chat notice with each gold quest you complete.
- Merge character records after a rename (Settings > Character management).
- Several game accounts under one license: leave the shared Warband Bank out of all but one account's holdings
  (Settings > Goal), so the bank is not counted twice.

## Commands
- /qtr : open or close the window
- /qtr gq, /qtr rich, /qtr stats, /qtr hold : open a tab
- /qtr set : settings
- /qtr route : start navigation (/qtr route clear : stop)
- /qtr hearth : hearthstone and travel ability status (inn, cooldown, charges)
- /qtr ban, /qtr unban : exclude or restore a quest (Shift+click the quest)
- /qtr list : saved gold per character

## Notes
- Each character must log in at least once before its records start.
- Gold holdings are based on each character's last login.
- Days reset at midnight, and weekly records follow the Thursday weekly reset.
- The hearthstone is added to navigation after you have hearthed once to that inn with any character.
  The Arcantina key needs the location of the inn it leads to (learned the same way, or after using the key once).
- TomTom and DBM are optional. Without TomTom, navigation uses the built-in waypoint;
  without DBM, the finish sound is the boss kill sound.

## Credits
- Libraries: Ace3
- Special Assignment quest IDs via GoldWQ by Marcus (Public Domain),
  originally from WeeklyRewards by cybertk (Copyright (c) 2025 Quanlong, MIT License).
- Hearthstone toy item IDs from RandomHearth by JamienAU.
- Silvermoon weekly quest IDs from Apex Ledger by Andrew (MIT License).

---

# 골드퀘로 부자되기 (QuestsToRiches)

모든 캐릭터의 골드 전역퀘와 그로 열리는 특별 과제를 한곳에서 관리하고,
가장 빠른 동선으로 돌고, 목표 골드까지 언제 닿을지 보여 주는 애드온입니다.

한국어와 영어 클라이언트를 지원합니다 (모든 창, 설정창, 메시지가 클라이언트 언어로 나옵니다).

## 대시보드
- 머리 영역: 목표 골드 진행률, 최근 7일 하루 평균, 획득 추세와 순증 추세 기준 달성 예상일
- 1. 골드퀘: 지금 캐릭터가 할 수 있는 골드 전역퀘(500골드 이상)를 지역별로, 남은 시간과 보상(전쟁 모드 보너스 포함)과 함께 표시
  잠금 해제된 특별 과제는 따로 모아 보여 주고, 잠긴 특별 과제는 잠금 해제 진행도를 표시
  퀘스트 줄 클릭: 웨이포인트 (TomTom이 있으면 TomTom), 마우스를 올리면 요구 조건과 보상
- 2. 부자되기: 계정 전체의 현재 골드퀘와 특별 과제별로 만렙 캐릭터 몇 명이 완료했는지 표시, 줄을 누르면 캐릭터별 현황
  특별 과제는 캐릭터별 해금 여부("잠김(n/3)"), 실버문 주간 퀘스트는 캐릭터별 진행도("35/100")도 표시
  다음에 접속할 캐릭터도 추천. 설정창에서 직업을 끌어서 선호, 보통, 비선호로 나눌 수 있고, 추천된 이름에 마우스를 올리면 추천 이유 표시
- 3. 획득량: 골드퀘와 특별 과제 보관함으로 번 골드를 일별, 주별, 월별, 전체로 집계하고 캐릭터별 기여도와 최근 추이 표시
- 4. 보유량: 계정 보유 골드 기록 (날짜별 요약, 캐릭터별 상세와 전일비, 순위 등락, 비중)
- 창 위에 마우스를 올리면 숫자키 1~4로 탭 전환, 탭마다 버튼 단축키 (R, Q W E R, T, 쉼표 마침표, 마우스 휠)
- 대시보드를 고정하면 Esc로 닫히지 않음. 창 크기 80% ~ 150% 설정 (대시보드와 내비게이션 창 따로)

## 내비게이션
- 골드퀘 탭의 "내비게이션 시작!" 버튼 (또는 R), 또는 바로 시작하는 단축키 지정
- 남은 골드퀘와 잠금 해제된 특별 과제를 가까운 순서로 잇고, 포탈이 빠르면 포탈을 거쳐 가도록 편성
  잠긴 특별 과제는 그 지역 골드퀘를 마친 뒤에 가도록 편성
- 귀환석: 빨라지는 구간이 있으면 귀환석(또는 귀환석 장난감)을 동선에 넣고, 방문 순서도 귀환석을 고려해 편성
  길드 혜택과 인간 종족 특성(2회 충전)을 반영하고, 마칠 때 1회 남기기 가능
- 이동 기술: 마법사 실버문 순간이동, 주술사 영혼의 귀환, 아르칸티나로 통하는 개인 열쇠, 쐐기돌 던전 마이사라 동굴 순간이동(줄아만)을 더 빠를 때 사용 (각각 끌 수 있음, 쐐기 순간이동은 기본 끔이라 설정에서 켜야 함)
  줄어드는 시간이 거의 같으면 쿨타임이 짧은 쪽을 사용
- 하라니르 뿌리걸음 (시험 기능, 기본 끔): 더 빠를 때 하란다르의 요람으로 가는 포탈처럼 사용
- 구렁로봇 7001로 킨도잔의 미궁 가기 (기본 끔, 미궁 업데이트 칩 필요): 그 차례에 로봇에게 말을 걸면 미궁을 자동으로 고름
- 둔둔의 풍요로운 이동 수단 (시험 기능, 기본 끔): 지금 풍요가 열린 동굴로 이동
- 내비게이션을 시작할 때 어떤 이동 수단을 넣었는지와 나머지를 넣지 않은 이유를 채팅창에 알리기 (선택)
- 사용 버튼 창: 다음 단계가 귀환석이나 이동 기술이면 작은 창을 눌러 바로 사용
- 곧 만료되는 퀘스트는 주황색으로 표시하고 앞으로 당기며, 만료되면 경로에서 뺌
- 퀘스트 줄 우클릭: 가장 먼저, 마지막에, 이번만 빼기, 더 이상 안 하기
- TomTom이 있으면 전체 경로를 등록하고, 없으면 게임 웨이포인트로 한 곳씩 안내
- 퀘스트를 완료하거나 포탈, 귀환석, 순간이동을 타면 다음 목적지로 넘어가고, 순간이동을 하거나 특별 과제가 열리거나 전쟁 모드를 켜고 끄면 남은 경로를 다시 편성
- 내비게이션 창: 완료한 곳과 완료 시각, 다음 목적지, 남은 곳, 포탈, 획득 골드와 남은 골드
  고정하면 Esc로 닫히지 않고, 마우스를 올리지 않으면 흐리게 할 수 있음
  크기와 흐리게: 설정창 "내비게이션" 묶음의 "내비게이션 창 크기", "작은 글씨", "배경 투명도",
  "마우스를 올리지 않았을 때 내비게이션 창을 흐리게", "흐릴 때 불투명도"
- 모두 마치면 소요 시간, 퀘스트 수, 획득 골드, 진척도, 다음 추천 캐릭터와 함께 완료 소리 (DBM이 있으면 DBM의 FF 팡파레)

## 특별 과제
- 전역퀘로 열리는 특별 과제와 그 보상인 정점 보관함 2종을 추적
- 가방에 열지 않은 보관함이 있으면 알림창 표시 (클릭해서 열기)
- 보관함을 열 때 나온 골드를 기록
- 실버문 주간 최정상 보관함 같은 다른 정점 보관함도 획득량 탭에 기록하고, 부자되기 탭에서 이번 주 캐릭터별 획득 여부 표시.
  3,000골드 이상은 대박(은색 별), 10,000골드 이상은 초대박(금색 별)으로 표시

## 그 밖의 기능
- 미니맵 버튼, 애드온 보관함 등록
- 계정 공통 단축키: 대시보드, 설정창, 내비게이션 창, 내비게이션 시작
- 하지 않는 퀘스트 추적 제외 (/qtr ban)
- 골드퀘 완료 시 채팅 알림 (선택)
- 캐릭터 이름을 바꿨을 때 옛 이름 기록 합치기 (설정창 "캐릭터 관리")
- 하위 계정(WoW1, WoW2 등)을 여럿 쓸 때: 함께 쓰는 전투부대 은행을 한 계정에만 넣고 나머지 계정 보유량에서 빼기 (설정창 "목표")

## 명령어
- /qtr : 창 열기/닫기
- /qtr gq, /qtr rich, /qtr stats, /qtr hold : 탭 열기
- /qtr set : 설정창
- /qtr route : 내비게이션 시작 (/qtr route clear : 중지)
- /qtr hearth : 귀환석과 이동 기술 상태 (귀환 지점, 쿨타임, 충전)
- /qtr ban, /qtr unban : 추적 제외 추가, 해제 (퀘스트 Shift+클릭)
- /qtr list : 캐릭터별 저장된 보유 골드

## 참고 사항
- 각 캐릭터로 한 번 이상 접속해야 그 캐릭터의 기록이 쌓이기 시작합니다.
- 보유 골드는 각 캐릭터가 마지막으로 접속했을 때의 금액 기준입니다.
- 날짜는 0시 기준이며, 주간 기록은 목요일 정기 점검을 기준으로 나뉩니다.
- 귀환석은 어느 캐릭터로든 그 여관으로 한 번 귀환석을 탄 뒤부터 동선에 들어갑니다.
  아르칸티나 열쇠도 나오는 여관 위치를 알아야 합니다 (그 여관으로 귀환석을 타거나 열쇠를 한 번 쓰면 기억).
- TomTom과 DBM은 선택 사항입니다. TomTom이 없으면 내비게이션이 게임 기본 웨이포인트를 사용하고,
  DBM이 없으면 완료 소리는 보스 처치 소리로 재생됩니다.

## 출처
- 사용 라이브러리: Ace3
- 특별 과제 퀘스트 ID 표: GoldWQ (Marcus, Public Domain) 경유,
  원출처 WeeklyRewards by cybertk (Copyright (c) 2025 Quanlong, MIT License)
- 귀환석 장난감 아이템 ID: RandomHearth by JamienAU
- 실버문 주간 퀘스트 ID: Apex Ledger by Andrew (MIT License)
