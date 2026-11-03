import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness3.lua', encoding='utf-8').read())
# 완료 기록 지역명: 하위 지도 이름을 골드퀘 지역 이름으로 (run54 준비 부분을 그대로 씀)
lua.execute('''
CHARNAME = "봄이간다"
NOWT = 1000
function GetTime() return NOWT end
Enum = { QuestTagType = { Capstone = 99 } }
C_Map = { GetMapInfo = function(id) return { name = "공허폭풍" } end, GetBestMapForUnit = function() return 9999 end }
C_TaskQuest = { GetQuestsOnMap = function() return {} end, GetQuestInfoByQuestID = function() return nil end,
  GetQuestTimeLeftSeconds = function() return nil end, GetQuestZoneID = function() return 2405 end }
C_QuestLog.IsQuestFlaggedCompleted = function() return false end
C_QuestLog.GetQuestTagInfo = function() return {} end
C_TooltipInfo = { GetItemByID = function() return { lines = {} } end }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 1 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end }
function hooksecurefunc() end
C_EventUtils = { IsEventValid = function() return false end }
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
MODKEY = false
function IsModifierKeyDown() return MODKEY end
function ScrollFrame_OnMouseWheel(self, delta) SCROLLED = delta end
Minimap = CreateFrame("Frame", "Minimap")
Minimap.GetWidth = function() return 198 end
Minimap.GetHeight = function() return 198 end
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval('''function(QTR, out)
  NAMES = { [2395] = "영원노래 숲", [2393] = "실버문", [2424] = "영원노래 하위", [2437] = "줄아만", [2405] = "공허폭풍",
            [2444] = "학살자의 오름길", [2413] = "하란다르", [2512] = "똬리의 섬", [9001] = "공허폭풍 동굴" }
  PARENT = { [9001] = 2444, [2444] = 2405 }
  C_Map.GetMapInfo = function(id) return NAMES[id] and { name = NAMES[id], parentMapID = PARENT[id] or 0 } or nil end
  -- 게임이 알려 주는 자식 지도 (allowedMaps에 없는 하위 지역도 바로잡는다)
  C_Map.GetMapChildrenInfo = function(id) if id == 2437 then return { { mapID = 9100, name = "줄아만 하위 동굴" } } end return {} end
  local today = date("%Y-%m-%d", time())
  QuestsToRichesDB = { chars = {}, turnIns = {}, settings = { tab = "dash" },
    days = { ["2026-10-20"] = { ["봄이간다-데스윙"] = { count = 3, money = 1, quests = {
      { id = 1, name = "정기 지배", zone = "학살자의 오름길", money = 1, t = 1 },
      { id = 2, name = "가둬진 공허", zone = "공허폭풍", money = 1, t = 2 },
      { id = 3, name = "실버문 퀘", zone = "실버문", money = 1, t = 3 },
      { id = 4, name = "자원 회수", zone = "줄아만", money = 1, t = 4 },
      { id = 5, name = "동굴 퀘", zone = "줄아만 하위 동굴", money = 1, t = 5 } } } } },
    cacheSources = { q900 = { kind = "quest", questID = 900, title = "실버문 주간: 수호", zone = "실버문", itemID = 279520 } } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  print("== fixed records")
  for dk, day in pairs(QuestsToRichesDB.days) do for ck, rec in pairs(day) do for _, q in ipairs(rec.quests or {}) do print("  " .. dk .. " " .. q.name .. ": " .. q.zone) end end end
  print("  cache source zone (unchanged):", QuestsToRichesDB.cacheSources.q900.zone)
  print("== zone of maps")
  for _, m in ipairs({ 2444, 9001, 2405, 2393, 2437, 1234 }) do print("  " .. m .. ": " .. tostring(QTR.GQZoneNameOfMap(m))) end
  -- 새 완료 기록: 퀘스트 지도가 하위 지도(2444)여도 골드퀘 지역 이름으로 남긴다
  print("== new turn-in")
  C_QuestLog.IsWorldQuest = function() return true end
  C_TaskQuest.GetQuestZoneID = function() return 2444 end
  C_QuestLog.GetTitleForQuestID = function() return "새 퀘스트" end
  QTR:QUEST_TURNED_IN("x", 777, 0, 10000000)
  -- 퀘스트 지도를 못 읽으면 내 지도(9001, 공허폭풍 안 동굴)에서 올라가 찾는다
  C_TaskQuest.GetQuestZoneID = function() return 0 end
  C_Map.GetBestMapForUnit = function() return 9001 end
  QTR:QUEST_TURNED_IN("x", 778, 0, 10000000)
  for dk, day in pairs(QuestsToRichesDB.days) do for ck, rec in pairs(day) do for _, q in ipairs(rec.quests or {}) do
    if q.id == 777 or q.id == 778 then print("  " .. q.id .. " " .. tostring(q.name) .. ": " .. tostring(q.zone)) end
  end end end
end''')(addon, out)