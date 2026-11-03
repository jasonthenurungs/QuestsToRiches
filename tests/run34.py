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
  function CreateVector2D(x, y) return { x = x, y = y } end
  -- 지도 -> 월드 좌표 (실버문, 공허폭풍, 소굴은 측정값에 맞춘 근사, 나머지는 가상의 일관된 값)
  local CONV = {
    [2393] = { c = 0,    f = function(x, y) return 8527.6 - 1875 * (y - 0.665628), -4327.1 - 2806 * (x - 0.35338) end },
    [2395] = { c = 0,    f = function(x, y) return 9500 - 4000 * y, -3000 - 5000 * x end },
    [2437] = { c = 0,    f = function(x, y) return 7000 - 4000 * y, -7000 - 5000 * x end },
    [2512] = { c = 0,    f = function(x, y) return 5949.8 - 3000 * (y - 0.4848), -12074.1 - 4000 * (x - 0.5822) end },
    [2405] = { c = 2771, f = function(x, y) return 895.8 - 6000 * (y - 0.702), -448.9 - 10000 * (x - 0.5164) end },
    [2576] = { c = 2694, f = function(x, y) return -266.8 - 620 * (y - 0.7045), -444.9 - 940 * (x - 0.6289) end },
    [2413] = { c = 2694, f = function(x, y) return 500 - 5000 * y, 2000 - 6000 * x end },
  }
  C_Map.GetWorldPosFromMapPos = function(m, v)
    local cv = CONV[m]; if not cv then return nil end
    local wx, wy = cv.f(v.x, v.y)
    return cv.c, { x = wx, y = wy }
  end
  PMAP, PX, PY = 2512, 0.55, 0.45
  C_Map.GetBestMapForUnit = function() return PMAP end
  C_Map.GetPlayerMapPosition = function() return { x = PX, y = PY } end
  UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
  C_Map.CanSetUserWaypointOnMap = function() return true end
  C_Map.SetUserWaypoint = function(p) PIN = p end
  C_Map.GetUserWaypoint = function() return PIN end
  C_Map.HasUserWaypoint = function() return PIN ~= nil end
  C_Map.ClearUserWaypoint = function() PIN = nil end
  C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
  TICKS = {}
  C_Timer.NewTicker = function(sec, fn) local t = { fn = fn, Cancel = function(self) self.dead = true end }; table.insert(TICKS, t); return t end
  function Tick() for _, t in ipairs(TICKS) do if not t.dead then t.fn() end end end
  ADDED, REMOVED = {}, {}
  TomTom = { AddWaypoint = function(self, m, x, y, o) table.insert(ADDED, o.title); return #ADDED end,
             RemoveWaypoint = function(self, uid) table.insert(REMOVED, uid) end,
             SetCrazyArrow = function(self, uid, d, title) ARROW = title end }
  for k in pairs(Q) do Q[k] = nil end
  for k in pairs(QuestsToRichesDB.cacheSources) do QuestsToRichesDB.cacheSources[k] = nil end
  Q[11] = { map = 2395, title = "B 실버문 앞", money = 10000000, t = 86400, x = 0.40, y = 0.25 }
  Q[12] = { map = 2395, title = "A 영원노래 깊숙이", money = 10000000, t = 86400, x = 0.10, y = 0.05 }
  print("== S1: 똬리의 섬에서 출발")
  QTR.forceScan = true
  QTR.RouteStart()
  print("S1 route:", table.concat(ADDED, " / "))
end""")(out, addon)
lua.eval("""function(out, QTR)
  QTR.RouteClear(true)
  for k in pairs(Q) do Q[k] = nil end
  Q[21] = { map = 2405, title = "V1 공허", money = 10000000, t = 86400, x = 0.45, y = 0.60 }
  Q[22] = { map = 2405, title = "V2 공허", money = 10000000, t = 86400, x = 0.40, y = 0.55 }
  Q[31] = { map = 2413, title = "H1 하란", money = 10000000, t = 86400, x = 0.30, y = 0.30 }
  Q[41] = { map = 2512, title = "C1 똬리", money = 10000000, t = 86400, x = 0.50, y = 0.60 }
  Q[11] = { map = 2395, title = "B 실버문 앞", money = 10000000, t = 86400, x = 0.40, y = 0.25 }
  PMAP, PX, PY = 2393, 0.36, 0.66   -- 실버문 포탈 방 근처
  ADDED = {}
  print("== S2: 실버문에서 출발, 모든 지역")
  QTR.forceScan = true
  QTR.RouteStart()
  for i, a in ipairs(ADDED) do print("  " .. a) end

  -- S3: 첫 목적지가 포탈이면 포탈을 타서 도착점에 서는 순간 다음으로 넘어간다
  print("== S3: 포탈 타기")
  print("  first:", QTR.route[1].label)
  Tick()  -- 제자리
  local r = QTR.route[1]
  local to = r.portal and ({ [1] = { 2405, 0.516377, 0.701999 } })[r.portal]
  -- 첫 포탈의 도착점으로 순간이동
  local PT = { [1] = { 2405, 0.516377, 0.701999 }, [3] = { 2576, 0.628871, 0.704452 }, [7] = { 2512, 0.582207, 0.484791 } }
  local dest = PT[r.portal]
  if dest then PMAP, PX, PY = dest[1], dest[2], dest[3] end
  Tick()
  print("  after portal, first:", QTR.route and QTR.route[1].label)

  -- S4: 경로에 없는 순간이동 (귀환석으로 실버문)
  print("== S4: 귀환석")
  PMAP, PX, PY = 2393, 0.50, 0.70
  Tick()
  print("  after hearth, first:", QTR.route and QTR.route[1].label)
end""")(out, addon)
lua.eval("""function(out, QTR)
  print("== S5: TomTom 없이 소굴 포탈 핀")
  QTR.RouteClear(true)
  TomTom = nil; PIN = nil
  C_Map.CanSetUserWaypointOnMap = function(m) return m ~= 2576 end
  local orig = C_Map.GetMapInfo
  C_Map.GetMapInfo = function(id) if id == 2576 then return { name = "소굴", parentMapID = 2413 } end return orig and orig(id) end
  C_Map.GetMapPosFromWorldPos = function(c, w, m) return m, { x = 0.77, y = 0.66 } end
  for k in pairs(Q) do Q[k] = nil end
  Q[21] = { map = 2405, title = "V1 공허", money = 10000000, t = 86400, x = 0.45, y = 0.60 }
  PMAP, PX, PY = 2413, 0.5, 0.5   -- 하란다르에 있음 -> 공허폭풍행 포탈(소굴)부터
  QTR.forceScan = true
  QTR.RouteStart()
  print("  pin:", PIN and (PIN.uiMapID .. " " .. PIN.position.x .. "," .. PIN.position.y))
end""")(out, addon)
