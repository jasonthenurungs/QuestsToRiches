# 리에드린 주간 완료 표시를 믿지 않기 (2026-11-05 사용자 제보: 리에드린 주간이 없는 주인데 '완료'로 나옴)
#   게임이 10종을 한꺼번에 완료로 답해 접속 시각에 모두 완료로 남았다. 예전 기록은 불러올 때 지우고, 새로 남기지 않는다.
#   잘아타스 추적은 완료 표시를 그대로 믿는다. 실제 완료(QUEST_TURNED_IN)는 그대로 완료 (run69 준비 부분 사용)
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
  ALLFLAG = false
  local LIADRIN = { 93913, 93769, 93889, 93890, 93891, 93892, 93909, 93910, 93911, 93912 }
  local function all(t) local r = {} for _, q in ipairs(LIADRIN) do r[q] = t end return r end
  local fy = all(now - 3600); fy[98172] = now - 3600
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["여름이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["격냥패딩-데스윙"] = { money = 1, class = "PALADIN", level = 90 },
              ["인구학-데스윙"] = { money = 1, class = "MAGE", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash", chatNotify = true },
    flagDone = { ["여름이간다-데스윙"] = fy, ["격냥패딩-데스윙"] = all(now - 7200) },
  }
  C_QuestLog.IsQuestFlaggedCompleted = function(id) return ALLFLAG end
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


  print("== 1) 지난주처럼 리에드린 10종이 접속 시각에 한꺼번에 '완료'로 남은 저장 데이터 -> 불러올 때 지운다 (잘아타스는 남김)")
  local n, xal = 0, DB.flagDone["여름이간다-데스윙"] and DB.flagDone["여름이간다-데스윙"][98172]
  for _, list in pairs(DB.flagDone) do for q in pairs(list) do if q ~= 98172 then n = n + 1 end end end
  print("  남은 리에드린 flagDone: " .. n .. " / 여름이간다 잘아타스 flagDone 남음: " .. tostring(xal ~= nil))
  print("== 2) 지금 캐릭터도 게임이 리에드린 10종 모두 완료로 답함 -> 완료로 세지 않음, 기록도 안 함")
  ALLFLAG = true
  QTR.ScanWeeklyFlags()
  local f = DB.flagDone["봄이간다-데스윙"]
  print("  봄이간다 flagDone 93913: " .. tostring(f and f[93913]) .. " / 98172(잘아타스, 그대로 믿음): " .. tostring(f and f[98172] ~= nil))
  SlashCmdList["QUESTSTORICHES"]("rich")
  rows("리에드린 줄 없음 (이번 주 실제 완료, 수행중 없음), 잘아타스는 여름이간다(표시)와 봄이간다(지금 표시)")
  print("== 3) 실제로 완료(QUEST_TURNED_IN)하면 그때부터 완료")
  QTR:QUEST_TURNED_IN("x", 93913, 0, 0)
  rows("리에드린 줄: 봄이간다 완료 1/4")
  print("== end")
end''')(addon, out)
