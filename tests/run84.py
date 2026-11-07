# 줄아만 하위 지도 2536 아탈아만 (2026-11-08 사용자 게임 확인: 특별 과제 "다시 우리의 것으로!" 91796이 GetQuestsOnMap(2437)에
#   mapID 2536으로 나온다). 줄아만 지역으로 인정해야 해금된 특별 과제의 위치를 배우고 내비게이션이 알아챈다
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness2.lua', encoding='utf-8').read())
lua.execute('''
CHARNAME = "봄이간다"
NOWT = 1000
function GetTime() return NOWT end
Enum = { QuestTagType = { Capstone = 99 } }
NAMES = { [2395] = "영원노래 숲", [2437] = "줄아만", [2405] = "공허폭풍", [2413] = "하란다르", [2512] = "똬리의 섬", [2536] = "아탈아만" }
C_Map = { GetMapInfo = function(id) return { name = NAMES[id] or "실버문" } end, GetBestMapForUnit = function() return 9999 end }
-- GetQuestsOnMap(2437)에 나오는 것: 특별 과제(하위 지도 2536), 아탈아만의 골드퀘(2536), 줄아만 골드퀘(2437), 이웃 지역 퀘스트(2395, 걸러져야 함)
Q = {
  [91796] = { map = 2536, title = "특별 과제: 다시 우리의 것으로!", money = 0, t = 3 * 86400, x = 0.357, y = 0.544, reward = 279520 },
  [70001] = { map = 2536, title = "아탈아만 골드퀘", money = 10500000, t = 86400, x = 0.36, y = 0.50 },
  [70002] = { map = 2437, title = "줄아만 골드퀘", money = 10400000, t = 86400, x = 0.55, y = 0.18 },
  [70003] = { map = 2395, title = "이웃 영원노래 퀘", money = 10300000, t = 86400, x = 0.9, y = 0.9 },
}
C_TaskQuest = {
  GetQuestsOnMap = function(mapID)
    local r = {}
    if mapID ~= 2437 then return r end
    for id, q in pairs(Q) do table.insert(r, { questID = id, mapID = q.map, x = q.x, y = q.y }) end
    table.sort(r, function(a, b) return a.questID < b.questID end)
    return r
  end,
  GetQuestInfoByQuestID = function(id) return Q[id] and Q[id].title end,
  GetQuestTimeLeftSeconds = function(id) return Q[id] and Q[id].t end,
  GetQuestZoneID = function() return 2437 end,
}
function GetQuestLogRewardMoney(id) return Q[id] and Q[id].money or 0 end
function GetNumQuestLogRewards(id) return (Q[id] and Q[id].reward) and 1 or 0 end
function GetQuestLogRewardInfo(i, id) return "x", 1, 1, 4, true, Q[id].reward, 1 end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return false end
C_QuestLog.GetQuestTagInfo = function(id) return {} end
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "x" } } } end }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function(id) return "정점 보관함" end, RequestLoadItemDataByID = function() end }
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
  local now = time()
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "gq" },
    -- 퀘스트 목록에서만 배워 위치가 없는 출처 (사용자 저장 데이터와 같은 모양)
    cacheSources = { q91796 = { kind = "quest", questID = 91796, itemID = 279520, title = "특별 과제: 다시 우리의 것으로!",
      zone = "아탈아만", via = "log", learned = now - 86400, lastSeen = now - 3600, expire = now + 3 * 86400 } },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  QTR.forceScan = true
  SlashCmdList["QUESTSTORICHES"]("gq")
  RunLater()
  print("== 1) 해금된 특별 과제 (아탈아만 지도) -> 지도에서 위치를 배우고 지금 캐릭터 지도의 보관함 퀘스트로 본다")
  local s = DB.cacheSources.q91796
  print("  위치: " .. (s.wp and (s.wp[1] .. " " .. s.wp[2] .. " " .. s.wp[3]) or "없음"))
  print("  지도의 보관함 퀘스트: " .. tostring(QTR.mapCaches and QTR.mapCaches[91796]))
  print("== 2) 아탈아만 골드퀘는 줄아만 골드퀘로, 이웃 지역 퀘스트는 여전히 거름")
  for _, id in ipairs({ 70001, 70002, 70003 }) do
    local a = DB.activeGQ[id]
    print("  " .. id .. ": " .. (a and (a.name .. " / " .. a.zone .. " / " .. a.mapID) or "없음"))
  end
  print("== end")
end''')(addon, out)
