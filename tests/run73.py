# 특별 과제 만료 시각 (2026-11-01 사용자 제보: 망령과 발톱이 만료된 뒤 남은 시간이 주간 초기화 시각으로 바뀌어 계속 보임)
#   잠김 상태용 퀘스트의 시간은 특별 과제보다 길 수 있다. 특별 과제 자체에서 읽은 만료 시각(expireSeen)을 따르고,
#   그 시각이 이번 주에 지났으면 초기화 전까지는 끝난 것으로 본다 (줄이 사라짐). 초기화 뒤에는 잠김 상태용 시간을 다시 믿는다
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
C_Map = { GetMapInfo = function(id) return { name = (id == 2395) and "영원노래 숲" or "실버문" } end, GetBestMapForUnit = function() return 9999 end }
LOCKED = true
TITLES = { [92145] = "특별 과제: 그림자와 발톱", [80001] = "보통 전역퀘" }
C_TaskQuest = {
  GetQuestsOnMap = function(mapID)
    if mapID ~= 2395 then return {} end
    local r = { { questID = 80001, mapID = 2395, x = 0.4, y = 0.4 } }
    if not LOCKED then table.insert(r, { questID = 92145, mapID = 2395, x = 0.5, y = 0.5 }) end
    return r
  end,
  GetQuestInfoByQuestID = function(id)
    if id == 92145 and GetLocale() ~= "koKR" then return "Special Assignment: 그림자와 발톱" end -- 영어 클라이언트 시험용
    return TITLES[id]
  end,
  GetQuestTimeLeftSeconds = function(id) if id == 80001 or id == 92848 or id == 92145 then return 3 * 86400 end return nil end,
  GetQuestZoneID = function() return 2395 end,
}
function GetQuestLogRewardMoney(id) return 0 end
function GetNumQuestLogRewards(id) return 0 end
function GetQuestLogRewardInfo(i, id) return nil end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return false end
C_QuestLog.GetQuestTagInfo = function(id) return {} end
C_QuestLog.IsWorldQuest = function(id) return true end
ONQUEST = {}
C_QuestLog.IsOnQuest = function(id) return ONQUEST[id] == true end
OBJ = {}
C_QuestLog.GetQuestObjectives = function(id) return OBJ[id] end
function GetQuestProgressBarPercent(id) return 40.5 end
C_AreaPoiInfo = {
  GetAreaPOIForMap = function(mapID) if LOCKED and mapID == 2395 then return { 500 } end return {} end,
  GetAreaPOIInfo = function(mapID, id)
    if id == 500 then return { atlasName = "worldquest-Capstone-questmarker", isPrimaryMapForPOI = true, tooltipWidgetSet = 77,
      name = "특별 과제: 그림자와 발톱", position = { x = 0.5, y = 0.5 }, areaPoiID = 500 } end
  end,
}
C_UIWidgetManager = {
  GetTextWithStateWidgetVisualizationInfo = function(id) if id == 7710 and LOCKED then return { text = "2" } end return nil end,
  GetAllWidgetsBySetID = function(setID) if setID == 77 then return { { widgetID = 7710 } } end return {} end,
}
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
  local base = time()
  local OFF = 0
  time = function(t) if t then return os.time(t) end return base + OFF end
  local RESET = base + 9 * 3600 + 6 * 86400
  C_DateAndTime.GetSecondsUntilWeeklyReset = function() return RESET - time() end
  TLEND = { [92139] = base + 25 * 3600, [95435] = RESET, [94865] = RESET }
  C_TaskQuest.GetQuestTimeLeftSeconds = function(id) local e = TLEND[id]; if e and e > time() then return e - time() end return nil end
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash" },
    cacheSources = {
      q92139 = { kind = "quest", questID = 92139, title = "특별 과제: 망령과 발톱", zone = "영원노래 숲", itemID = 279520, onMap = true, lastSeen = base, learned = base - 86400, via = "map" },
      q91390 = { kind = "quest", questID = 91390, title = "특별 과제: 부서진 사원의 잔재", zone = "줄아만", itemID = 279520, onMap = true, lastSeen = base, learned = base - 86400, via = "map" },
    },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local strip = function(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
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
      if s:find("정점 보관함") == 1 or s:find("Pinnacle Caches") == 1 then on = true end
      if on then print("    " .. s) end
    end
    for _, fs in ipairs(cells) do
      if lasty and fs._y ~= lasty then flush(); line = {} end
      lasty = fs._y; table.insert(line, strip(fs._text))
    end
    if #line > 0 then flush() end
  end
  local function seen() local s = DB.cacheSources.q92139; return "expireSeen=" .. tostring(s.expireSeen) .. " expire-base=" .. tostring(s.expire and (s.expire - base)) end

  SlashCmdList["QUESTSTORICHES"]("rich")
  print("== 1) 망령과 발톱이 지도에 떠 있음 (25시간 남음), 부서진 사원의 잔재는 잠김 상태용 시간만 (초기화까지)")
  rows("처음")
  print("  " .. seen())
  print("== 2) 1시간 뒤, 특별 과제 자체 시간은 못 읽고 잠김 상태용 시간(초기화까지)만 읽힘 -> 읽어 둔 만료 시각대로 24시간")
  OFF = 3600; TLEND[92139] = nil
  rows("1시간 뒤")
  print("  " .. seen())
  print("== 3) 26시간 뒤 (만료 지남, 잠김 상태용 시간은 아직 남음) -> 망령과 발톱 줄이 사라짐")
  OFF = 26 * 3600
  rows("만료 뒤")
  print("  남은 시간: " .. tostring(QTR.GetSpecialTimeLeft(92139)) .. " / " .. seen())
  print("== 4) 주간 초기화 뒤 다시 잠김 상태용 시간이 읽힘 -> 새 회차로 봄")
  OFF = RESET - base + 3600
  local RESET2 = RESET + 7 * 86400
  RESET = RESET2
  TLEND[95435] = RESET2; TLEND[94865] = RESET2
  rows("초기화 뒤")
  print("  " .. seen())
  print("== end")
end''')(addon, out)
