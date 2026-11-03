# 실버문 주간 퀘스트 "수행중" (2026-11-01): 퀘스트 목록에 받아 둔 캐릭터는 미완료 대신 노란 "수행중", 미완료보다 위
#   다른 캐릭터는 마지막 접속 때 모습, 지난주에 본 것은 모름. 수행중만 있어도 줄을 그린다. 포기하면 다시 미완료
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
C_Map = { GetMapInfo = function(id) return { name = "실버문" } end, GetBestMapForUnit = function() return 9999 end }
C_TaskQuest = {
  GetQuestsOnMap = function(mapID) return {} end,
  GetQuestInfoByQuestID = function(id) return nil end,
  GetQuestTimeLeftSeconds = function(id) return nil end,
  GetQuestZoneID = function() return 2405 end,
}
function GetQuestLogRewardMoney(id) return 0 end
function GetNumQuestLogRewards(id) return 0 end
function GetQuestLogRewardInfo(i, id) return nil end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return false end
C_QuestLog.GetQuestTagInfo = function(id) return {} end
ONQUEST = {}
C_QuestLog.IsOnQuest = function(id) return ONQUEST[id] == true end
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "x" } } } end }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function(id) return "최정상 보관함" end, RequestLoadItemDataByID = function() end }
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
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["여름이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["격냥패딩-데스윙"] = { money = 1, class = "PALADIN", level = 90 },
              ["인구학-데스윙"] = { money = 1, class = "MAGE", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash", chatNotify = true },
  }
  -- 지금 캐릭터 봄이간다는 잘아타스 추적을 받아 두었다 (접속할 때 본다)
  ONQUEST[98172] = true
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local strip = function(s)
    s = tostring(s or "")
    s = s:gsub("|cffffd100", "[노랑]"):gsub("|cffff4444", "[빨강]")
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
  end
  local function rows(title)
    for _, fs in ipairs(out) do fs._text = "" end
    QTR:Refresh()
    local cells = {}
    for _, fs in ipairs(out) do
      if fs._shown and type(fs._text) == "string" and fs._text ~= "" and rawget(fs, "_y") and rawget(fs, "_y") <= 0 and rawget(fs, "_x") and rawget(fs, "_x") < 400 then table.insert(cells, fs) end
    end
    table.sort(cells, function(a, b) if a._y ~= b._y then return a._y > b._y end return a._x < b._x end)
    print("  -- " .. title)
    local line, lasty, on = {}, nil, false
    local function flush()
      local s = table.concat(line, " | ")
      if s:find("정점 보관함") == 1 then on = true end
      if on then print("    " .. s) end
    end
    for _, fs in ipairs(cells) do
      if lasty and fs._y ~= lasty then flush(); line = {} end
      lasty = fs._y; table.insert(line, strip(fs._text))
    end
    if #line > 0 then flush() end
  end
  local function expand(id)
    for _, fr in ipairs(ALLFRAMES) do
      if rawget(fr, "tipQuest") == id and rawget(fr, "_scr_OnClick") then rawget(fr, "_scr_OnClick")(fr, "LeftButton"); return end
    end
  end

  print("== 1) 접속 때 퀘스트 목록 기록")
  local w = DB.weeklyOn["봄이간다-데스윙"]
  print("  봄이간다 weeklyOn 98172: " .. tostring(w and w.ids[98172]) .. " / 93913: " .. tostring(w and w.ids[93913]))

  print("== 2) 잘아타스 추적: 여름이간다 완료, 봄이간다 수행중, 나머지 미완료 (수행중은 미완료보다 위)")
  DB.turnIns["여름이간다-데스윙"] = { [98172] = now - 100 }
  SlashCmdList["QUESTSTORICHES"]("rich")
  expand(98172)
  rows("잘아타스 추적 펼침")

  print("== 3) 리에드린 주간: 완료한 캐릭터 없이 수행중만 있어도 줄을 그린다 (격냥패딩이 이번 주 접속 때 받아 둠)")
  DB.weeklyOn["격냥패딩-데스윙"] = { t = now - 3600, ids = { [93910] = true } }
  -- 인구학은 지난주에 받아 둔 것만 보였다 (이번 주는 모름 -> 미완료)
  DB.weeklyOn["인구학-데스윙"] = { t = now - 8 * 86400, ids = { [93910] = true } }
  rows("리에드린 주간 줄 생김 (접힘)")
  print("  격냥패딩 리에드린 수행중: " .. tostring(QTR.WeeklyOnQuest("격냥패딩-데스윙", QTR.SILVERMOON_WEEKLY[2], time() - 15 * 3600)))
  print("  인구학 리에드린 수행중 (지난주 기록): " .. tostring(QTR.WeeklyOnQuest("인구학-데스윙", QTR.SILVERMOON_WEEKLY[2], time() - 15 * 3600)))

  print("== 4) 봄이간다가 잘아타스 추적을 포기 (QUEST_REMOVED) -> 미완료")
  ONQUEST[98172] = nil
  QTR:QUEST_REMOVED("QUEST_REMOVED", 98172)
  RunLater()
  print("  봄이간다 weeklyOn 98172: " .. tostring(DB.weeklyOn["봄이간다-데스윙"].ids[98172]))
  rows("잘아타스 추적 (포기 뒤)")

  print("== 5) 다시 받음 (QUEST_ACCEPTED) -> 수행중, 다른 퀘스트를 받으면 기록하지 않음")
  ONQUEST[98172] = true
  QTR:QUEST_ACCEPTED("QUEST_ACCEPTED", 98172)
  local n = #LATER
  QTR:QUEST_ACCEPTED("QUEST_ACCEPTED", 12345)
  print("  실버문 주간이 아닌 퀘스트로 예약된 갱신: " .. (#LATER - n))
  RunLater()
  rows("잘아타스 추적 (다시 받은 뒤)")

  print("== 6) 완료하면 수행중보다 완료가 먼저")
  QTR:QUEST_TURNED_IN("x", 98172, 0, 0)
  rows("잘아타스 추적 (봄이간다 완료)")
  print("== end")
end''')(addon, out)
