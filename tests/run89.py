# 구렁로봇 7001로 킨도잔의 미궁 (2026-11-08 사용자 결정, 기본 끔): 칩 학습, 동선, 사용 버튼, 미궁 자동 선택과 다른 애드온용 신호, 내린 곳 기억
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

  -- 구렁로봇 7001: 장난감 230850, 주문 467470, 로봇 NPC 232267, 미궁 선택지 142847, 미궁 입구 영원노래 숲 62.89 71.98
  TOYS = { [230850] = true }
  function PlayerHasToy(id) return TOYS[id] or false end
  ICD[230850] = { 0, 0 }
  NPCGUID = "Vehicle-0-3058-0-18913-232267-00006FAC77"
  function UnitGUID(u) if u == "npc" then return NPCGUID end return "Player-1-1" end
  OPTS = { { gossipOptionID = 140193, name = "카즈 알가르 구렁으로 데려다주십시오." },
           { gossipOptionID = 140192, name = "한밤 구렁으로 데려다주십시오." },
           { gossipOptionID = 142847, name = "킨도잔의 미궁으로 데려다주십시오." } }
  PICKED = {}
  C_GossipInfo = { GetOptions = function() return OPTS end, SelectOption = function(id) table.insert(PICKED, id) end }
  SHIFT = false
  function IsShiftKeyDown() return SHIFT end
  local function picked() local r = table.concat(PICKED, ","); PICKED = {}; return r == "" and "없음" or r end
  for k in pairs(Q) do Q[k] = nil end
  -- 영원노래 숲 남쪽(미궁 입구 가까이) 퀘스트 하나, 하란다르 먼 구석에서 출발 (귀환석은 대기시간 중)
  Q[71] = { map = 2395, title = "E1 영원노래 남쪽", money = 10000000, t = 86400, x = 0.60, y = 0.74 }
  DB.settings.travelWhyOn = true
  route("1) 장난감은 있지만 설정 기본 끔 -> 넣지 않음")
  print("  설정 기본값: " .. tostring(OPTIONS.args.travelGroup.args.travelDelveBot.get()))
  OPTIONS.args.travelGroup.args.travelDelveBot.set(nil, true)
  route("2) 켬, 미궁 칩을 아직 모름 -> 넣지 않고 이유")
  print("==T 3) 로봇에게 말을 검 (내비게이션 단계가 아님): 칩을 배우고, 자동 선택은 안 함")
  QTR.TestOnGossip()
  print("  delveBotLab: " .. tostring(DB.delveBotLab ~= nil and DB.delveBotLab ~= false) .. " / 고른 것: " .. picked())
  route("4) 칩을 앎 -> 구렁로봇을 넣음")
  button()
  -- 2026-11-08 창 넘침: 줄마다 잰 너비에 맞춰 창을 넓힌다 (글자 하나 4로 흉내)
  rawset(QuestsToRichesTravelButton.measure, "GetStringWidth", function(self) return #(self._text or "") * 4 end)
  rawset(QuestsToRichesTravelAlert, "SetWidth", function(self, w) rawset(self, "_w", w) end)
  QTR.UpdateTravelButton()
  print("  창 너비: " .. tostring(rawget(QuestsToRichesTravelAlert, "_w")) .. " (가장 긴 줄 4 x 75바이트 + 70)")
  print("  다른 애드온용 신호 (아직 장난감 안 씀): " .. tostring(QuestsToRiches_WantsDelveBotLabyrinth()))
  print("==T 5) 장난감을 씀 -> 신호 켜짐, 말을 걸면 미궁을 고름 (한 번만)")
  LATER = {}
  QTR.OnPlayerSpellcast(467470)
  print("  신호: " .. tostring(QuestsToRiches_WantsDelveBotLabyrinth()))
  QTR.TestOnGossip()
  print("  고른 것: " .. picked())
  QTR.TestOnGossip()
  print("  같은 장난감 사용에 두 번째 대화창: " .. picked() .. " / 신호는 1분 동안 유지: " .. tostring(QuestsToRiches_WantsDelveBotLabyrinth()))
  print("==T 6) 미궁 입구에 내림 -> 내린 곳 기억, 다음 목적지")
  PMAP, PX, PY = 2395, 0.6289, 0.7198
  RunLater()
  Tick()
  local d = DB.travelDest and DB.travelDest.delvebot
  print("  기억한 곳: " .. tostring(d and (d.c .. " " .. math.floor(d.x) .. " " .. math.floor(d.y))))
  print("  first: " .. tostring(QTR.route and QTR.route[1] and QTR.route[1].label))
  print("==T 7) Shift를 누르고 말을 걸면 고르지 않음")
  route("7a) 다시 시작")
  QTR.OnPlayerSpellcast(467470)
  SHIFT = true
  QTR.TestOnGossip()
  SHIFT = false
  print("  고른 것: " .. picked())
  print("==T 8) 1분이 지나면 신호 꺼짐")
  NOWT = NOWT + 61
  print("  신호: " .. tostring(QuestsToRiches_WantsDelveBotLabyrinth()))
  NOWT = NOWT - 61
  print("==T 9) 계정에서 칩을 본 뒤 다른 캐릭터 대화창에 미궁이 없어도 칩이 있다고 본다 (2026-11-08 사용자 요청)")
  local labOpts = OPTS
  OPTS = { labOpts[1], labOpts[2] }
  QTR.TestOnGossip()
  print("  delveBotLab 그대로: " .. tostring(DB.delveBotLab ~= false and DB.delveBotLab ~= nil))
  route("9a) 여전히 구렁로봇을 넣음")
  print("==T 9b) 선택지를 읽지 못한 대화창 (다른 애드온이 먼저 골라 닫힘 등) -> 배우지 않음")
  local before = DB.delveBotLab
  OPTS = {}
  QTR.TestOnGossip()
  print("  바뀌지 않음: " .. tostring(DB.delveBotLab == before))
  print("==T 9c) 칩을 본 적이 없는 계정 (선택지에 미궁 없음) -> 배우고 넣지 않음")
  local landing = DB.travelDest.delvebot
  DB.delveBotLab, DB.travelDest.delvebot = nil, nil
  OPTS = { labOpts[1], labOpts[2] }
  QTR.TestOnGossip()
  print("  delveBotLab: " .. tostring(DB.delveBotLab))
  route("9c) 칩 없음")
  print("==T 9d) false로 덮였어도 미궁 입구에 내린 기록이 있으면 칩이 있다고 본다 (그날 게임의 상태)")
  DB.travelDest.delvebot = landing
  print("  delveBotLab: " .. tostring(DB.delveBotLab))
  route("9d) 구렁로봇을 넣음")
  print("==T 10) 다른 NPC의 대화창은 무시")
  NPCGUID = "Creature-0-3058-0-18913-12345-00006FAC77"
  OPTS = { { gossipOptionID = 142847, name = "x" } }
  QTR.TestOnGossip()
  print("  delveBotLab: " .. tostring(DB.delveBotLab))
  NPCGUID = "Vehicle-0-3058-0-18913-232267-00006FAC77"
  QTR.TestOnGossip()
  print("==T 11) 대기시간 중 -> 이유")
  ICD[230850] = { NOWT - 60, 3600 }
  route("11) 대기시간")
  ICD[230850] = { 0, 0 }
  print("==T 12) /qtr hearth")
  SlashCmdList["QUESTSTORICHES"]("hearth")
  OPTIONS.args.travelGroup.args.travelDelveBot.set(nil, false)
  print("  끔 -> travelDelveBotOn = " .. tostring(DB.settings.travelDelveBotOn))
  route("13) 끔 -> 넣지 않음")
  print("==T end")
end''')(addon, out)
