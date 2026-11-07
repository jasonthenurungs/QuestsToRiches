# 해금된 특별 과제 알아채기 (2026-11-08 사용자 제보, 압구정): 퀘스트 목록에 받아 둔 특별 과제는 열린 것으로 보고, 해금 예정 목적지가 남아 있으면 10초마다 확인
#   줄아만 마이사라 동굴 입구(2437, 0.445193, 0.393821)에 내린다. 대기시간 8시간, 설정 travelMaisaraOn으로 켠다 (2026-11-02부터 기본 끔)
#   배운 캐릭터만, 대기시간 중이면 넣지 않음, 사용 버튼 창은 그 주문, 내리면 다음 목적지로, /qtr hearth 상태 줄
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
  -- 귀환석은 대기시간 중 (마이사라 동굴 순간이동만 보려고)
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

  -- 압구정 사례: 줄아만 골드퀘를 마쳐 특별 과제 "다시 우리의 것으로!"(91796)가 열렸고 퀘스트 목록에도 있는데,
  -- 지도 목록에는 아직 안 나온다 (보상 정보를 불러오는 중 등). 경로에는 "해금 예정" 목적지가 남아 있다
  ONQUEST = {}
  C_QuestLog.IsOnQuest = function(id) return ONQUEST[id] == true end
  C_QuestLog.GetTitleForQuestID = function(id) if id == 91796 then return "특별 과제: 다시 우리의 것으로!" end return "퀘" .. id end
  for k in pairs(Q) do Q[k] = nil end
  Q[95990] = { map = 2512, title = "꿈틀거리는 고지", money = 10000000, t = 86400, x = 0.3967, y = 0.4848 }
  Q[96066] = { map = 2512, title = "기어드는 조사자", money = 10000000, t = 86400, x = 0.5688, y = 0.4934 }
  DB.cacheSources.q91796 = { kind = "quest", questID = 91796, itemID = 279520, title = "특별 과제: 다시 우리의 것으로!",
    zone = "아탈아만", via = "log", learned = 1, lastSeen = 1, expire = time() + 3 * 86400 }
  route("1) 줄아만에서 출발 (특별 과제는 아직 퀘스트 목록에 없음)", 2437, 0.38, 0.72)
  -- 처음 짤 때 해금 예정으로 들어간 목적지를 흉내 (실제로는 잠긴 아이콘 위치)
  table.insert(QTR.route, 1, { questID = 91796, locked = true, need = 0, label = "1. (해금 예정) 특별 과제: 다시 우리의 것으로!",
    title = "특별 과제: 다시 우리의 것으로!", wp = { 2437, 0.357, 0.544 }, zone = "줄아만" })
  print("==T 2) 10초 동안 아직 안 열림 -> 그대로")
  for _ = 1, 10 do Tick() end
  RunLater()
  print("  first: " .. tostring(QTR.route and QTR.route[1].label))
  print("==T 3) 퀘스트 목록에 생김 (지도 목록에는 아직 없음) -> 10초 안에 열린 것으로 알아채고 다시 짬, 위치는 해금 예정 목적지 위치")
  ONQUEST[91796] = true
  for _ = 1, 10 do Tick() end
  RunLater()
  local labels = {}
  for _, r in ipairs(QTR.route or {}) do table.insert(labels, r.label .. (r.locked and " [잠김]" or "")) end
  print("  route: " .. table.concat(labels, " / "))
  local first = QTR.route and QTR.route[1]
  print("  특별 과제 위치: " .. tostring(first and first.wp and (first.wp[1] .. " " .. first.wp[2] .. " " .. first.wp[3])))
  print("==T 4) 이미 완료(이번 내비게이션에서)면 넣지 않음")
  QTR.routeDone = QTR.routeDone or {}
  QTR.routeDone[91796] = true
  QTR.RouteStart("시험", true)
  labels = {}
  for _, r in ipairs(QTR.route or {}) do table.insert(labels, r.label) end
  print("  route: " .. table.concat(labels, " / "))
  print("==T end")
end''')(addon, out)
