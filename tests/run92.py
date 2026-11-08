# 하위 지도 퀘스트 (2026-11-08 사용자 게임 확인: 똬리의 섬 골드퀘 "사술과 거짓" 96329가 GetQuestsOnMap(2512)에 mapID 2642
#   방황하는 사제의 무덤으로 나와 걸러졌다). 2642를 넣고, 목록에 없는 하위 지도도 상위 지도를 따라 올라가 그 지역이면 받는다
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
NAMES = { [2395] = "영원노래 숲", [2437] = "줄아만", [2405] = "공허폭풍", [2413] = "하란다르", [2512] = "똬리의 섬", [2536] = "아탈아만", [2642] = "방황하는 사제의 무덤", [2650] = "새 하위 지도", [2651] = "하위의 하위" }
PARENT = { [2642] = 2512, [2650] = 2512, [2651] = 2650, [2512] = 2537, [2437] = 2537, [2395] = 2537 }
C_Map = { GetMapInfo = function(id) return { name = NAMES[id] or "실버문", parentMapID = PARENT[id] } end, GetBestMapForUnit = function() return 9999 end }
-- GetQuestsOnMap(2437)에 나오는 것: 특별 과제(하위 지도 2536), 아탈아만의 골드퀘(2536), 줄아만 골드퀘(2437), 이웃 지역 퀘스트(2395, 걸러져야 함)
Q = {
  [91796] = { map = 2536, title = "특별 과제: 다시 우리의 것으로!", money = 0, t = 3 * 86400, x = 0.357, y = 0.544, reward = 279520 },
  [70001] = { map = 2536, title = "아탈아만 골드퀘", money = 10500000, t = 86400, x = 0.36, y = 0.50 },
  [70002] = { map = 2437, title = "줄아만 골드퀘", money = 10400000, t = 86400, x = 0.55, y = 0.18 },
  [70003] = { map = 2395, title = "이웃 영원노래 퀘", money = 10300000, t = 86400, x = 0.9, y = 0.9 },
}
-- GetQuestsOnMap(2512)에 나오는 것: 사술과 거짓(2642), 목록에 없는 하위 지도(2650)와 그 아래(2651), 이웃 줄아만(2437, 걸러져야 함)
Q2 = {
  [96329] = { map = 2642, title = "사술과 거짓", money = 10639588, t = 86400, x = 0.5226, y = 0.4328 },
  [80001] = { map = 2650, title = "새 하위 지도 골드퀘", money = 10200000, t = 86400, x = 0.30, y = 0.30 },
  [80002] = { map = 2651, title = "하위의 하위 골드퀘", money = 10100000, t = 86400, x = 0.31, y = 0.31 },
  [80003] = { map = 2437, title = "이웃 줄아만 퀘", money = 10000000, t = 86400, x = 0.5, y = 0.5 },
}
for id, q in pairs(Q2) do Q[id] = q end
C_TaskQuest = {
  GetQuestsOnMap = function(mapID)
    local r = {}
    if mapID ~= 2437 and mapID ~= 2512 then return r end
    for id, q in pairs(Q) do
      if (mapID == 2437) == (Q2[id] == nil) then table.insert(r, { questID = id, mapID = q.map, x = q.x, y = q.y }) end
    end
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
  print("== 1) 똬리의 섬 하위 지도 퀘스트는 똬리의 섬 골드퀘로, 이웃 지역 퀘스트는 거름")
  for _, id in ipairs({ 96329, 80001, 80002, 80003 }) do
    local a = DB.activeGQ[id]
    print("  " .. id .. ": " .. (a and (a.name .. " / " .. a.zone .. " / " .. a.mapID .. " / wp " .. (a.wp and a.wp[1] or "-")) or "없음"))
  end
  print("== 2) 줄아만 쪽은 그대로 (아탈아만 받고, 이웃 영원노래 거름)")
  for _, id in ipairs({ 70001, 70002, 70003 }) do
    local a = DB.activeGQ[id]
    print("  " .. id .. ": " .. (a and (a.name .. " / " .. a.zone .. " / " .. a.mapID) or "없음"))
  end
  print("== end")
end''')(addon, out)
