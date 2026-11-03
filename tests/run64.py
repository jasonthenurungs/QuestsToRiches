# 대시보드 고정 버튼(Esc로 안 닫힘)과 창 크기(dashScale, navScale 따로: 배율, 위치 보정, 최대 높이, 예전 uiScale 옮기기) (run62 준비 부분 사용)
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
      ["여름이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
    },
    days = {}, turnIns = {},
    settings = { tab = "dash", pos = { "TOPLEFT", "BOTTOMLEFT", 300, 900 }, routePopPos = { 750, 900 } },
  }
  local TIP = {}
  GameTooltip = { SetOwner = function() end, SetText = function(self, t) TIP = { t } end,
    AddLine = function(self, t) table.insert(TIP, t) end, Show = function() end, Hide = function() end }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local S = QuestsToRichesDB.settings
  local f, pop = QuestsToRichesFrame, QuestsToRichesRouteFrame
  local function inEsc(name)
    for _, v in ipairs(UISpecialFrames) do if v == name then return "Esc로 닫힘" end end
    return "Esc로 안 닫힘"
  end
  local pin
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "_scr_OnClick") and rawget(fr, "_x") == -2 and rawget(fr, "_y") == 0 then pin = fr end
  end
  print("== 1) 대시보드 고정 버튼")
  print("  처음: 대시보드 " .. inEsc("QuestsToRichesFrame") .. ", 내비 " .. inEsc("QuestsToRichesRouteFrame"))
  rawget(pin, "_scr_OnClick")(pin)
  print("  누름: dashPinned=" .. tostring(S.dashPinned) .. ", 대시보드 " .. inEsc("QuestsToRichesFrame") .. ", 내비 " .. inEsc("QuestsToRichesRouteFrame"))
  print("  툴팁: " .. table.concat(TIP, " / "))
  rawget(pin, "_scr_OnClick")(pin)
  print("  다시 누름: dashPinned=" .. tostring(S.dashPinned) .. ", 대시보드 " .. inEsc("QuestsToRichesFrame"))
  local n = 0
  for _, v in ipairs(UISpecialFrames) do if v == "QuestsToRichesFrame" then n = n + 1 end end
  print("  Esc 목록 중복 없음: " .. n .. "개")
  S.dashPinned = true
  QTR.ApplyDashPinned()
  print("  저장된 켜짐 적용(접속 때): 대시보드 " .. inEsc("QuestsToRichesFrame"))

  print("== 2) 창 크기")
  local function st(title)
    print("  " .. title .. ": 배율 대시보드 " .. tostring(rawget(f, "_scale")) .. ", 내비 " .. tostring(rawget(pop, "_scale"))
      .. " / 대시보드 위치 " .. string.format("%.1f, %.1f", S.pos[3], S.pos[4])
      .. " / 내비 위치 " .. string.format("%.1f, %.1f", S.routePopPos[1], S.routePopPos[2])
      .. " / 화면 기준 왼쪽 위 대시보드 " .. string.format("%.1f, %.1f", S.pos[3] * (S.dashScale or 1), S.pos[4] * (S.dashScale or 1))
      .. ", 내비 " .. string.format("%.1f, %.1f", S.routePopPos[1] * (S.navScale or 1), S.routePopPos[2] * (S.navScale or 1)))
  end
  st("처음 (설정 없음)")
  -- 대시보드와 내비게이션 창을 따로 (2026-10-27): 바꾼 창만 배율과 위치가 바뀐다
  local function set(v) local old = S.dashScale or 1; S.dashScale = v; QTR.ApplyUIScale("dash", old) end
  local function setNav(v) local old = S.navScale or 1; S.navScale = v; QTR.ApplyUIScale("nav", old) end
  set(1.5); st("대시보드 150%")
  setNav(1.25); st("내비 125%")
  set(0.8); st("대시보드 80%")
  set(1); setNav(1); st("둘 다 100%으로 되돌림")
  print("  적용된 대시보드 좌표: " .. tostring(rawget(f, "_x")) .. ", " .. tostring(rawget(f, "_y")))
  -- 1.4.0의 공통 설정(uiScale 1.3)이 남아 있으면 두 창에 옮긴다 (접속 때)
  S.uiScale, S.dashScale, S.navScale = 1.3, nil, nil
  QTR.ApplyUIScale()
  print("  예전 공통 설정 1.3 옮김: dashScale=" .. tostring(S.dashScale) .. " navScale=" .. tostring(S.navScale) .. " uiScale=" .. tostring(S.uiScale)
    .. " / 배율 대시보드 " .. tostring(rawget(f, "_scale")) .. ", 내비 " .. tostring(rawget(pop, "_scale")))
  S.dashScale, S.navScale = 1, 1
  QTR.ApplyUIScale()

  print("== 3) 내용이 긴 부자되기 탭의 창 높이 (화면 높이 700)")
  rawset(UIParent, "_h", 700)
  for i = 1, 40 do
    QuestsToRichesDB.activeGQ[1000 + i] = { name = "긴목록" .. i, zone = "공허폭풍", mapID = 2405, money = 10000000,
      expire = now + 40000, seen = now, seenBy = { ["여름이간다-데스윙"] = now } }
  end
  QuestsToRiches_ToggleDashboard()
  QTR:Refresh()
  print("  100%: 창 높이 " .. tostring(rawget(f, "_h")) .. " (최대 700, 화면 700/1-40=660)")
  set(1.5)
  print("  150%: 창 높이 " .. tostring(rawget(f, "_h")) .. " (화면 700/1.5-40=426)")
  set(1)
  print("  100%으로 되돌림: 창 높이 " .. tostring(rawget(f, "_h")))
  print("== end")
end''')(addon, out)
