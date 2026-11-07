# 리에드린 주간: 지난주에 한 캐릭터는 이번 주에 받을 수 없다 (2026-11-07 사용자 제보). '지난주 완료'로 보이고 개수에서 뺀다
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
    cacheGets = {}, flagDone = {},
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


  local W = QTR.SILVERMOON_WEEKLY[2]
  local X = QTR.SILVERMOON_WEEKLY[1]
  local weekStart = now - 15 * 3600 -- 하네스의 주간 초기화까지 6d 9h
  local CACHE = QTR.SILVERMOON_CACHE
  local function show(title)
    print("  -- " .. title)
    for _, k in ipairs({ "봄이간다-데스윙", "여름이간다-데스윙", "격냥패딩-데스윙", "인구학-데스윙" }) do
      local s = QTR.WeeklyDoneTime(k, W, weekStart) and "완료" or strip((QTR.WeeklyState(k, W, weekStart)))
      if s == "" then s = "미완료" end
      print("    " .. k .. ": " .. s .. " / 지난주: " .. tostring(QTR.WeeklyLastWeek(k, W, weekStart) ~= nil)
        .. " / 잘아타스 지난주(skipNext 없음): " .. tostring(QTR.WeeklyLastWeek(k, X, weekStart) ~= nil))
    end
  end

  print("== 1) 지난주에 리에드린을 한 캐릭터는 이번 주 '지난주 완료', 개수에서 뺌 (2026-11-07 사용자 제보)")
  -- 여름이간다: 실버문 주간 ID를 넣기 전처럼 보관함 출처 기록만 (지난주)
  DB.cacheGets["여름이간다-데스윙"] = { { id = CACHE, n = 1, t = weekStart - 2 * 86400, q = 93913 } }
  -- 격냥패딩: QTR 완료 기록 (지난주)
  DB.turnIns["격냥패딩-데스윙"] = { [93913] = weekStart - 86400 }
  -- 인구학: 2주 전 리에드린, 지난주 보관함은 잘아타스 추적 출처, 다른 보관함의 리에드린 출처 -> 지난주 아님
  DB.turnIns["인구학-데스윙"] = { [93913] = weekStart - 8 * 86400, [98172] = now - 100 }
  DB.cacheGets["인구학-데스윙"] = { { id = CACHE, n = 1, t = weekStart - 86400, q = 98172 },
                                   { id = 12345, n = 1, t = weekStart - 86400, q = 93910 } }
  -- 봄이간다(지금 캐릭터): 이번 주 처음 받음
  DB.weeklyOn["봄이간다-데스윙"] = { t = now - 60, ids = { [93909] = true }, prog = { [93909] = { r = 3, f = 0 } } }
  ONQUEST[93909] = true
  SlashCmdList["QUESTSTORICHES"]("rich")
  rows("리에드린 0/2 (4명 중 지난주 2명 뺌), 잘아타스는 1/4 그대로")
  show("캐릭터별")
  print("== 2) 지난주에 했어도 이번 주에 받아 두었으면 수행중 (받을 수 있는 것)")
  DB.weeklyOn["격냥패딩-데스윙"] = { t = now - 60, ids = { [93910] = true } }
  rows("리에드린 0/3")
  show("격냥패딩 수행중")
  print("== 3) 봄이간다가 완료")
  DB.weeklyOn["격냥패딩-데스윙"] = nil
  ONQUEST[93909] = nil
  QTR:QUEST_TURNED_IN("x", 93909, 0, 0)
  rows("리에드린 1/2")
  show("봄이간다 완료")
  print("== 4) 경계: 지난주 시작 직전(2주 전)과 이번 주 시작 직전")
  DB.cacheGets["여름이간다-데스윙"][1].t = weekStart - 7 * 86400 - 1
  DB.turnIns["격냥패딩-데스윙"][93913] = weekStart - 1
  show("여름이간다 지난주 아님, 격냥패딩 지난주")
  print("== end")
end''')(addon, out)
