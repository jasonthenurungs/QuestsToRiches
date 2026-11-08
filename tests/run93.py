# 하라니르 뿌리걸음 (2026-11-08 인벤 김다크님 제안, 사용자 "한번 테스트해보자"): 주문 1238686, 쿨타임 없음, 하란다르 요람으로
#   요람 위치는 어림값으로 시작해 한 번 써서 내린 곳을 배우면 그것으로, 마법사 순간이동처럼 TravelCost에 넣는다. 세계수 뿌리 가까이(150야드)에서는 넣지 않는다
#   다른 대륙에 내리면 배우지 않음, 설정 travelRootOff, 사용 버튼 창은 그 주문, /qtr hearth 상태 줄
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
NAMES = { [2395] = "영원노래 숲", [2437] = "줄아만", [2405] = "공허폭풍", [2413] = "하란다르", [2512] = "똬리의 섬" }
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
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
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
  -- run65와 같은 지도 좌표 흉내
  function CreateVector2D(x, y) return { x = x, y = y } end
  local CONV = {
    [2393] = { c = 0,    f = function(x, y) return 8527.6 - 1875 * (y - 0.665628), -4327.1 - 2806 * (x - 0.35338) end },
    [2395] = { c = 0,    f = function(x, y) return 9500 - 4000 * y, -3000 - 5000 * x end },
    [2437] = { c = 0,    f = function(x, y) return 8287 - 5945 * y, -3644 - 8940 * x end }, -- 2026-11-08 navLog로 맞춘 줄아만
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
  -- 귀환석은 쿨타임 중 (마이사라 동굴 순간이동만 보려고)
  ICD = { [6948] = { NOWT - 60, 900 } }
  C_Container.GetItemCooldown = function(id) local c = ICD[id] or { 0, 0 }; return c[1], c[2], 1 end
  KNOWN = {}
  function IsPlayerSpell(id) return KNOWN[id] or false end
  SCD = {}
  SNAMES = { [1254559] = "심연의 동굴의 길" }
  C_Spell = { GetSpellCooldown = function(id) local c = SCD[id] or { 0, 0 }; return { startTime = c[1], duration = c[2] } end,
    GetSpellName = function(id) return SNAMES[id] end, GetSpellTexture = function(id) return 1000 + id end }
  function PlayerHasToy() return false end
  QuestsToRichesTravelButton.SetAttribute = function(self, k, v) rawset(self, "a_" .. k, v) end
  local PRINTS = {}
  local oldPrint = print

  local DB = QuestsToRichesDB
  DB.hearthBinds = { ["실버문"] = { c = 0, x = 8519.4, y = -4324.6, t = 1 } }
  Q[71] = { map = 2437, title = "Z1 줄아만", money = 10000000, t = 86400, x = 0.50, y = 0.45 }
  Q[72] = { map = 2437, title = "Z2 줄아만", money = 10000000, t = 86400, x = 0.55, y = 0.50 }
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
      .. " text=" .. clean(rawget(tb.text, "_text")):gsub("\n", " | "))
  end

  local ROOT = 1238686
  DB.settings.travelWhyOn = true
  local function dest()
    local d = DB.travelDest and DB.travelDest.root
    return d and (d.c .. " " .. math.floor(d.x + 0.5) .. " " .. math.floor(d.y + 0.5)) or "없음"
  end
  for k in pairs(Q) do Q[k] = nil end
  -- 하란다르 요람 근처 퀘스트 (요람은 이 시험에서 하란다르 0.5, 0.5로 둔다)
  Q[91] = { map = 2413, title = "H1 요람 근처", money = 10000000, t = 86400, x = 0.52, y = 0.52 }
  local SM = { 2393, 0.49910, 0.48728 } -- 실버문 (8862,-4736)
  route("1) 기술을 모름 -> 넣지 않음", SM[1], SM[2], SM[3])
  KNOWN[ROOT] = true
  route("2) 배웠고 요람 위치 모름 -> 어림 위치(하란다르 0.509, 0.507)로 넣음", SM[1], SM[2], SM[3])
  print("==T 2b) /qtr hearth")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  print("==T 3) 세계수 뿌리 곁에서 써서 다른 대륙(c=1)으로 감 -> 배우지 않음")
  PMAP, PX, PY = 2413, 0.7645, 0.4740
  QTR.OnPlayerSpellcast(ROOT)
  local oldW = C_Map.GetWorldPosFromMapPos
  C_Map.GetWorldPosFromMapPos = function(m, v) if m == 9998 then return 1, { x = 100, y = 100 } end return oldW(m, v) end
  PMAP, PX, PY = 9998, 0.5, 0.5
  RunLater()
  print("  기억한 요람: " .. dest())
  print("==T 4) 실버문에서 써서 하란다르(0.5, 0.5)에 내림 -> 요람으로 기억")
  PMAP, PX, PY = SM[1], SM[2], SM[3]
  QTR.OnPlayerSpellcast(ROOT)
  PMAP, PX, PY = 2413, 0.5, 0.5
  RunLater()
  print("  기억한 요람: " .. dest())
  print("==T 4b) /qtr hearth")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  route("5) 실버문에서 하란다르 요람 근처 퀘스트 -> 뿌리걸음 (포탈 대신)", SM[1], SM[2], SM[3])
  button()
  -- 아미드라실 뿌리(0.7645, 0.4740)에서 요람까지 약 1,590야드(28초) > 순간이동 비용 20초
  route("6) 하란다르 아미드라실 뿌리 곁에서 출발 -> 넣지 않음 (다른 대륙으로 가므로)", 2413, 0.7645, 0.4740)
  route("7) 같은 뿌리에서 약 210야드 떨어진 곳 -> 뿌리걸음", 2413, 0.80, 0.4740)
  DB.settings.travelRootOff = true
  route("8) 설정 끔 -> 넣지 않음", SM[1], SM[2], SM[3])
  DB.settings.travelRootOff = nil
  route("9) 다시 실버문에서 시작하고 뿌리걸음을 써서 요람에 내림 -> 다음 목적지로", SM[1], SM[2], SM[3])
  QTR.OnPlayerSpellcast(ROOT)
  PMAP, PX, PY = 2413, 0.5, 0.5
  RunLater(); Tick(); Tick(); RunLater()
  print("  지금 단계: " .. tostring(QTR.route and QTR.route[1] and QTR.route[1].label))
  print("==T end")
end''')(addon, out)
