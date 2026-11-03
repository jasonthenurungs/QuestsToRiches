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





# 순간이동 2단계: 영혼의 귀환, 아르칸티나 열쇠, 마법사 실버문 순간이동, 귀환형 고려 순서, 사용 버튼 창 (run55 준비 부분 사용, 출력은 "==T" 이후)
lua.eval("""function(out, QTR)
  function CreateVector2D(x, y) return { x = x, y = y } end
  local CONV = {
    [2393] = { c = 0,    f = function(x, y) return 8527.6 - 1875 * (y - 0.665628), -4327.1 - 2806 * (x - 0.35338) end },
    [2395] = { c = 0,    f = function(x, y) return 9500 - 4000 * y, -3000 - 5000 * x end },
    [2437] = { c = 0,    f = function(x, y) return 7000 - 4000 * y, -7000 - 5000 * x end },
    [2512] = { c = 0,    f = function(x, y) return 5949.8 - 3000 * (y - 0.4848), -12074.1 - 4000 * (x - 0.5822) end },
    [2405] = { c = 2771, f = function(x, y) return 895.8 - 6000 * (y - 0.702), -448.9 - 10000 * (x - 0.5164) end },
    [2576] = { c = 2694, f = function(x, y) return -266.8 - 620 * (y - 0.7045), -444.9 - 940 * (x - 0.6289) end },
    [2413] = { c = 2694, f = function(x, y) return 500 - 5000 * y, 2000 - 6000 * x end },
    [3000] = { c = 5555, f = function(x, y) return 100 * x, 100 * y end }, -- 아르칸티나 (다른 공간) 흉내
  }
  C_Map.GetWorldPosFromMapPos = function(m, v)
    local cv = CONV[m]; if not cv then return nil end
    local wx, wy = cv.f(v.x, v.y)
    return cv.c, { x = wx, y = wy }
  end
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
  TomTom = nil
  BIND = "실버문"
  function GetBindLocation() return BIND end
  function IsInGuild() return true end
  function UnitRace() return "x", "Orc" end
  CLASS = "SHAMAN"
  function UnitClass() return "x", CLASS end
  -- 아이템 대기시간: 귀환석(6948), 아르칸티나 열쇠(253629)
  ICD = { [6948] = { 0, 0 }, [253629] = { 0, 0 } }
  C_Container.GetItemCooldown = function(id) local c = ICD[id] or { 0, 0 }; return c[1], c[2], 1 end
  KNOWN = {}
  function IsPlayerSpell(id) return KNOWN[id] or false end
  SCD = {}
  NAMES = { [556] = "영혼의 귀환", [1259190] = "순간이동: 실버문", [32272] = "순간이동: 실버문 (불타는 성전)" }
  C_Spell = { GetSpellCooldown = function(id) local c = SCD[id] or { 0, 0 }; return { startTime = c[1], duration = c[2] } end,
    GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return 1000 + id end }
  TOYS = {}
  function PlayerHasToy(id) return TOYS[id] or false end
  C_Item.GetItemSpell = function(id) if id == 253629 then return "열쇠", 1255801 end return nil end
  -- 주문책: 순간이동 묶음(flyout) 하나에 스톰윈드, 실버문
  Enum = Enum or {}
  Enum.SpellBookSpellBank = { Player = 0 }
  Enum.SpellBookItemType = { Spell = 1, Flyout = 4 }
  C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function() return { itemType = 4, actionID = 7, name = "순간이동" } end,
  }
  function GetFlyoutInfo(id) return "순간이동", "", 2, true end
  function GetFlyoutSlotInfo(id, k) if k == 1 then return 32272, nil, KNOWN[32272] or false, "순간이동: 실버문 (불타는 성전)" end return 1259190, nil, KNOWN[1259190] or false, "순간이동: 실버문" end
  -- 보안 버튼 속성을 볼 수 있게
  QuestsToRichesTravelButton.SetAttribute = function(self, k, v) rawset(self, "a_" .. k, v) end

  local DB = QuestsToRichesDB
  local me = DB.chars["봄이간다-데스윙"]
  DB.hearthBinds = { ["실버문"] = { c = 0, x = 8519.4, y = -4324.6, t = 1 } }
  local later = time() + 7200
  time = function(t) if t then return os.time(t) end return later end
  NOWT = 10000
  for k in pairs(Q) do Q[k] = nil end
  for k in pairs(DB.cacheSources) do DB.cacheSources[k] = nil end
  Q[41] = { map = 2512, title = "C1 똬리", money = 10000000, t = 86400, x = 0.50, y = 0.60 }
  Q[42] = { map = 2512, title = "C2 똬리", money = 10000000, t = 86400, x = 0.52, y = 0.62 }
  local function clean(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local function route(title, map, x, y)
    QTR.RouteClear(true)
    PMAP, PX, PY = map or 2413, x or 0.95, y or 0.95   -- 기본: 하란다르 먼 구석
    QTR.forceScan = true
    print("==T " .. title)
    QTR.RouteStart()
    local labels = {}
    for _, r in ipairs(QTR.route or {}) do table.insert(labels, r.label) end
    print("  route: " .. table.concat(labels, " / "))
  end
  local function button()
    local ta, tb = QuestsToRichesTravelAlert, QuestsToRichesTravelButton
    print("  button: shown=" .. tostring(ta._shown) .. " type=" .. tostring(rawget(tb, "a_type")) .. " spell=" .. tostring(rawget(tb, "a_spell"))
      .. " item=" .. tostring(rawget(tb, "a_item")) .. " toy=" .. tostring(rawget(tb, "a_toy")) .. " text=" .. clean(rawget(tb.text, "_text")):gsub("\\n", " | "))
  end

  -- 1) 주술사: 귀환석은 대기시간 중, 영혼의 귀환은 쓸 수 있다
  KNOWN[556] = true
  ICD[6948] = { NOWT - 60, 900 }
  route("T1 shaman, hearth on cooldown -> astral recall")
  button()
  SCD[556] = { NOWT - 30, 600 }
  route("T1b astral also on cooldown -> nothing")
  SCD[556] = nil
  DB.settings.travelAstralOff = true
  route("T1c astral setting off -> nothing")
  DB.settings.travelAstralOff = nil
  -- 2) 귀환석과 영혼의 귀환을 둘 다 쓸 수 있으면: 더 많이 줄어드는 구간부터 하나씩 (한 구간에는 하나)
  ICD[6948] = { 0, 0 }
  DB.settings.hearthKeepOff = true
  Q[43] = { map = 2405, title = "V1 공허폭풍", money = 10000000, t = 86400, x = 0.30, y = 0.20 }
  route("T2 hearth + astral both ready, keep off, quests in 똬리 and 공허폭풍")
  Q[43] = nil
  DB.settings.hearthKeepOff = nil
  KNOWN[556] = nil

  -- 3) 아르칸티나 열쇠: 나오는 곳(나그네의 쉼터)을 알아야 넣는다. 비용이 커서(45초) 귀환석보다 덜 줄어든다
  CLASS = "WARRIOR"
  TOYS[253629] = true
  ICD[6948] = { NOWT - 60, 900 }
  route("T3 arcantina, exit unknown -> nothing")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  DB.hearthBinds["나그네의 쉼터"] = { c = 0, x = 8519.4, y = -4324.6, t = 1 }
  route("T3b arcantina, exit known (나그네의 쉼터) -> arcantina")
  button()
  print("==T T3c take arcantina: into the Arcantina (another place) -> wait, out at the inn -> next")
  PMAP, PX, PY = 3000, 0.5, 0.5
  Tick()
  print("  first:", QTR.route[1].label, "inside:", tostring(QTR.route[1].inside))
  button()
  PMAP, PX, PY = 2393, 0.36, 0.66
  Tick()
  print("  after exit, first:", QTR.route and QTR.route[1].label)
  local run = QTR.navRun
  print("  navlog last stop:", run and run.stops[#run.stops] and run.stops[#run.stops].portal)
  DB.settings.travelArcantinaOff = true
  route("T3d arcantina setting off -> nothing")
  DB.settings.travelArcantinaOff = nil
  ICD[253629] = { NOWT - 60, 900 }
  route("T3e arcantina on cooldown -> nothing")
  ICD[253629] = { 0, 0 }
  TOYS[253629] = nil

  -- 4) 마법사 실버문 순간이동: 주문책 순간이동 묶음에서 찾고, 포탈처럼 경로에 넣는다 (대기시간 없음)
  CLASS = "MAGE"
  KNOWN[1259190] = true
  for k in pairs(Q) do Q[k] = nil end
  Q[51] = { map = 2395, title = "E1 영원노래", money = 10000000, t = 86400, x = 0.60, y = 0.30 }
  Q[52] = { map = 2405, title = "V2 공허폭풍", money = 10000000, t = 86400, x = 0.30, y = 0.20 }
  route("T4 mage in 공허폭풍 far side -> teleport to Silvermoon instead of flying to the portal", 2405, 0.30, 0.25)
  button()
  SlashCmdList["QUESTSTORICHES"]("hearth")
  DB.settings.travelMageOff = true
  route("T4b mage setting off -> portal", 2405, 0.30, 0.25)
  DB.settings.travelMageOff = nil
  KNOWN[1259190] = nil
  KNOWN[32272] = true
  route("T4c mage knows only the old (Burning Crusade) Silvermoon teleport -> portal", 2405, 0.30, 0.25)
  SlashCmdList["QUESTSTORICHES"]("hearth")
  print("==T T4d cast the old teleport -> not learned / cast the Midnight one -> landing learned")
  KNOWN[1259190] = true
  LATER = {}
  PMAP, PX, PY = 2405, 0.30, 0.25
  QTR.OnPlayerSpellcast(32272)
  PMAP, PX, PY = 2393, 0.53, 0.66
  RunLater()
  local d = DB.travelDest and DB.travelDest.mage
  print("  after old spell, landing:", d and d.c)
  LATER = {}
  PMAP, PX, PY = 2405, 0.30, 0.25
  QTR.OnPlayerSpellcast(1259190)
  PMAP, PX, PY = 2393, 0.53, 0.66
  RunLater()
  d = DB.travelDest and DB.travelDest.mage
  print("  after Midnight spell, landing:", d and d.c, d and math.floor(d.x), d and math.floor(d.y))
  -- 테스트 버전이 옛 실버문 도착점(다른 대륙 530)을 기억해 둔 경우: 경로를 짤 때 지우고 실측 위치를 쓴다
  DB.travelDest.mage = { c = 530, x = 9909, y = -7545, t = 1 }
  me.mageTele = 32272
  route("T4e wrong learned landing (old Silvermoon) -> removed, teleport used", 2405, 0.30, 0.25)
  print("  travelDest.mage:", DB.travelDest.mage, " mageTele:", me.mageTele)
  -- 같은 실버문으로 갈 때 마법사는 귀환석보다 순간이동 (귀환석은 15초 이상 더 빠를 때만)
  ICD[6948] = { 0, 0 }
  DB.settings.hearthKeepOff = true
  route("T4f mage with hearth ready -> teleport, not hearth", 2405, 0.30, 0.25)
  DB.settings.hearthKeepOff = nil
  ICD[6948] = { NOWT - 60, 900 }
  KNOWN[32272] = nil

  -- 5) 영혼의 귀환 시전: 대기시간 길이와 귀환 지점을 기억한다
  print("==T T5 cast astral recall -> learn cooldown and bind")
  CLASS = "SHAMAN"
  KNOWN[556] = true
  BIND = "새 여관"
  LATER = {}
  PMAP, PX, PY = 2413, 0.95, 0.95
  QTR.OnPlayerSpellcast(556)
  SCD[556] = { NOWT, 540 }
  PMAP, PX, PY = 2393, 0.40, 0.70
  -- 내린 곳의 지역 이름도 기억한다 (2026-10-27). 2026-10-30부터 지도 기준: 내린 직후 GetRealZoneText가 바뀌기 전 지역
  -- ("황혼의 납골당")을 돌려줘도 지도(2393, 하네스 이름 "실버문")를 따른다
  GetRealZoneText = function() return "황혼의 납골당" end
  RunLater()
  print("  astralCD:", me.astralCD, " hearthBinds[새 여관]:", DB.hearthBinds["새 여관"] ~= nil, " hearth uses:", #(me.hearthUses or {}))
  print("  hearthBinds[새 여관].zone:", DB.hearthBinds["새 여관"] and DB.hearthBinds["새 여관"].zone, " zoneV:", DB.hearthBinds["새 여관"] and DB.hearthBinds["새 여관"].zoneV)
  -- 예전 방식으로 저장된 지역(zoneV 없음)은 쓰지 않는다
  DB.hearthBinds["옛 여관"] = { c = 0, x = 1, y = 1, t = 1, zone = "황혼의 납골당" }
  print("  옛 방식 지역은 안 씀:", (QTR.TravelLabelForTest and QTR.TravelLabelForTest("hearth", "옛 여관")) or "(함수 없음)")
  DB.hearthBinds["옛 여관"] = nil
  -- 지역을 아는 여관이면 경로 이름에 지역이 붙고, 내비게이션 창은 지역을 포탈 줄처럼 따로 쓴다
  BIND = "새 여관"
  SCD[556] = nil
  DB.hearthBinds["새 여관"] = { c = 0, x = 8519.4, y = -4324.6, t = 1, zone = "실버문", zoneV = 2 }
  local q41, q42, q51, q52 = Q[41], Q[42], Q[51], Q[52]
  Q[41] = { map = 2512, title = "C1 똬리", money = 10000000, t = 86400, x = 0.50, y = 0.60 }
  Q[42] = { map = 2512, title = "C2 똬리", money = 10000000, t = 86400, x = 0.52, y = 0.62 }
  route("T5b astral to inn with known zone")
  Q[41], Q[42] = q41, q42
  for _, fs in ipairs(out) do fs._text = "" end
  QTR.RoutePopupUpdate(true)
  -- 이름 칸 바로 뒤 글자칸이 지역 칸 (내비게이션 창은 이름과 지역을 다른 글자칸에 쓴다)
  for i, fs in ipairs(out) do
    if type(fs._text) == "string" and fs._text:find("새 여관", 1, true) and fs._shown ~= false then
      local nx = out[i + 1]
      print("  nav line:", (fs._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "/ zone:", nx and tostring(nx._text))
    end
  end
  -- 작은 글씨 (2026-10-30): 줄 높이 18 -> 15라 같은 경로에서 창 세로가 줄어든다. 배경 투명도는 설정창에서 바꾼다
  local pop = QuestsToRichesRouteFrame
  local hNormal = rawget(pop, "_h")
  local navArgs = OPTIONS.args.navGroup.args
  navArgs.navSmallFont.set(nil, true)
  local hSmall = rawget(pop, "_h")
  print("  작은 글씨: 창 세로 " .. tostring(hNormal) .. " -> " .. tostring(hSmall) .. ", 설정 " .. tostring(DB.settings.navSmallFont))
  navArgs.navSmallFont.set(nil, false)
  print("  작은 글씨 끔: 창 세로 " .. tostring(rawget(pop, "_h")) .. ", 설정 " .. tostring(DB.settings.navSmallFont))
  print("  배경 투명도 기본: " .. tostring(navArgs.navBgAlpha.get()))
  navArgs.navBgAlpha.set(nil, 0.3)
  print("  배경 투명도 0.3: " .. tostring(DB.settings.navBgAlpha) .. " / 창 전체 불투명도는 그대로 " .. tostring(pop:GetAlpha()))
  DB.settings.navBgAlpha = nil
  QTR.ApplyNavBg()
  QTR.RouteClear(true)
  GetRealZoneText = nil
  DB.hearthBinds["새 여관"] = nil
  BIND = "실버문"

  -- 6) 사용 버튼 창: 설정으로 끄기, 닫으면 그 단계 동안 다시 안 띄우기, 전투 중이면 끝난 뒤 고치기
  for k in pairs(Q) do Q[k] = nil end
  Q[41] = { map = 2512, title = "C1 똬리", money = 10000000, t = 86400, x = 0.50, y = 0.60 }
  Q[42] = { map = 2512, title = "C2 똬리", money = 10000000, t = 86400, x = 0.52, y = 0.62 }
  ICD[6948] = { 0, 0 }
  DB.settings.hearthKeepOff = true
  KNOWN[556] = nil
  CLASS = "WARRIOR"
  GetItemCount = function(id) return id == 6948 and 1 or 0 end
  C_Item.GetItemCount = function(id) return id == 6948 and 1 or 0 end
  route("T6 hearth first -> button uses the hearthstone item")
  button()
  print("==T T6a cast the hearthstone -> button hides for this step")
  LATER = {}
  QTR.OnPlayerSpellcast(8690)
  button()
  me.hearthUses = nil -- 시험을 이어 가려고 사용 기록을 지운다
  route("T6a2 new navigation again (use record cleared)")
  button()
  DB.settings.travelPopupOff = true
  QTR.UpdateTravelButton()
  print("==T T6b popup setting off")
  button()
  DB.settings.travelPopupOff = nil
  QTR.UpdateTravelButton()
  local close
  for _, fr in ipairs(ALLFRAMES) do if rawget(fr, "_pf") == QuestsToRichesTravelAlert and rawget(fr, "_scr_OnClick") then close = fr end end
  rawget(close, "_scr_OnClick")(close)
  QTR.UpdateTravelButton()
  print("==T T6c closed -> stays hidden for this step (also when re-planned)")
  button()
  QTR.RouteStart("순간이동을 감지했습니다.", true)
  button()
  route("T6d new navigation -> shown again")
  button()
  InCombatLockdown = function() return true end
  QTR.RouteClear(true)
  print("==T T6e in combat: route cleared but the button can't change until combat ends")
  button()
  InCombatLockdown = function() return false end
  QTR:PLAYER_REGEN_ENABLED()
  print("==T T6f after combat -> hidden")
  button()
  DB.settings.hearthKeepOff = nil

  -- 7) 귀환형 이동을 고려한 순서: 출발은 줄아만, 줄아만 사원 쪽 퀘스트 하나, 영원노래 숲 북쪽(실버문 가까이) 하나, 공허폭풍 둘
  --    귀환석이 없으면 줄아만에서 북쪽으로 날아가며 영원노래 숲을 들르는 것이 낫고,
  --    귀환석이 있으면 줄아만 다음에 바로 귀환석을 타고, 영원노래 숲은 공허폭풍에서 돌아와 하는 것이 나을 수 있다
  print("==T T7 order with/without recall (start 줄아만)")
  local function W(m, x, y) local c, p = C_Map.GetWorldPosFromMapPos(m, { x = x, y = y }); return { c = c, x = p.x, y = p.y } end
  local function P(id, title, m, x, y, zone) return { questID = id, title = title, wp = { m, x, y }, zone = zone, zoneMap = m, pos = W(m, x, y) } end
  local pts = {
    P(1, "줄아만 사원", 2437, 0.26, 0.78, "줄아만"),
    P(2, "영원노래 북쪽", 2395, 0.36, 0.20, "영원노래 숲"),
    P(3, "공허 A", 2405, 0.45, 0.60, "공허폭풍"), P(4, "공허 B", 2405, 0.40, 0.55, "공허폭풍"),
  }
  local start = W(2437, 0.30, 0.70)
  local rec = { { key = "hearth", dest = { c = 0, x = 8519.4, y = -4324.6 }, cost = 20 * 56, tokens = 1 } }
  local function show(title, recalls)
    local order, _, assumed = QTR.OrderPoints(pts, start, nil, {}, recalls)
    local names = {}
    for _, p in ipairs(order) do table.insert(names, p.title) end
    local n = 0 for _, v in pairs(assumed) do n = n + v end
    print("  " .. title .. ": " .. table.concat(names, " > ") .. " (귀환형 " .. n .. "번)")
    return order
  end
  local o1 = show("no recall")
  local o2 = show("hearth 1")
  o2 = show("hearth 1", rec)
  -- 같은 귀환석 1번을 쓸 때, 귀환석 없이 짠 순서에 1단계처럼 끼우는 것과 비교 (초)
  DB.settings.hearthKeepOff = true
  ICD[6948] = { 0, 0 }
  local function cost(order)
    local sum, prev = 0, start
    for _, p in ipairs(order) do sum = sum + QTR.TravelCost(prev, p.pos); prev = p.pos end
    local plan = QTR.PlanHearth(order, start)
    return math.floor(sum / 56), plan and math.floor((sum - plan.save) / 56), plan and order[plan.k].title
  end
  local a1, b1, k1 = cost(o1)
  local a2, b2, k2 = cost(o2)
  print("  1단계 방식(순서 먼저, 귀환석 끼우기): 이동 " .. a1 .. "초, 귀환석 반영 " .. tostring(b1) .. "초 (" .. tostring(k1) .. " 가기 전)")
  print("  2단계 방식(귀환석 고려해 순서):       이동 " .. a2 .. "초, 귀환석 반영 " .. tostring(b2) .. "초 (" .. tostring(k2) .. " 가기 전)")
  -- 무작위 200가지 (지역 5곳에 4~7곳, 출발점도 무작위): 2단계가 1단계보다 나빠지지 않는지, 얼마나 자주 나아지는지
  print("==T T8 random 200 cases: 1단계(순서 먼저) vs 2단계(귀환석 고려 순서)")
  local maps = { 2437, 2395, 2405, 2512, 2413 }
  local seed = 12345
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  local better, worse, same, gain, example = 0, 0, 0, 0, nil
  for c = 1, 200 do
    pts = {}
    local n = 4 + math.floor(rnd() * 4)
    for i = 1, n do
      local m = maps[1 + math.floor(rnd() * #maps)]
      table.insert(pts, P(i, "Q" .. i .. "(" .. m .. ")", m, 0.2 + rnd() * 0.6, 0.2 + rnd() * 0.6, tostring(m)))
    end
    local sm = maps[1 + math.floor(rnd() * #maps)]
    start = W(sm, 0.2 + rnd() * 0.6, 0.2 + rnd() * 0.6)
    local q1 = QTR.OrderPoints(pts, start, nil, {})
    local o1c = {} for i, p in ipairs(q1) do o1c[i] = p end
    local q2 = QTR.OrderPoints(pts, start, nil, {}, rec)
    local _, c1 = cost(o1c)
    local _, c2 = cost(q2)
    local s1, s2 = 0, 0
    local prev = start
    for _, p in ipairs(o1c) do s1 = s1 + QTR.TravelCost(prev, p.pos); prev = p.pos end
    prev = start
    for _, p in ipairs(q2) do s2 = s2 + QTR.TravelCost(prev, p.pos); prev = p.pos end
    local p1 = QTR.PlanHearth(o1c, start); local p2 = QTR.PlanHearth(q2, start)
    local t1 = (s1 - (p1 and p1.save or 0)) / 56
    local t2 = (s2 - (p2 and p2.save or 0)) / 56
    if t2 < t1 - 0.5 then
      better = better + 1; gain = gain + (t1 - t2)
      if not example or (t1 - t2) > example.g then
        local a, b = {}, {}
        for _, p in ipairs(o1c) do table.insert(a, p.title) end
        for _, p in ipairs(q2) do table.insert(b, p.title) end
        example = { g = t1 - t2, a = table.concat(a, " > ") .. " / 귀환석: " .. tostring(p1 and o1c[p1.k].title),
          b = table.concat(b, " > ") .. " / 귀환석: " .. tostring(p2 and q2[p2.k].title), t1 = t1, t2 = t2 }
      end
    elseif t2 > t1 + 0.5 then worse = worse + 1 else same = same + 1 end
  end
  print(string.format("  나아짐 %d, 같음 %d, 나빠짐 %d, 나아진 경우 평균 %.0f초", better, same, worse, better > 0 and gain / better or 0))
  print("  (순서를 짤 때는 대기시간을 따지지 않아 나빠질 수도 있으나, RouteStart는 두 방식 중 실제로 빠른 쪽을 고른다)")
  if example then
    print(string.format("  가장 나아진 예 (%.0f초 -> %.0f초)", example.t1, example.t2))
    print("    1단계: " .. example.a)
    print("    2단계: " .. example.b)
  end
  DB.settings.hearthKeepOff = nil

  -- 9) 내비게이션을 모두 마치면 귀환 버튼 (2026-10-27): 순간이동, 영혼의 귀환, 귀환석 순, 쓸 수 있는 것 하나
  for k in pairs(Q) do Q[k] = nil end
  Q[61] = { map = 2405, title = "V9 공허폭풍", money = 10000000, t = 86400, x = 0.30, y = 0.20 }
  local function finish(title, map, x, y)
    route(title, map or 2405, x or 0.30, y or 0.25)
    PMAP, PX, PY = map or 2405, 0.30, 0.20
    QTR.RouteAdvance(61)
    button()
  end
  ICD[6948] = { 0, 0 }
  me.hearthUses = nil
  CLASS = "MAGE"; KNOWN[1259190] = true
  finish("T9a mage finishes in 공허폭풍 -> Silvermoon teleport")
  CLASS = "SHAMAN"; KNOWN[1259190] = nil; KNOWN[556] = true; SCD[556] = nil
  finish("T9b shaman -> astral recall")
  KNOWN[556] = nil; CLASS = "WARRIOR"
  finish("T9c warrior, hearth ready -> hearthstone")
  print("==T T9d cast it -> button goes away")
  LATER = {}
  QTR.OnPlayerSpellcast(8690)
  button()
  me.hearthUses = nil
  ICD[6948] = { NOWT - 60, 900 }
  finish("T9e hearth on cooldown -> nothing")
  ICD[6948] = { 0, 0 }
  DB.settings.travelPopupOff = true -- 동선용 버튼 창을 꺼도 마친 뒤 버튼은 따로
  finish("T9f route popup off, finish popup on -> hearthstone")
  DB.settings.travelPopupOff = nil
  print("==T T9g stop navigation -> button goes away")
  QTR.RouteClear()
  button()
  DB.settings.finishPopupOff = true
  finish("T9h finish popup setting off -> nothing")
  DB.settings.finishPopupOff = nil
  -- 귀환 지점(실버문) 가까이서 마치면 띄우지 않는다
  Q[61] = { map = 2393, title = "S9 실버문", money = 10000000, t = 86400, x = 0.36, y = 0.66 }
  route("T9i finish next to the inn -> nothing", 2393, 0.36, 0.66)
  QTR.RouteAdvance(61)
  button()
  -- 수단별 허용 (설정 체크)과 아르칸티나 열쇠 (2026-10-27)
  Q[61] = { map = 2405, title = "V9 공허폭풍", money = 10000000, t = 86400, x = 0.30, y = 0.20 }
  CLASS = "MAGE"; KNOWN[1259190] = true
  DB.settings.finishMageOff = true
  finish("T9j mage, teleport unchecked -> hearthstone")
  DB.settings.finishMageOff = nil; CLASS = "WARRIOR"; KNOWN[1259190] = nil
  TOYS[253629] = true
  DB.settings.finishHearthOff = true
  finish("T9k hearth unchecked, Arcantina key owned -> Arcantina key")
  ICD[253629] = { NOWT - 60, 900 }
  finish("T9l hearth unchecked, key on cooldown -> nothing, quietly (no chat line)")
  ICD[253629] = { 0, 0 }
  DB.settings.finishArcantinaOff = true
  finish("T9m hearth and key unchecked -> nothing")
  DB.settings.finishHearthOff, DB.settings.finishArcantinaOff = nil, nil
  TOYS[253629] = nil
  print("==T end")
end""")(out, addon)
