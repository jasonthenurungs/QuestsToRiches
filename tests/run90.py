# 쿨타임이 짧은 수단 우선 (2026-11-08 사용자 결정): 같은 구간에서 30초 안이면 쿨타임이 짧은 수단, 내비 기록에 표지 (run.pref)
#   줄아만 마이사라 동굴 입구(2437, 0.445193, 0.393821)에 내린다. 쿨타임 8시간, 설정 travelMaisaraOn으로 켠다 (2026-11-02부터 기본 끔)
#   배운 캐릭터만, 쿨타임 중이면 넣지 않음, 사용 버튼 창은 그 주문, 내리면 다음 목적지로, /qtr hearth 상태 줄
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

  -- 2026-11-08 게임 (격냥패딩): 실버문(8862,-4736)에서 줄아만 91805 (5496,-7287).
  -- 쐐기 포탈 입구(5946,-7624)에서 약 560야드, 구렁로봇 미궁 입구 실측(5647,-5777)에서 약 1520야드: 쐐기 포탈이 약 17초 빠르다
  TOYS = { [230850] = true }
  function PlayerHasToy(id) return TOYS[id] or false end
  ICD[230850] = { 0, 0 }
  KNOWN[1254559] = true
  DB.settings.travelMaisaraOn = true
  DB.settings.travelDelveBotOn = true
  DB.settings.travelWhyOn = true
  DB.delveBotLab = 1
  DB.travelDest = { delvebot = { c = 0, x = 5646.6, y = -5777.0, t = 1 } }
  for k in pairs(Q) do Q[k] = nil end
  local G1 = { map = 2437, title = "G1 91805 자리", money = 11065402, t = 86400, x = 0.40749, y = 0.46947 }
  -- 쐐기 포탈 입구 너머 (두 도착점을 잇는 줄의 연장선): 차이가 두 도착점 거리(약 1870야드, 33초)에 가깝다
  local G2 = { map = 2437, title = "G2 마이사라 너머", money = 11065402, t = 86400, x = 0.65503, y = 0.34264 }
  Q[81] = G1
  local function lastPref()
    local run = DB.navLog and DB.navLog[#DB.navLog]
    local t = {}
    for _, e in ipairs(run and run.pref or {}) do table.insert(t, e.key .. " (" .. e.over .. " 대신, " .. e.sec .. "초, t=" .. tostring(e.t ~= nil) .. ")") end
    return #t > 0 and table.concat(t, ", ") or "없음"
  end
  local SM = { 2393, 0.49910, 0.48728 } -- 실버문 (8862,-4736)
  route("1) 차이 약 17초 -> 쿨타임 1시간인 구렁로봇을 넣고 기록에 표지", SM[1], SM[2], SM[3])
  print("  기록 표지: " .. lastPref())
  print("==T 2) 같은 회차에서 다시 짜도 표지는 한 번만")
  QTR.RouteStart("test", true)
  print("  기록 표지: " .. lastPref())
  Q[81] = G2
  route("3) 하란다르에서 출발, 차이 30초 넘음 -> 쐐기 포탈 (표지 없음)")
  print("  기록 표지: " .. lastPref())
  Q[81] = G1
  SCD[1254559] = { NOWT - 60, 8 * 3600 }
  route("4) 쐐기 포탈 쿨타임 중 -> 구렁로봇, 표지 없음 (어차피 못 쓰므로)", SM[1], SM[2], SM[3])
  print("  기록 표지: " .. lastPref())
  SCD[1254559] = nil
  ICD[230850] = { NOWT - 60, 3600 }
  route("5) 구렁로봇 쿨타임 중 -> 쐐기 포탈, 표지 없음", SM[1], SM[2], SM[3])
  print("  기록 표지: " .. lastPref())
  ICD[230850] = { 0, 0 }
  DB.settings.travelWhyOn = false
  route("6) 알림 설정 끔 -> 채팅 없이 구렁로봇, 표지는 남김", SM[1], SM[2], SM[3])
  print("  기록 표지: " .. lastPref())
  DB.settings.travelWhyOn = true
  -- 2026-11-08 게임 (연남동누렁스): 줄아만 91801 황혼의 파멸. 두 도착점에서 거리가 약 10야드 차이라 "약 0초"로 나왔다
  Q[81] = { map = 2437, title = "G3 91801 자리", money = 10634778, t = 86400, x = 0.3757914900779724, y = 0.7215083837509155 }
  route("7) 차이 1초 미만 -> 거의 같다는 문구", SM[1], SM[2], SM[3])
  print("  기록 표지: " .. lastPref())
  print("==T end")
end''')(addon, out)
