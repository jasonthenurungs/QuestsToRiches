## (next version, number to be decided)

### New
- Navigation (experimental, off by default): Dundun's Abundant Travel Method can be used in the route.
  The addon finds the cave where Abundance is currently active and uses the toy when it makes the route faster.
  With a 30 minute cooldown it can be used up to twice in one route. It is not used in the last 2 minutes before the location ends,
  and the remaining route is re-planned if the location changes during navigation.
  Turn it on under "Use Dundun's Abundant Travel Method in navigation (experimental)" in Settings.
  The author does not own this toy yet, so it has not been tested in game. Please report how it works for you.
- New key binding: "Start Navigation!". One key starts navigation without opening the window and picking a tab,
  the same as the button on the Gold Quests tab. Set it under Key Bindings in Settings (or in the game's Key Bindings, AddOns section).
- New setting "Tell me in chat why a travel method was not used" (off by default). When navigation starts, prints one line for each
  travel method you have and turned on but that was not added (Hearthstone, Astral Recall, Key to the Arcantina, M+ portal, Dundun toy),
  with the reason: no part of the route gets 15 seconds faster, cooldown, the kept Hearthstone charge, and so on.

### Changes
- The "Hearthstone not added" chat line now only appears when the new setting above is on.
- Zul'Aman: quests on the Atal'Aman map are now counted as Zul'Aman. One Zul'Aman special assignment is on this map,
  so after it unlocked, navigation still showed it as "unlocks later" and did not know its location.
- Navigation: a special assignment that is already in your quest log now counts as unlocked, and while an "unlocks later" stop
  is in the route, the addon checks every 10 seconds whether it has opened. Before, it only checked right after each quest.
- Riches tab: characters who did the Liadrin weekly quest last week now show "Done last week" in gray and are not counted.
  Those characters cannot get the quest again this week, so they no longer look like unfinished work.

---

## (다음 버전, 번호는 정해지면) (한국어)

### 새 기능
- 내비게이션 (시험 기능, 기본 끔): 둔둔의 풍요로운 이동 수단을 동선에 넣을 수 있습니다.
  지금 풍요가 열린 동굴을 애드온이 찾아서, 경로가 빨라지는 자리에 장난감을 넣습니다.
  대기시간이 30분이라 한 경로에서 두 번까지 씁니다. 풍요 지점이 끝나기 2분 전부터는 넣지 않고, 안내 중에 지점이 바뀌면 남은 경로를 다시 짭니다.
  설정창 "둔둔의 풍요로운 이동 수단을 동선에 넣기 (시험 기능)"에서 켜 주세요.
  제작자가 아직 장난감이 없어 게임에서 확인하지 못했습니다. 써 보시고 어땠는지 알려 주세요.
- 단축키 "내비게이션 시작!" 추가: 창을 열고 탭을 고를 필요 없이 키 하나로 바로 내비게이션을 시작합니다.
  골드퀘 탭의 버튼을 누른 것과 같습니다. 설정창 단축키 칸(또는 게임 단축키 설정의 애드온 항목)에서 지정해 주세요.
- 설정 "넣지 않은 이유를 채팅창에 알리기" 추가 (기본 끔): 내비게이션을 시작할 때, 가지고 있고 켜 둔 이동 수단
  (귀환석, 영혼의 귀환, 아르칸티나 열쇠, 쐐기 포탈, 둔둔 장난감) 중 동선에 넣지 않은 것을 이유와 함께 한 줄씩 알립니다.
  예: 15초 이상 빨라지는 구간이 없어서, 대기시간 중이라서, 귀환석 1회 남기기 때문에.

### 변경
- "귀환석은 넣지 않았습니다" 채팅 알림은 위 설정을 켰을 때만 나옵니다.
- 줄아만: 아탈아만 지도에 있는 퀘스트도 줄아만으로 셉니다. 특별 과제 "다시 우리의 것으로!"가 이 지도에 있어서,
  해금된 뒤에도 내비게이션에 "해금 예정"으로 남고 위치를 몰랐습니다.
- 내비게이션: 퀘스트 목록에 받아 둔 특별 과제는 열린 것으로 봅니다. 경로에 "해금 예정" 목적지가 남아 있으면 10초마다 열렸는지 확인합니다.
  예전에는 퀘스트를 완료한 직후에만 확인해서, 게임 정보가 늦게 바뀌면 계속 "해금 예정"으로 남았습니다.
- 부자되기 탭: 지난주에 리에드린 주간 퀘스트를 한 캐릭터는 회색 "지난주 완료"로 보이고 개수에서 빠집니다.
  그 캐릭터는 이번 주에 퀘스트를 다시 받을 수 없어서, 안 한 숙제처럼 보이지 않게 했습니다.
