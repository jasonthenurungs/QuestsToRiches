## 1.3.0

### New
- Hearthstone in navigation
  - When a hearthstone saves 15 seconds or more, navigation inserts it once at the best point of the route
    ("Hearthstone: <inn>" line in the navigation window, with the time saved in chat).
  - Hearthstone toys that share the hearthstone cooldown work too.
  - The inn location is learned the first time you hearth there, and it is shared by every character
    that uses the same inn.
  - Cooldown reflects the guild perk (Hasty Hearth) and the Human racial (feedback welcome).
  - Option: keep one hearthstone charge for when you finish (on by default).
  - If no hearthstone is added, a single chat line tells you why. /qtr hearth shows the current status.
- Next character to play
  - Shown on the Riches tab and on the navigation finish screen.
  - Picks among characters who have not done the gold quest that expires soonest,
    then the one with the most gold left, preferring the same realm when the gold is close.
- Right-click menu on navigation quest lines: do this first, do this last, skip this time only,
  never show this quest again. A skipped quest can be put back with a right-click.
- Expiring quests
  - Quests that expire during navigation are removed and the rest of the route is re-planned.
  - Quests with less than 30 minutes left are shown in orange with the time left.
  - Quests that would expire before you arrive are moved earlier in the route.
- Special assignment unlocks are planned into the route: the locked assignment is visited
  after the gold quests in its zone that unlock it.
- Navigation window can fade when the mouse is not over it (option and opacity slider).
- Shortcuts for the buttons on each tab while the mouse is over the window
  (Gold Quests: R start navigation / Earnings: Q W E R views, T current, comma and period previous and next /
  Holdings: Q W views, T today, comma and period previous and next). The mouse wheel also moves to the
  previous or next period.
- Holdings tab (detail): daily rank change for each character.
- "Back to Dashboard" button on the navigation finish screen.

### Changes
- Apex Caches: only the two special assignment caches are tracked now.
  The bottom section of the Gold Quests and Riches tabs is now called "Special Assignments".
  Automatic cache detection, manual registration, /qtr cache and /qtr cachecheck were removed.
- Travel time estimates are calibrated from real navigation logs (flight speed and portal time).
- Skipped and expired stops are marked with icons, so the right column shows only gold.
- Settings reorganized. Keybindings now show the name and the key on one row, like the game's keybinding window.
- Excluded quests are always left out of navigation, and they are listed as "Quest (Zone)".

### Fixes
- Navigation could end right after crossing to another continent by teleport (map data was still loading).
- Quest tooltips showed the progress percent twice.
- Some completed quests were recorded with a sub-zone name instead of the gold quest zone.
  Existing records are corrected automatically.
- Completing a quest you had skipped is now counted in the navigation summary.

---

## 1.3.0 (한국어)

### 새 기능
- 내비게이션에 귀환석
  - 귀환석을 쓰면 15초 이상 빨라지는 구간이 있으면 동선에서 가장 좋은 자리에 한 번 넣습니다
    (내비게이션 창의 "귀환석: 여관 이름" 줄, 채팅에 줄어드는 시간 안내).
  - 귀환석과 대기시간을 같이 쓰는 귀환석 장난감도 됩니다.
  - 여관 위치는 그 여관으로 처음 귀환석을 탈 때 기억하고, 같은 여관을 쓰는 모든 캐릭터에 함께 적용됩니다.
  - 대기시간에 길드 혜택(빠른 귀환)과 인간 종족 특성을 반영합니다 (인간 캐릭터 제보 환영).
  - 설정: 내비게이션을 마칠 때 귀환석 1회 남기기 (기본 켬)
  - 귀환석을 넣지 않았으면 이유를 채팅에 한 줄로 알려 줍니다. /qtr hearth로 지금 상태를 볼 수 있습니다.
- 다음 접속 추천 캐릭터
  - 부자되기 탭과 내비게이션 완료 화면에 표시합니다.
  - 가장 빨리 끝나는 골드퀘를 안 한 캐릭터 중에서 남은 골드가 가장 많은 캐릭터를 고르고,
    골드가 비슷하면 같은 서버의 캐릭터를 먼저 추천합니다.
- 내비게이션 퀘스트 줄 우클릭 메뉴: 가장 먼저 하기, 마지막에 하기, 이번만 빼기, 더 이상 안 하기.
  이번만 뺀 퀘스트는 우클릭으로 다시 경로에 넣을 수 있습니다.
- 만료되는 퀘스트
  - 내비게이션 중 만료된 퀘스트는 빼고 남은 경로를 다시 짭니다.
  - 남은 시간이 30분 미만인 퀘스트는 주황색과 남은 시간으로 표시합니다.
  - 도착 전에 끝날 것 같은 퀘스트는 동선 앞쪽으로 당깁니다.
- 특별 과제 해금을 고려한 동선: 잠긴 특별 과제를 그 지역 골드퀘를 마친 뒤에 가도록 편성합니다.
- 마우스를 올리지 않았을 때 내비게이션 창을 흐리게 (설정, 불투명도 슬라이더)
- 창 위에 마우스를 올리고 탭 버튼 단축키
  (골드퀘: R 내비게이션 시작 / 획득량: Q W E R 보기, T 현재, 쉼표 마침표 이전 다음 /
  보유량: Q W 보기, T 오늘, 쉼표 마침표 이전 다음). 마우스 휠로도 이전, 다음으로 넘어갑니다.
- 보유량 탭 상세: 캐릭터별 전일 대비 순위 등락
- 내비게이션 완료 화면에 "대시보드로 돌아가기" 버튼

### 변경
- 정점 보관함은 이제 특별 과제 보상 2종만 추적합니다.
  골드퀘, 부자되기 탭 아래쪽 묶음 이름을 "특별 과제"로 바꿨습니다.
  정점 보관함 자동 인식, 직접 등록, /qtr cache, /qtr cachecheck는 없앴습니다.
- 이동 시간 어림값을 실제 내비게이션 기록으로 보정했습니다 (비행 속도, 포탈 시간).
- 건너뛴 곳과 만료된 곳은 아이콘으로 표시해 맨 오른쪽 칸에는 골드만 나옵니다.
- 설정창 정리. 단축키는 게임 기본 단축키 설정창처럼 항목명과 키를 한 줄에 표시합니다.
- 추적 제외 퀘스트는 항상 내비게이션에서 빼고, "퀘스트명 (지역명)"으로 표시합니다.

### 수정
- 순간이동으로 다른 대륙에 가면 내비게이션이 바로 끝나 버리던 문제 (지도 정보를 불러오는 중이었음)
- 퀘스트 툴팁에 진행도 퍼센트가 두 번 나오던 문제
- 일부 완료 기록이 골드퀘 지역 대신 하위 지역 이름으로 남던 문제 (기존 기록도 자동으로 바로잡음)
- 이번만 뺀 퀘스트를 결국 완료하면 내비게이션 결과에 넣지 않던 문제
