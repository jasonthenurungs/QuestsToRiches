# 쐐기 포탈 여러 곳 (2026-11-14 사용자 요청): 쐐기돌 던전 순간이동은 쿨타임(8시간)을 함께 써서 한 동선에서 합쳐 한 번만.
#   배운 던전 중 가장 빨라지는 곳 하나. 이름은 아는 던전 이름, 모르면 게임의 주문 이름. 입구 어림 좌표는 한 번 쓰면 실제로 내린 곳으로 바꾼다
#   (run70 준비 부분 사용. 마이사라 1254559, 윈드러너 첨탑 1254400, 공결탑 제나스 1254563(공허폭풍))
#   시즌 2 (같은 날 추가): 날로라크의 소굴 1286807 (줄아만 실측 입구). 설정창 던전별 켜고 끄기 (DB.settings.mplusOff)
#   설정창 칸은 아홉 곳 모두, 배우지 않은 던전은 회색에 툴팁 "아직 배우지 않았습니다" (같은 날 사용자 요청)
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
    [2437] = { c = 0,    f = function(x, y) return 7000 - 4000 * y, -7000 - 5000 * x end },
    [2512] = { c = 0,    f = function(x, y) return 5949.8 - 3000 * (y - 0.4848), -12074.1 - 4000 * (x - 0.5822) end },
    [2405] = { c = 2771, f = function(x, y) return 895.8 - 6000 * (y - 0.702), -448.9 - 10000 * (x - 0.5164) end },
    [2576] = { c = 2694, f = function(x, y) return -266.8 - 620 * (y - 0.7045), -444.9 - 940 * (x - 0.6289) end },
    [2413] = { c = 2694, f = function(x, y) return 500 - 5000 * y, 2000 - 6000 * x end },
    [2424] = { c = 0,    f = function(x, y) return 12000 - 3000 * y, -5000 - 3000 * x end },
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
  SNAMES = { [1254559] = "심연의 동굴의 길", [1254400] = "윈드러너의 길", [1254563] = "조각난 핵의 길" }
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

  local MAI, WR, XEN = 1254559, 1254400, 1254563
  local function cdAll(v) for _, id in ipairs({ MAI, WR, XEN }) do SCD[id] = v end end
  local function dest(id)
    local d = DB.travelDest and DB.travelDest.mplus and DB.travelDest.mplus[id]
    return d and (d.c .. " " .. math.floor(d.x + 0.5) .. " " .. math.floor(d.y + 0.5)) or "없음"
  end
  OPTIONS.args.travelGroup.args.travelMaisara.set(nil, true)
  print("==T 0) 설정 이름: " .. tostring(OPTIONS.args.travelGroup.args.travelMaisara.name))
  -- 줄아만 두 곳과, 공허폭풍 제나스 입구(0.647, 0.6177) 곁 한 곳
  Q[73] = { map = 2405, title = "V1 공허폭풍 동쪽", money = 10000000, t = 86400, x = 0.66, y = 0.62 }
  KNOWN[MAI] = true
  route("1) 마이사라만 배움 -> 마이사라")
  KNOWN[WR], KNOWN[XEN] = true, true
  route("2) 세 곳 배움 -> 쐐기 포탈은 한 번만, 가장 많이 줄어드는 곳")
  button()
  print("==T 3) /qtr hearth (윈드러너, 조각난 핵은 내리는 곳 어림)")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  print("==T 4) 조각난 핵의 길을 쓰고 어림 위치에서 약 60야드 떨어진 곳에 내림 -> 그 자리를 기억")
  local first = QTR.route and QTR.route[1]
  print("  첫 단계 주문: " .. tostring(first and first.spell))
  PMAP, PX, PY = 2413, 0.95, 0.95
  QTR.OnPlayerSpellcast(XEN)
  PMAP, PX, PY = 2405, 0.6476, 0.6177
  RunLater()
  print("  기억: " .. dest(XEN))
  print("==T 5) 윈드러너의 길을 써서 다른 대륙에 내림 -> 기억하지 않음")
  PMAP, PX, PY = 2413, 0.95, 0.95
  QTR.OnPlayerSpellcast(WR)
  PMAP, PX, PY = 2405, 0.5, 0.5
  RunLater()
  print("  기억: " .. dest(WR))
  print("==T 6) /qtr hearth (조각난 핵은 이제 어림 표시 없음)")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  cdAll({ NOWT - 60, 28800 })
  route("7) 쿨타임 중 (함께 씀) -> 쐐기 포탈 넣지 않음")
  cdAll(nil)
  KNOWN[XEN] = nil
  route("8) 조각난 핵을 모름 -> 마이사라나 윈드러너 중 하나만")
  print("==T 9) 설정창 던전별 칸: 아홉 곳 모두, 배우지 않은 던전은 회색")
  local each = OPTIONS.args.travelGroup.args.travelMaisaraEach
  KNOWN[1286807] = true
  local keys = {}
  for k, v in pairs(each.args) do table.insert(keys, k) end
  table.sort(keys, function(a, b) return each.args[a].order < each.args[b].order end)
  print("  묶음: " .. tostring(each.type) .. " inline " .. tostring(each.inline) .. " / " .. tostring(each.name) .. " / 칸 " .. #keys)
  for _, k in ipairs(keys) do
    local o = each.args[k]
    print("  " .. k .. " " .. o.name() .. " | 회색 " .. tostring(o.disabled()) .. " | 체크 " .. tostring(o.get()) .. " | 툴팁 " .. tostring(o.desc()) .. " | 칸 " .. tostring(o.dialogControl))
  end
  print("  큰 설정 켜짐이라 묶음은 바꿀 수 있음 " .. tostring(not each.disabled()))
  -- 회색이어도 툴팁이 뜨는 체크 칸: AceGUI 기본 체크 칸이 없는 시험 환경이면 nil (기본 체크 칸)
  print("  QTR_CheckBox 등록: " .. tostring(QTR.RegisterDisabledTipCheckBox()))
  local nal = each.args.d1286807
  -- 줄아만 남쪽 날로라크의 소굴 입구 곁 퀘스트
  for k in pairs(Q) do Q[k] = nil end
  Q[74] = { map = 2437, title = "Z3 줄아만 남쪽", money = 10000000, t = 86400, x = 0.32, y = 0.82 }
  route("10) 날로라크의 소굴을 배움 -> 날로라크의 소굴")
  nal.set(nil, false)
  print("  끈 뒤 저장: " .. tostring(DB.settings.mplusOff and DB.settings.mplusOff[1286807]) .. ", 보기 " .. tostring(nal.get()))
  route("11) 날로라크의 소굴을 끔 -> 다른 던전 (마이사라 또는 윈드러너)")
  print("==T 12) /qtr hearth (끈 던전은 끔)")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  nal.set(nil, true)
  print("  다시 켬: " .. tostring(DB.settings.mplusOff[1286807]))
  OPTIONS.args.travelGroup.args.travelMaisara.set(nil, false)
  print("  큰 설정을 끄면 던전별 묶음은 못 바꿈: " .. tostring(each.disabled()))
  print("==T 13) 회색이어도 툴팁이 뜨는 체크 칸 (흉내 AceGUI)")
  local FREG = { CheckBox = function() return { type = "CheckBox", frame = { SetMotionScriptsWhileDisabled = function(f, v) f.mswd = v end } } end }
  local FAKE = { WidgetRegistry = FREG, RegisterWidgetType = function(self, n, ctor, v) FREG[n] = ctor end }
  local oldLS = LibStub
  LibStub = function(n, ...) if n == "AceGUI-3.0" then return FAKE end return oldLS(n, ...) end
  local cname = QTR.RegisterDisabledTipCheckBox()
  local w = FREG[cname]()
  print("  " .. tostring(cname) .. ": 종류 " .. tostring(w.type) .. ", 회색일 때 마우스 " .. tostring(w.frame.mswd) .. " / 기본 체크 칸은 그대로 " .. tostring(FREG.CheckBox().frame.mswd))
  LibStub = oldLS
  print("==T end")
end''')(addon, out)
