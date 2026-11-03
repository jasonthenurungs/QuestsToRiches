import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
base = TD + ''
addon, out = lua.execute(open(base + 'harness2.lua', encoding='utf-8').read())
lua.execute('''
CHARNAME = "봄이간다"
NOWT = 1000
function GetTime() return NOWT end
Enum = { QuestTagType = { Capstone = 99 } }
NAMES = { [2395] = "영원노래 숲", [2437] = "줄아만", [2405] = "공허폭풍", [2413] = "하란다르", [2512] = "똬리의 섬" }
C_Map = { GetMapInfo = function(id) return { name = NAMES[id] or "실버문" } end, GetBestMapForUnit = function() return 9999 end }
Q = {
  [1] = { map = 2405, title = "퀘 A", money = 10000000, t = 3600 - 100, x = 0.2, y = 0.2 },
  [2] = { map = 2405, title = "퀘 B", money = 9840000, t = 3*86400, x = 0.9, y = 0.9 },
  [3] = { map = 2413, title = "퀘 C", money = 10460000, t = 86400, x = 0.25, y = 0.3 },
  [5] = { map = 2444, title = "특별 과제: 수요와 공급", money = 0, t = nil, capstone = true, reward = 279520 },
}
C_TaskQuest = {
  GetQuestsOnMap = function(mapID)
    local r = {}
    for id, q in pairs(Q) do table.insert(r, { questID = id, mapID = q.map, x = q.x, y = q.y }) end
    table.sort(r, function(a,b) return a.questID < b.questID end)
    return r
  end,
  GetQuestInfoByQuestID = function(id) return Q[id] and Q[id].title end,
  GetQuestTimeLeftSeconds = function(id) return Q[id] and Q[id].t end,
  GetQuestZoneID = function() return 2405 end,
}
function GetQuestLogRewardMoney(id) return Q[id] and Q[id].money or 0 end
function GetNumQuestLogRewards(id) return (Q[id] and Q[id].reward) and 1 or 0 end
function GetQuestLogRewardInfo(i, id) return "x", 1, 1, 4, true, Q[id].reward, 1 end
DONEFLAG = {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return DONEFLAG[id] or false end
C_QuestLog.GetQuestTagInfo = function(id) if Q[id] and Q[id].capstone then return { worldQuestType = 99 } end return {} end
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
CACHEITEMS = { [282183] = "실버문 정점 보관함", [888666] = "승리의 스토마리온 정점 보관함" }
C_TooltipInfo = { GetItemByID = function(id)
  if CACHEITEMS[id] then return { lines = { { leftText = CACHEITEMS[id] }, { leftText = "정점 보관함 - 한밤 2 시즌" } } } end
  return { lines = { { leftText = "잡템" .. id }, { leftText = "판매 가격" } } }
end }
BAG = { [0] = { [1] = 12345 } }
C_Container = { UseContainerItem = function() end,
  GetContainerNumSlots = function(b) return b == 0 and 6 or 0 end,
  GetContainerItemID = function(b, s) return BAG[b] and BAG[b][s] end }
C_Item = { GetItemCount = function(id) local n = 0 for _, b in pairs(BAG) do for _, v in pairs(b) do if v == id then n = n + 1 end end end return n end,
           GetItemIconByID = function(id) return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function(id) return CACHEITEMS[id] end, RequestLoadItemDataByID = function() end }
HOOKS = {}
function hooksecurefunc(t, name, fn) HOOKS[name] = fn end
C_EventUtils = { IsEventValid = function() return false end }
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
MerchantFrame = { IsShown = function() return false end }
QID = 0; QTITLE = ""; QREWARD = nil
function GetQuestID() return QID end
function GetTitleText() return QTITLE end
function GetNumQuestRewards() return QREWARD and 1 or 0 end
function GetQuestItemLink(kind, i) return QREWARD and ("|cffa335ee|Hitem:" .. QREWARD .. "::::|h[x]|h|r") end
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval('''function(QTR, out)
  local now = time()
  QuestsToRichesDB = {
    chars = {
      ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
      ["여름이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90, cacheBag = { [282183] = 1 } },
      ["저렙이-데스윙"] = { money = 1, class = "WARRIOR", level = 40 },
      ["가방-아즈샤라"] = { money = 1, class = "MAGE", level = 90, realm = "아즈샤라" },
      ["나무-아즈샤라"] = { money = 1, class = "WARRIOR", level = 90, realm = "아즈샤라" },
      ["다리-아즈샤라"] = { money = 1, class = "MAGE", level = 90, realm = "아즈샤라" },
      ["완료빠름-아즈샤라"] = { money = 1, class = "MAGE", level = 90, realm = "아즈샤라" },
      ["가람-불타는군단"] = { money = 1, class = "MAGE", level = 90, realm = "불타는군단" },
    },
    days = {}, turnIns = { ["여름이간다-데스윙"] = { [1] = now - 1000, [2] = now - 10 * 86400 }, ["완료빠름-아즈샤라"] = { [1] = now - 5000 } },
    settings = { tab = "dash" },
  }
  QuestsToRichesDB.activeGQ = { [77] = { name = "뜻밖의 상황", zone = "공허폭풍", mapID = 2405, money = 10890000, expire = now + 40000, seenBy = { ["여름이간다-데스윙"] = now - 100 } } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  -- HIDDENTEST
  local h = QuestsToRichesDB.activeGQ[77].hiddenFor
  print("hidden for me:", h and h["봄이간다-데스윙"])
  local n = 0 for k in pairs(QuestsToRichesDB.activeGQ) do n = n + 1 end
  print("activeGQ:", n)
  for k, s in pairs(QuestsToRichesDB.cacheSources) do print("source:", k, s.title, s.zone, s.itemID, s.via) end

  print("== NPC dialog")
  QID = 900; QTITLE = "실버문 주간: 수호"; QREWARD = 282183
  QTR:QUEST_DETAIL()
  print("== turn in 900 and cache arrives")
  NOWT = 2000
  QTR:QUEST_TURNED_IN("x", 900, 0, 0)
  BAG[0][2] = 282183
  NOWT = 2003
  QTR:BAG_UPDATE_DELAYED()
  print("== stormarion cache with no quest")
  NOWT = 3000
  BAG[0][3] = 888666
  QTR:BAG_UPDATE_DELAYED()
  local g = QuestsToRichesDB.cacheGets["봄이간다-데스윙"]
  for _, x in ipairs(g) do print("get:", x.id, x.n, x.q) end
  for k, s in pairs(QuestsToRichesDB.cacheSources) do print("source:", k, s.kind, s.title, s.itemID, s.via) end
  print("== bank withdraw should not count")
  BankFrame = { IsShown = function() return true end }
  BAG[0][4] = 888666
  QTR:BAG_UPDATE_DELAYED()
  BankFrame = nil
  print("gets now:", #QuestsToRichesDB.cacheGets["봄이간다-데스윙"])

  local function dump(title)
    print("==== " .. title)
    for _, fs in ipairs(out) do fs._text = "" end
    QTR:Refresh()
    for _, fs in ipairs(out) do if type(fs._text) == "string" and fs._text ~= "" and not fs._text:find("단축") and not fs._text:find("D%-") and not fs._text:find("하루 평균") and not fs._text:find("계정 총") and not fs._text:find("캐릭터 합계") and not fs._text:find("목표") and not fs._text:find("/ 5,000,000") then print(fs._text) end end
  end
  QuestsToRiches_ToggleDashboard()
  dump("rich collapsed")
  -- 누를 수 있는 줄 찾기 (RenderList가 만든 버튼)
  local clicks = {}
  for _, fr in ipairs(ALLFRAMES) do if rawget(fr, "_scr_OnClick") and rawget(fr, "_text") == nil and rawget(fr, "_name") == "Button" and not (rawget(fr, "_x") == -2 and rawget(fr, "_y") == 0) and rawget(fr, "_pf") ~= QuestsToRichesTravelAlert and rawget(fr, "_w") ~= 20 then table.insert(clicks, fr) end end
  print("clickable rows:", #clicks)
  rawget(clicks[1], "_scr_OnClick")(clicks[1])
  rawget(clicks[4], "_scr_OnClick")(clicks[4])
  dump("rich expanded first gq and first source")
  -- 정렬 확인: 퀘 A 펼치기 (rich.expanded는 줄 클릭으로만) -> 클릭 버튼 중 퀘 A 줄 찾기 어려우니 모두 접고 하나씩
  LOCALIZED_CLASS_NAMES_MALE = { MAGE = "마법사", WARRIOR = "전사" }
  print("== ban quest 1 via link")
  SlashCmdList["QUESTSTORICHES"]("ban |cffffff00|Hquest:1:90|h[퀘 A]|h|r")
  SlashCmdList["QUESTSTORICHES"]("ban")
  dump("rich after ban")
  print("==== ordered rows")
  local cells = {}
  for _, fs in ipairs(out) do if fs._shown and type(fs._text) == "string" and fs._text ~= "" and rawget(fs, "_y") and rawget(fs, "_y") <= 0 and rawget(fs, "_x") and rawget(fs, "_x") < 400 then table.insert(cells, fs) end end
  table.sort(cells, function(a, b) if a._y ~= b._y then return a._y > b._y end return a._x < b._x end)
  local line, lasty = {}, nil
  for _, fs in ipairs(cells) do
    if lasty and fs._y ~= lasty then print(table.concat(line, " | ")); line = {} end
    lasty = fs._y; table.insert(line, (fs._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
  end
  print(table.concat(line, " | "))
  QuestsToRichesDB.settings.hideBanned = false
  dump("rich ban off")
  for _, fr in ipairs(ALLFRAMES) do if rawget(fr, "_scr_OnClick") and rawget(fr, "_name") == "Button" and rawget(fr, "_y") == -16 then rawget(fr, "_scr_OnClick")(fr) break end end
  local cells = {}
  for _, fs in ipairs(out) do if fs._shown and type(fs._text) == "string" and fs._text ~= "" and rawget(fs, "_y") and rawget(fs, "_y") <= 0 and rawget(fs, "_x") and rawget(fs, "_x") < 400 then table.insert(cells, fs) end end
  table.sort(cells, function(a, b) if a._y ~= b._y then return a._y > b._y end return a._x < b._x end)
  local line, lasty = {}, nil
  print("==== quest A expanded")
  for _, fs in ipairs(cells) do
    if lasty and fs._y ~= lasty then print(table.concat(line, " | ")); line = {} end
    lasty = fs._y; table.insert(line, (fs._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
  end
  print(table.concat(line, " | "))
  SlashCmdList["QUESTSTORICHES"]("unban 1")
  SlashCmdList["QUESTSTORICHES"]("gq")
  dump("gq tab")
  -- TIPTEST
  local TIP = {}
  GameTooltip = { SetOwner = function(self, o) TIP.owner = o end, SetHyperlink = function(self, l) TIP.link = l end,
    SetText = function(self, t) TIP.text = t end, Show = function() TIP.shown = true end, Hide = function() TIP.shown = false end,
    IsShown = function() return TIP.shown end, GetOwner = function() return TIP.owner end, SetItemByID = function(self, id) TIP.item = id end, AddLine = function(self, t) TIP.lines = (TIP.lines or "") .. "|" .. t end, AddDoubleLine = function(self, l, r) TIP.lines = (TIP.lines or "") .. "|" .. tostring(l) .. "=" .. tostring(r) end }
  local n = 0
  for _, fr in ipairs(ALLFRAMES) do
    local onEnter = rawget(fr, "_scr_OnEnter")
    if onEnter and rawget(fr, "tipQuest") then onEnter(fr); n = n + 1; print("tip:", rawget(fr, "tipQuest"), TIP.link, TIP.shown, TIP.lines) ; if n >= 2 then break end end
  end
  for _, fr in ipairs(ALLFRAMES) do
    local onEnter = rawget(fr, "_scr_OnEnter")
    if onEnter and rawget(fr, "tipItem") then onEnter(fr); print("item tip:", TIP.item, TIP.shown); break end
  end
end''')(addon, out)

lua.eval("""function(out, QTR)
  local F = QuestsToRichesFrame
  -- 지도 핀 / 슈퍼트랙 / 월드 좌표 흉내
  PIN = nil; SUPER = false
  UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
  C_Map.CanSetUserWaypointOnMap = function() return true end
  C_Map.SetUserWaypoint = function(p) PIN = p end
  C_Map.GetUserWaypoint = function() return PIN end
  C_Map.ClearUserWaypoint = function() PIN = nil end
  C_Map.HasUserWaypoint = function() return PIN ~= nil end
  C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) SUPER = v end }
  function CreateVector2D(x, y) return { x = x, y = y } end
  C_Map.GetWorldPosFromMapPos = function(m, v) return 1, { x = v.x * 1000 + (m == 2413 and 0 or 0), y = v.y * 1000 } end
  C_Map.GetPlayerMapPosition = function() return { x = 0.1, y = 0.1 } end
  C_Map.GetBestMapForUnit = function() return 2405 end
  local function pinStr() return PIN and (PIN.uiMapID .. " " .. PIN.position.x .. "," .. PIN.position.y) or "nil" end

  -- 1) 특별 과제 표: NPC로만 배운 빛을 몰아내라(93013), 잠김 상태용 퀘스트(94391)에 남은 시간
  QuestsToRichesDB.cacheSources["q93013"] = { kind = "quest", questID = 93013, title = "특별 과제: 빛을 몰아내라",
    zone = "하란다르", itemID = 279520, via = "npc", learned = time() - 9 * 86400, lastSeen = time() - 9 * 86400 }
  local orig = C_TaskQuest.GetQuestTimeLeftSeconds
  C_TaskQuest.GetQuestTimeLeftSeconds = function(id) if id == 94391 then return 5 * 86400 + 20 * 3600 end return orig(id) end
  local function texts(cmd)
    for _, fs in ipairs(out) do fs._text = nil end
    SlashCmdList["QUESTSTORICHES"](cmd)
    local r = {}
    for _, fs in ipairs(out) do if type(fs._text) == "string" and fs._shown ~= false then table.insert(r, fs._text) end end
    return table.concat(r, " | ")
  end
  local t = texts("rich")
  local seg = t:match("(빛을 몰아내라[^|]*|r | [^|]*|c%x%x%x%x%x%x%x%x[^|]*)") or t:match("빛을 몰아내라.-m|r") or "(none)"
  print("1) rich SA row:", seg)
  print("   onMap:", QuestsToRichesDB.cacheSources["q93013"].onMap, " expire-now(h):", math.floor((QuestsToRichesDB.cacheSources["q93013"].expire - time()) / 3600))

  -- 2) 골드퀘 탭 줄 클릭 -> 웨이포인트
  for _, f in ipairs(ALLFRAMES) do rawset(f, "leftFn", nil) end
  texts("gq")
  local clicked
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "tipQuest") == 1 and fr._shown and rawget(fr, "leftFn") then
      rawget(fr, "_scr_OnClick")(fr, "LeftButton"); clicked = true; break
    end
  end
  print("2) gq click:", clicked, " pin:", pinStr(), " super:", SUPER)
  QTR:QUEST_TURNED_IN("x", 1, 0, 10000000)
  print("   after turn-in of quest 1, pin:", pinStr())

  -- 3) 부자되기 탭 오른쪽 클릭 -> 웨이포인트, 왼쪽 클릭은 펼치기
  texts("rich")
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "tipQuest") == 3 and fr._shown and rawget(fr, "rightFn") then
      rawget(fr, "_scr_OnClick")(fr, "RightButton"); break
    end
  end
  print("3) rich right-click pin:", pinStr())

  -- 4) 경로 안내 (TomTom 있음)
  ADDED, REMOVED, ARROW = {}, {}, nil
  TomTom = { AddWaypoint = function(self, m, x, y, o) table.insert(ADDED, o.title .. "@" .. m .. ":" .. x .. "," .. y); return #ADDED end,
             RemoveWaypoint = function(self, uid) table.insert(REMOVED, uid) end,
             SetCrazyArrow = function(self, uid, d, title) ARROW = title end }
  Q[1] = { map = 2405, title = "퀘 A", money = 10000000, t = 3000, x = 0.2, y = 0.2 }
  DONEFLAG[1] = nil
  QTR.forceScan = true
  QTR.RouteStart()
  print("4) TomTom added:", table.concat(ADDED, " / "))
  print("   arrow:", ARROW)
  QTR:QUEST_TURNED_IN("x", ADDED[1] and 1 or 0, 0, 10000000)
  print("   after turn-in: removed uids", table.concat(REMOVED, ","), " arrow:", ARROW)
  QTR.RouteClear()
  print("   after clear: removed uids", table.concat(REMOVED, ","), " route:", QTR.route)

  -- 5) TomTom 없음: 게임 웨이포인트로 한 곳씩
  TomTom = nil; PIN = nil
  QTR.forceScan = true
  QTR.RouteStart()
  print("5) no TomTom first pin:", pinStr())
end""")(out, addon)
lua.eval("""function(QTR)
  PIN = nil
  QTR.SetWaypoint(3, "퀘 C", { 2413, 0.25, 0.3 })
  PIN = { uiMapID = 2395, position = { x = 0.5, y = 0.5 } } -- 사용자가 다른 곳에 직접 핀을 찍음
  QTR:QUEST_TURNED_IN("x", 3, 0, 10460000)
  print("6) user's own pin kept:", PIN and PIN.uiMapID)
end""")(addon)
lua.eval("""function(out, QTR)
  local function texts(cmd)
    for _, fs in ipairs(out) do fs._text = nil end
    QTR.forceScan = true
    SlashCmdList["QUESTSTORICHES"](cmd)
    local r = {}
    for _, fs in ipairs(out) do if type(fs._text) == "string" and fs._shown ~= false then table.insert(r, fs._text) end end
    return (table.concat(r, " | "):gsub("|TInterface[^|]*|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  end
  C_PvP = { IsWarModeDesired = function() return false end, GetWarModeRewardBonus = function() return 10 end }
  C_QuestLog.QuestCanHaveWarModeBonus = function(id) return id ~= 2 end -- 퀘 B는 보너스 대상 아님
  local off = texts("gq")
  print("7) war off:", off:match("수행 가능한 골드퀘[^|]*"), "|", off:match("기준[^|]*"))
  print("   rows:", off:match("퀘 A | [^|]* | [^|]*"), "/", off:match("퀘 B | [^|]* | [^|]*"))
  C_PvP.IsWarModeDesired = function() return true end
  QTR:PLAYER_FLAGS_CHANGED("x", "player")
  local on = texts("gq")
  print("   war on:", on:match("수행 가능한 골드퀘[^|]*"), "|", on:match("기준[^|]*"))
  print("   rows:", on:match("퀘 A | [^|]* | [^|]*"), "/", on:match("퀘 B | [^|]* | [^|]*"))
  print("   activeGQ base money q1:", QuestsToRichesDB.activeGQ[1] and QuestsToRichesDB.activeGQ[1].money)
end""")(out, addon)
lua.eval("""function(out)
  for _, fs in ipairs(out) do
    local t = fs._text
    if type(t) == "string" and (t:find("수행 가능한 골드퀘", 1, true) or t:find("기준, 남은 시간", 1, true)) then
      print("8)", (t:gsub("|TInterface[^|]*|t", "G"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    end
  end
end""")(out)
lua.eval("""function(out, QTR)
  local function texts(cmd)
    for _, fs in ipairs(out) do fs._text = nil end
    QTR.forceScan = true
    SlashCmdList["QUESTSTORICHES"](cmd)
  end
  -- 9) TomTom이 있을 때 1번 탭 클릭: TomTom 웨이포인트 + 지역 이름
  ADDED, REMOVED, ARROW = {}, {}, nil
  TomTom = { AddWaypoint = function(self, m, x, y, o) table.insert(ADDED, o.title .. "@" .. m); return 100 + #ADDED end,
             RemoveWaypoint = function(self, uid) table.insert(REMOVED, uid) end,
             SetCrazyArrow = function(self, uid, d, title) ARROW = title end }
  PIN = nil
  -- 앞 단계의 내비게이션이 남아 있으면 클릭이 막히므로(2026-10-27부터, run66) 경로를 지우고 본다
  if QTR.RouteClear then QTR.RouteClear(true) end
  Q[1] = { map = 2405, title = "퀘 A", money = 10000000, t = 3000, x = 0.2, y = 0.2 }
  for _, f in ipairs(ALLFRAMES) do rawset(f, "leftFn", nil) end
  texts("gq")
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "tipQuest") == 1 and fr._shown and rawget(fr, "leftFn") then
      rawget(fr, "_scr_OnClick")(fr, "LeftButton"); break
    end
  end
  print("9) TomTom click:", table.concat(ADDED, " / "), " arrow:", ARROW, " blizzard pin:", PIN)
  -- 우클릭은 아무 일 없음
  local before = #ADDED
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "tipQuest") == 1 and fr._shown and rawget(fr, "leftFn") then
      rawget(fr, "_scr_OnClick")(fr, "RightButton"); break
    end
  end
  print("   right-click adds:", #ADDED - before)
  QTR:QUEST_TURNED_IN("x", 1, 0, 10000000)
  print("   after turn-in removed:", table.concat(REMOVED, ","))
  -- 10) 부자되기 탭: 오른쪽 클릭 웨이포인트 없음
  texts("rich")
  local rf = 0
  for _, fr in ipairs(ALLFRAMES) do if fr._shown and rawget(fr, "rightFn") then rf = rf + 1 end end
  print("10) rich rows with right-click action:", rf)
  -- 11) 경로 안내 문구에 지역 이름
  ADDED = {}
  Q[1] = { map = 2405, title = "퀘 A", money = 10000000, t = 3000, x = 0.2, y = 0.2 }
  QTR.forceScan = true
  QTR.RouteStart()
  print("11) route:", table.concat(ADDED, " / "))
end""")(out, addon)
