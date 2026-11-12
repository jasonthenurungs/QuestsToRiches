## 1.8.0

### New
- Navigation (experimental, off by default): Haranir Rootwalking can be used in the route. It has no cooldown, so it is used like a portal to the Cradle in Harandar
  whenever that is faster. Where you land is estimated at first; use it once away from the World Tree roots in Harandar
  and the addon learns the real spot. It is not used near the World Tree roots, because there it takes you to another continent.
  Turn it on under "Use Haranir Rootwalking in navigation" in Settings.
- Next character recommendation: sort classes into Preferred, Normal and Avoid boxes in Settings ("Next character recommendation").
  Drag a class to another box to move it; the box under the cursor is outlined in yellow.
  The class preference is checked before the amount of gold left (after narrowing to characters who have not done the gold quest that ends soonest).
  Hover over the recommended character's name to see why it was picked.
- Riches tab: when you expand a Pinnacle Cache line, characters who opened a jackpot cache show a star with "Jackpot"
  (silver star, 3,000 gold or more) or "Mega jackpot" (gold star, 10,000 gold or more). Unopened caches still show "Unopened n" first.

### Fixes
- Riches tab and next character recommendation: gold quests seen only by characters below max level are no longer listed.
  A leveling version of a gold quest (quest ID 92566) seen by a level 84 character showed up as 0/7 and turned hidden on every max-level character.
- Riches tab: the Xal'atath Silvermoon weekly (quest ID 98172) no longer shows characters as done just because the game reports it completed
  (in a week without it, every character that logged in showed "Done"). Only completions seen by the addon count, as with the Liadrin weekly.

---

## 1.8.0 (한국어)

### 새 기능
- 내비게이션 (시험 기능, 기본 끔): 하라니르 종족 기술 뿌리걸음을 동선에 넣습니다. 쿨타임이 없어서 하란다르의 요람으로 가는 포탈처럼, 더 빠를 때마다 씁니다.
  내리는 곳은 처음에는 어림으로 잡고, 하란다르의 세계수 뿌리에서 떨어진 곳에서 한 번 쓰면 실제로 내린 곳을 기억합니다.
  세계수 뿌리 근처에서는 다른 대륙으로 가기 때문에 넣지 않습니다.
  설정창 "하라니르 뿌리걸음을 동선에 넣기"에서 켜야 합니다.
- 다음 추천 캐릭터: 설정창 "다음 추천 캐릭터"에서 직업을 선호, 보통, 비선호 칸으로 나눌 수 있습니다.
  직업을 끌어서 다른 칸에 놓으면 옮겨지고, 끄는 동안 놓일 칸의 테두리가 노랗게 바뀝니다.
  직업 선호는 남은 골드보다 먼저 봅니다 (가장 빨리 끝나는 골드퀘를 아직 안 한 캐릭터로 후보를 좁힌 다음).
  추천된 캐릭터 이름에 마우스를 올리면 추천 이유가 나옵니다.
- 부자되기 탭: 정점 보관함 줄을 펼치면, 보관함을 열어 대박이 나온 캐릭터에 별과 함께 "대박"
  (은별, 3,000골드 이상) 또는 "초대박"(금별, 10,000골드 이상)이 나옵니다. 아직 열지 않은 보관함이 있으면 지금처럼 "미개봉 n"이 먼저 나옵니다.

### 수정
- 부자되기 탭과 다음 추천: 만렙이 아닌 캐릭터만 본 골드퀘는 더 이상 나오지 않습니다.
  84레벨 캐릭터가 본 레벨업용 "어둠의 군대"가 0/7로 나오고, 만렙 캐릭터로 접속할 때마다 "안 보임"으로 바뀌었습니다.
- 부자되기 탭: 잘아타스 추적을 게임이 완료로 알려 준다는 이유만으로 "완료"로 표시하지 않습니다
  (이 퀘스트가 없는 주에 접속한 캐릭터마다 "완료"가 되었습니다). 리에드린 주간처럼 애드온이 직접 본 완료만 셉니다.
