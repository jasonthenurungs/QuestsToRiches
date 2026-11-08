## 1.7.0

### New
- Navigation (experimental, off by default): Dundun's Abundant Travel Method can be used in the route.
  The addon finds the cave where Abundance is currently active and uses the toy when it makes the route faster.
  With a 30 minute cooldown it can be used up to twice in one route. It is not used in the last 2 minutes before the location ends,
  and the remaining route is re-planned if the location changes during navigation.
  Turn it on under "Use Dundun's Abundant Travel Method in navigation (experimental)" in Settings.
  The author does not own this toy yet, so it has not been tested in game. Please report how it works for you.
- Navigation (off by default): Delve-O-Bot 7001 can take you to the Labyrinth of Kindo'jan entrance (southern Eversong Woods)
  as part of the route. Requires the Labyrinth update chip; talk to the bot once on any character and the addon remembers it for the whole account.
  On that step, talking to the bot picks the Labyrinth automatically (hold Shift to choose yourself). Cooldown 1 hour.
  Turn it on under "Use Delve-O-Bot 7001 to the Labyrinth of Kindo'jan in navigation" in Settings.
- New key binding: "Start Navigation!". One key starts navigation without opening the window and picking a tab,
  the same as the button on the Gold Quests tab. Set it under Key Bindings in Settings (or in the game's Key Bindings, AddOns section).
- New setting "Tell me in chat which travel methods were used, and why not" (off by default). When navigation starts, prints one line
  for each travel method you have and turned on (Hearthstone, Astral Recall, Key to the Arcantina, M+ portal, Dundun toy):
  where it is used and how much time it saves, or why it was not added (no part of the route gets 15 seconds faster, cooldown,
  the kept Hearthstone charge, and so on).

### Changes
- Navigation: when two travel methods save almost the same time for the same part of the route (within 30 seconds),
  the one with the shorter cooldown is used. For example, Delve-O-Bot (1 hour) is used instead of the M+ portal to Maisara Caverns (8 hours)
  when the portal would be only about 15 seconds faster, so the M+ portals stay available.
- Navigation: the M+ portal to Maisara Caverns is now added only when it makes part of the route 45 seconds or more faster
  (15 seconds for the other travel methods). It was sometimes used inside Zul'Aman to save about 15 seconds, which is not worth an 8-hour cooldown.
- The "Loaded" chat message now shows the addon version, e.g. "Loaded (v1.7.0)".
- The "Added ... to the route" and "Hearthstone not added" chat lines now only appear when the new setting above is on,
  so the chat stays quieter by default.
- Isle of Quel'Danas: a gold quest was left out of the lists and navigation because it is on a smaller map inside the island
  (quest ID 96329, map ID 2642). Quests on any map inside a gold-quest zone now count for that zone.
- Zul'Aman: quests on the Atal'Aman map are now counted as Zul'Aman. One Zul'Aman special assignment is on this map,
  so after it unlocked, navigation still showed it as "unlocks later" and did not know its location.
- Navigation: a special assignment that is already in your quest log now counts as unlocked, and while an "unlocks later" stop
  is in the route, the addon checks every 10 seconds whether it has opened. Before, it only checked right after each quest.
- Riches tab: characters who did the Liadrin weekly quest last week now show "Done last week" in gray and are not counted.
  Those characters cannot get the quest again this week, so they no longer look like unfinished work.
- Navigation window: the summary shown when every stop is done now moves to a second line when it is too long for the window,
  instead of running past its edge. The travel ability use window also widens to fit long text.

---

## 1.7.0 (한국어)

### 새 기능
- 내비게이션 (시험 기능, 기본 끔): 둔둔의 풍요로운 이동 수단을 동선에 넣을 수 있습니다.
  지금 풍요가 열린 동굴을 애드온이 찾아서, 경로가 빨라지는 자리에 장난감을 넣습니다.
  쿨타임이 30분이라 한 경로에서 두 번까지 씁니다. 풍요 지점이 끝나기 2분 전부터는 넣지 않고, 안내 중에 지점이 바뀌면 남은 경로를 다시 짭니다.
  설정창 "둔둔의 풍요로운 이동 수단을 동선에 넣기 (시험 기능)"에서 켜 주세요.
  제작자가 아직 장난감이 없어 게임에서 확인하지 못했습니다. 써 보시고 어땠는지 알려 주세요.
- 내비게이션 (기본 끔): 구렁로봇 7001로 킨도잔의 미궁 입구(영원노래 숲 남쪽)에 가는 것을 동선에 넣을 수 있습니다.
  미궁 업데이트 칩이 있어야 하고, 아무 캐릭터로나 로봇에게 한 번 말을 걸면 계정 전체에 칩이 있다고 기억합니다.
  그 차례에 로봇에게 말을 걸면 미궁을 자동으로 고릅니다 (Shift를 누르고 말을 걸면 직접 고를 수 있습니다). 쿨타임은 1시간입니다.
  설정창 "구렁로봇 7001로 킨도잔의 미궁 가기를 동선에 넣기"에서 켜 주세요.
- 단축키 "내비게이션 시작!" 추가: 창을 열고 탭을 고를 필요 없이 키 하나로 바로 내비게이션을 시작합니다.
  골드퀘 탭의 버튼을 누른 것과 같습니다. 설정창 단축키 칸(또는 게임 단축키 설정의 애드온 항목)에서 지정해 주세요.
- 설정 "이동 수단을 넣었는지와 그 이유를 채팅창에 알리기" 추가 (기본 끔): 내비게이션을 시작할 때, 가지고 있고 켜 둔 이동 수단
  (귀환석, 영혼의 귀환, 아르칸티나 열쇠, 쐐기 포탈, 둔둔 장난감)마다 한 줄씩 알립니다.
  넣었으면 어디서 쓰는지와 줄어드는 시간을, 넣지 않았으면 그 이유를 알립니다 (15초 이상 빨라지는 구간이 없어서, 쿨타임 중이라서, 귀환석 1회 남기기 때문에 등).

### 변경
- 내비게이션: 같은 구간에서 두 이동 수단으로 줄어드는 시간이 비슷하면 (30초 안), 쿨타임이 짧은 쪽을 씁니다.
  예를 들어 쐐기 포탈(마이사라 동굴, 8시간)이 구렁로봇(1시간)보다 15초쯤만 빠르면 구렁로봇을 넣어서, 쐐기 포탈을 아껴 둡니다.
- 내비게이션: 쐐기 포탈(마이사라 동굴)은 45초 이상 빨라지는 구간이 있을 때만 넣습니다 (다른 이동 수단은 15초).
  줄아만 안에서 15초쯤 줄이려고 8시간 쿨타임을 쓰는 경우가 있었습니다.
- 접속할 때 나오는 "로드 완료" 채팅 메시지에 애드온 버전을 함께 보여 줍니다 (예: "로드 완료 (v1.7.0)").
- "동선에 넣었습니다", "귀환석은 넣지 않았습니다" 채팅 알림은 위 설정을 켰을 때만 나옵니다. 기본으로는 채팅창이 조용해집니다.
- 똬리의 섬: 골드퀘 "사술과 거짓"이 섬 안의 작은 지도(방황하는 사제의 무덤)에 있어서 목록과 내비게이션에서 빠졌습니다.
  이제 골드퀘 지역 안의 어느 지도에 있는 퀘스트든 그 지역 퀘스트로 셉니다.
- 줄아만: 아탈아만 지도에 있는 퀘스트도 줄아만으로 셉니다. 특별 과제 "다시 우리의 것으로!"가 이 지도에 있어서,
  해금된 뒤에도 내비게이션에 "해금 예정"으로 남고 위치를 몰랐습니다.
- 내비게이션: 퀘스트 목록에 받아 둔 특별 과제는 열린 것으로 봅니다. 경로에 "해금 예정" 목적지가 남아 있으면 10초마다 열렸는지 확인합니다.
  예전에는 퀘스트를 완료한 직후에만 확인해서, 게임 정보가 늦게 바뀌면 계속 "해금 예정"으로 남았습니다.
- 부자되기 탭: 지난주에 리에드린 주간 퀘스트를 한 캐릭터는 회색 "지난주 완료"로 보이고 개수에서 빠집니다.
  그 캐릭터는 이번 주에 퀘스트를 다시 받을 수 없어서, 안 한 숙제처럼 보이지 않게 했습니다.
- 내비게이션 창: 모두 마쳤을 때 나오는 결과 줄이 창보다 길면 둘째 줄로 넘깁니다 (창 밖으로 넘치던 문제).
  이동 기술 사용 창도 글이 길면 그만큼 넓어집니다.
