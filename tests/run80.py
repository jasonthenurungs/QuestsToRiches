# 주간 초기화를 넘겨 남는 특별 과제 (2026-11-05 사용자 제보: 대마법학자의 음료가 초기화 뒤 부자되기 탭에서 사라졌다가,
#   그 특별 과제를 해금한 캐릭터가 생기자 다시 나타남)
#   원인: 지도에서 특별 과제 남은 시간을 못 읽으면 "주간 초기화까지"로 어림하는데, 이 어림값이 퀘스트에서 읽은 만료 시각(expireSeen)으로
#   저장되어, 초기화 뒤 "이번 주에 이미 끝난 특별 과제"로 보고 숨겼다. 이제 어림값은 만료 시각으로 남기지 않는다.
#   지금 지도에 떠 있는데 저장된 만료 시각이 지났으면 그 시각을 지운다 (예전 버전이 남긴 값) (run73 준비 부분 사용)
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
function GetNumQuestLogRewards(id) return (id == 92145) and 1 or 0 end
function GetQuestLogRewardInfo(i, id) if id == 92145 then return "x", 1, 1, 1, true, 279520 end return nil end
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
  TLEND = { [92848] = RESET + 7 * 86400 } -- 잠김 상태용 퀘스트(대마법학자의 음료 92145의 unlock)는 다음 초기화 뒤까지
  C_TaskQuest.GetQuestTimeLeftSeconds = function(id) local e = TLEND[id]; if e and e > time() then return e - time() end return nil end
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash" },
    cacheSources = {},
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
  local function seen() local s = DB.cacheSources.q92145 or {}; return "expireSeen=" .. tostring(s.expireSeen) .. " expire-base=" .. tostring(s.expire and (s.expire - base)) end

  LOCKED = false
  SlashCmdList["QUESTSTORICHES"]("gq")
  print("== 1) 해금된 캐릭터가 지도에서 봄, 특별 과제 자체 남은 시간은 못 읽음 -> 어림값(초기화까지)은 만료 시각으로 남기지 않음")
  QTR.forceScan = true
  rows("골드퀘 탭")
  print("  " .. seen())
  print("== 2) 주간 초기화 뒤, 다른 캐릭터(잠김)로 봄. 잠김 상태용 시간만 읽힘 -> 이번 주 특별 과제로 보고 부자되기 탭에 남음")
  LOCKED = true
  OFF = RESET - base + 3600
  RESET = RESET + 7 * 86400
  SlashCmdList["QUESTSTORICHES"]("rich")
  rows("부자되기 탭 (초기화 뒤)")
  print("  남은 시간 출처: " .. tostring(select(2, QTR.GetSpecialTimeLeft(92145))))
  print("== 3) 예전 버전이 초기화 시각을 만료 시각으로 남긴 상태 -> 초기화 뒤 숨는 문제(고치기 전 동작)")
  DB.cacheSources.q92145.expire = time() - 3600; DB.cacheSources.q92145.expireSeen = true
  rows("부자되기 탭 (예전 값, 숨음)")
  print("== 4) 해금된 캐릭터로 지도에서 다시 봄 (시간은 여전히 못 읽음) -> 지난 만료 시각을 지우고 다시 보임")
  LOCKED = false
  SlashCmdList["QUESTSTORICHES"]("gq")
  QTR.forceScan = true
  rows("골드퀘 탭")
  print("  " .. seen())
  LOCKED = true
  SlashCmdList["QUESTSTORICHES"]("rich")
  rows("부자되기 탭")
  print("== end")
end''')(addon, out)
