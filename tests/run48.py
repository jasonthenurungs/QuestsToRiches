import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
base = TD + ''
addon, out = lua.execute(open(base + 'harness3.lua', encoding='utf-8').read())
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

lua.execute("""
Minimap = CreateFrame("Frame", "Minimap")
Minimap.GetWidth = function() return 198 end
Minimap.GetHeight = function() return 198 end
""")
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
  for _, fr in ipairs(ALLFRAMES) do if rawget(fr, "_scr_OnClick") and rawget(fr, "_text") == nil and rawget(fr, "_name") == "Button" and not (rawget(fr, "_x") == -2 and rawget(fr, "_y") == 0) and rawget(fr, "_pf") ~= QuestsToRichesTravelAlert then table.insert(clicks, fr) end end
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
  UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
  C_Map.CanSetUserWaypointOnMap = function() return true end
  C_Map.SetUserWaypoint = function() end
  C_Map.HasUserWaypoint = function() return true end
  C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
  function CreateVector2D(x, y) return { x = x, y = y } end
  local CONT = { [2405] = 2771, [2413] = 2694, [2576] = 2694 }
  C_Map.GetWorldPosFromMapPos = function(m, v) return CONT[m] or 0, { x = v.x * 1000, y = v.y * 1000 } end
  C_Map.GetPlayerMapPosition = function() return { x = 0.1, y = 0.1 } end
  C_Map.GetBestMapForUnit = function() return 2405 end
  TomTom = nil
  SOUNDKIT = { UI_RAID_BOSS_DEFEATED = 50111 }
  SOUNDS = {}
  PlaySound = function(k) table.insert(SOUNDS, k) end
  QTR.forceScan = true
  local pop = QuestsToRichesRouteFrame
  local function clean(t) return (tostring(t or ""):gsub("|TInterface\\\\RaidFrame[^|]*|t", "[V]"):gsub("|TInterface[^|]*|t", "g"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local hidden = {}
  local orig = pop.CreateFontString
  rawset(pop, "CreateFontString", function(self, ...)
    local c = orig(self, ...)
    rawset(c, "Hide", function(s) hidden[s] = true end)
    rawset(c, "Show", function(s) hidden[s] = nil end)
    rawset(c, "SetShown", function(s, v) hidden[s] = (not v) or nil end)
    return c
  end)
  local function dump(t)
    print("==== " .. t .. " shown=" .. tostring(pop._shown) .. " h=" .. tostring(rawget(pop, "_h")))
    local rows = {}
    for _, fs in ipairs(out) do
      if rawget(fs, "_parent") == pop and type(fs._text) == "string" and fs._text ~= "" and not hidden[fs] then
        print("  " .. clean(fs._text))
      end
    end
  end
  local function inEsc() for _, n in ipairs(UISpecialFrames) do if n == "QuestsToRichesRouteFrame" then return true end end return false end
  print("title main:", QuestsToRichesFrame.Title and QuestsToRichesFrame.Title._text)
  print("esc list has nav (default):", inEsc())
  -- 특별 과제(보관함 퀘스트) 지도에 표시: Q[5]
  Q[5] = { map = 2405, title = "특별 과제: 수요와 공급", money = 0, t = 2*86400, capstone = true, reward = 279520, x = 0.12, y = 0.12 }
  QTR.forceScan = true
  NOWSAVE = time
  local T = time()
  time = function(t) if t then return os.time(t) end return T end
  QTR.RouteStart()
  QTR.RoutePopupUpdate(true)
  dump("start")
  -- 순서대로 완료
  local order = {}
  for _, r in ipairs(QTR.route) do if r.questID then table.insert(order, r.questID) end end
  local function turnIn(q, plus)
    T = T + plus
    DONEFLAG[q] = true
    QTR:QUEST_TURNED_IN("x", q, 0, 0)
    LATER = {}
    -- 포탈이 첫 목적지면 건너뛴다 (포탈 통과 흉내)
    while QTR.route and QTR.route[1] and QTR.route[1].portal do table.remove(QTR.route, 1) end
  end
  turnIn(order[1], 300)
  turnIn(order[2], 240)
  dump("after 2 done")
  -- 보관함 열기: 특별 과제의 보관함 아이템 279520에서 300골드
  print("done list cacheItem:", QTR.routeDoneList[1].cacheItem, QTR.routeDoneList[2].cacheItem)
  QTR.NavCacheOpened(279520, 3000000)
  dump("after cache opened")
  turnIn(order[3], 600)
  turnIn(order[4], 900)
  dump("all done")
  local act
  for _, fr in ipairs(ALLFRAMES) do if rawget(fr, "_text") == "대시보드로 돌아가기" then act = fr end end
  print("finish button:", act and act._text, rawget(act, "_w"))
  QuestsToRichesFrame:Hide()
  rawget(act, "_scr_OnClick")(act)
  print("after click: nav", tostring(pop._shown), "dash", tostring(QuestsToRichesFrame._shown), "route", QTR.route ~= nil)
  -- 고정
  local pinBtn
  for _, fr in ipairs(ALLFRAMES) do if rawget(fr, "_scr_OnClick") and rawget(fr, "_name") == "Button" and rawget(fr, "_w") == 20 then pinBtn = fr end end
  rawget(pinBtn, "_scr_OnClick")(pinBtn)
  print("pinned:", QuestsToRichesDB.settings.navPinned, "esc list has nav:", inEsc())
  rawget(pinBtn, "_scr_OnClick")(pinBtn)
  print("unpinned:", QuestsToRichesDB.settings.navPinned, "esc list has nav:", inEsc())
  QuestsToRichesDB.settings.navPinned = true
  QTR.ApplyNavPinned()
  print("reload pinned -> esc list has nav:", inEsc())
end""")(out, addon)
