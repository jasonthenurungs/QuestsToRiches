# 둔둔의 풍요로운 이동 수단 (2026-11-07, 엔젤스쿨님 제안, 사용자 결정 "일단 구현, 필요한 사람만 켜기")
#   장난감 266370, 주문 1278093, 대기시간 30분, 설정 travelDundunOn (기본 끔)
#   지금 풍요 지점: 이벤트 목록(GetEventsForMap)의 아이콘 UI-EventPoi-abundancebountiful, 남은 시간: 툴팁 위젯 글자
#   장난감 없음/설정 끔이면 넣지 않음, 켜면 넣음, 사용 버튼은 장난감, 쓰면 내린 곳을 지점별로 기억,
#   지점이 바뀌면 다시 짜기, 끝나기 직전이면 넣지 않음, 한밤 밖에서 출발하면 첫 구간에는 쓰지 않음, 남은 시간 글자 읽기
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness2.lua', encoding='utf-8').read())
lua.execute('''
CHARNAME = "봄이간다"
NOWT = 10000
function GetTime() return NOWT end
Enum = { QuestTagType = { Capstone = 99 } }
NAMES = { [2395] = "영원노래 숲", [2437] = "줄아만", [2405] = "공허폭풍", [2413] = "하란다르", [2512] = "똬리의 섬", [2339] = "도르노갈" }
C_Map = { GetMapInfo = function(id) return { name = NAMES[id] or "실버문" } end, GetBestMapForUnit = function() return 9999 end }
Q = {}
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
function GetNumQuestLogRewards(id) return 0 end
function GetQuestLogRewardInfo(i, id) return nil end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return false end
C_QuestLog.GetQuestTagInfo = function(id) return {} end
-- 풍요 이벤트 흉내: EV = { map, poi, name, x, y, left(남은 시간 글자) }
EV = nil
C_AreaPoiInfo = {
  GetAreaPOIForMap = function() return {} end,
  GetEventsForMap = function(m) if EV and EV.map == m then return { 8600, EV.poi } end; return { 8600 } end,
  GetAreaPOIInfo = function(m, id)
    if id == 8600 then return { atlasName = "ui-eventpoi-saltherilssoiree", name = "살데릴의 연회", position = { x = 0.1, y = 0.1 } } end
    if EV and id == EV.poi and m == EV.map then
      return { atlasName = "UI-EventPoi-abundancebountiful", name = EV.name, description = "풍요로운 채집",
               position = { x = EV.x, y = EV.y }, tooltipWidgetSet = 1900, isCurrentEvent = true }
    end
    return nil
  end,
}
C_UIWidgetManager = {
  GetAllWidgetsBySetID = function(set) if set == 1900 then return { { widgetID = 7735, widgetType = 8 }, { widgetID = 7629, widgetType = 8 } } end; return {} end,
  GetTextWithStateWidgetVisualizationInfo = function(id)
    if id == 7735 then return { text = " 복원된 금고 열쇠: 11" } end
    if id == 7629 then return { text = EV and EV.left or "" } end
    return nil
  end,
}
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "x" } } } end }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function(id) return nil end, RequestLoadItemDataByID = function() end }
function hooksecurefunc() end
C_EventUtils = { IsEventValid = function() return false end }
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
MerchantFrame = { IsShown = function() return false end }
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval(r'''function(QTR, out)
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  function CreateVector2D(x, y) return { x = x, y = y } end
  local CONV = {
    [2393] = { c = 0,    f = function(x, y) return 8527.6 - 1875 * (y - 0.665628), -4327.1 - 2806 * (x - 0.35338) end },
    [2395] = { c = 0,    f = function(x, y) return 9500 - 4000 * y, -3000 - 5000 * x end },
    [2437] = { c = 0,    f = function(x, y) return 7000 - 4000 * y, -7000 - 5000 * x end },
    [2512] = { c = 0,    f = function(x, y) return 5949.8 - 3000 * (y - 0.4848), -12074.1 - 4000 * (x - 0.5822) end },
    [2405] = { c = 2771, f = function(x, y) return 895.8 - 6000 * (y - 0.702), -448.9 - 10000 * (x - 0.5164) end },
    [2576] = { c = 2694, f = function(x, y) return -266.8 - 620 * (y - 0.7045), -444.9 - 940 * (x - 0.6289) end },
    [2413] = { c = 2694, f = function(x, y) return 500 - 5000 * y, 2000 - 6000 * x end },
    [2339] = { c = 2552, f = function(x, y) return 100 - 1000 * y, 100 - 1000 * x end },
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
  function GetBindLocation() return "실버문" end
  function IsInGuild() return true end
  function UnitRace() return "x", "Orc" end
  function UnitClass() return "x", "WARRIOR" end
  -- 귀환석은 대기시간 중 (둔둔 장난감만 보려고)
  ICD = { [6948] = { NOWT - 60, 900 } }
  C_Container.GetItemCooldown = function(id) local c = ICD[id] or { 0, 0 }; return c[1], c[2], 1 end
  function IsPlayerSpell(id) return false end
  C_Spell = { GetSpellCooldown = function(id) return { startTime = 0, duration = 0 } end,
    GetSpellName = function(id) return nil end, GetSpellTexture = function(id) return 1000 + id end }
  TOYS = {}
  function PlayerHasToy(id) return TOYS[id] or false end
  QuestsToRichesTravelButton.SetAttribute = function(self, k, v) rawset(self, "a_" .. k, v) end

  local DB = QuestsToRichesDB
  DB.hearthBinds = { ["실버문"] = { c = 0, x = 8519.4, y = -4324.6, t = 1 } }
  Q[71] = { map = 2437, title = "Z1 줄아만", money = 10000000, t = 86400, x = 0.50, y = 0.45 }
  Q[72] = { map = 2437, title = "Z2 줄아만", money = 10000000, t = 86400, x = 0.55, y = 0.50 }
  EV = { map = 2437, poi = 8700, name = "풍요: 가죽 동굴", x = 0.52, y = 0.47, left = "남은 시간: 4시간 12분" }
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
    print("  button: shown=" .. tostring(ta._shown) .. " type=" .. tostring(rawget(tb, "a_type")) .. " toy=" .. tostring(rawget(tb, "a_toy"))
      .. " text=" .. clean(rawget(tb.text, "_text")):gsub("\n", " | "))
  end

  route("1) 장난감 없음 -> 넣지 않음")
  TOYS[266370] = true
  route("1b) 장난감 있지만 설정 기본 끔 -> 넣지 않음")
  local opt = OPTIONS.args.travelGroup.args.travelDundun
  print("  default travelDundunOn = " .. tostring(DB.settings.travelDundunOn) .. " / toggle get = " .. tostring(opt.get()))
  print("  option name = " .. opt.name)
  opt.set(nil, true)
  print("  toggle on -> travelDundunOn = " .. tostring(DB.settings.travelDundunOn))
  route("2) 켬, 하란다르에서 출발, 풍요는 줄아만 -> 둔둔 장난감 먼저")
  button()
  print("  first poi = " .. tostring(QTR.route[1].poi) .. " chat = " .. tostring(QTR.route[1].chatLabel))
  print("==T 3) /qtr hearth (내리는 곳 아직 모름)")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  print("==T 4) 장난감을 쓰고 아이콘에서 조금 떨어진 동굴 입구에 내림 -> 내린 곳 기억")
  LATER = {}
  QTR.OnPlayerSpellcast(1278093)
  button()
  PMAP, PX, PY = 2437, 0.521, 0.468
  RunLater()
  local d = DB.travelDest and DB.travelDest.dundun and DB.travelDest.dundun[8700]
  print("  learned 8700: " .. (d and string.format("c=%d x=%.1f y=%.1f", d.c, d.x, d.y) or "nil"))
  Tick()
  print("  first: " .. tostring(QTR.route and QTR.route[1].label))
  ICD[266370] = { NOWT - 60, 1800 }
  print("==T 5) /qtr hearth (대기시간 중, 내린 곳 기억함)")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  route("6) 대기시간 중 -> 넣지 않음")
  ICD[266370] = nil
  route("7) 다시 쓸 수 있음 -> 넣음 (도착지는 기억한 곳)")
  print("  arrival: " .. string.format("c=%d x=%.1f y=%.1f", QTR.route[1].arrival.c, QTR.route[1].arrival.x, QTR.route[1].arrival.y))
  print("==T 8) 안내 중 풍요 지점이 공허폭풍으로 바뀜 -> 다시 짬")
  EV = { map = 2405, poi = 8526, name = "풍요: 채광 공허굴", x = 0.388, y = 0.533, left = "남은 시간: 7시간 59분" }
  for _ = 1, 30 do Tick() end
  local labels = {}
  for _, r in ipairs(QTR.route or {}) do table.insert(labels, r.label) end
  print("  route: " .. table.concat(labels, " / "))
  EV = { map = 2437, poi = 8700, name = "풍요: 가죽 동굴", x = 0.52, y = 0.47, left = "남은 시간: 1분" }
  route("9) 풍요가 1분 뒤 끝남 -> 넣지 않음")
  EV.left = "남은 시간: 3분"
  route("9b) 3분 뒤 끝남 -> 첫 구간(지금)에는 넣음")
  EV.left = "알 수 없는 글자"
  route("10) 남은 시간 못 읽음 -> 따지지 않고 넣음")
  EV.left = "남은 시간: 4시간 12분"
  route("11) 한밤 밖(도르노갈)에서 출발 -> 첫 구간에는 쓰지 않음", 2339, 0.5, 0.5)
  route("12) 설정 끔 -> 넣지 않음")
  opt.set(nil, false)
  route("12b) 끈 뒤")
  print("==T 13) 남은 시간 글자 읽기")
  for _, s in ipairs({ "남은 시간: 4시간 12분", "|cffffffff남은 시간: 45분|r", "Time Left: 4 Hr 12 Min", "2 hours 5 minutes",
      "1일 3시간", " 복원된 금고 열쇠: 11", "8 / 8", "5 Shards of Dundun", "" }) do
    print("  [" .. s .. "] -> " .. tostring(QTR.TestParseLeft(s)))
  end
  print("==T end")
end''')(addon, out)
