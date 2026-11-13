# 리에드린 주간 93766 "Midnight: World Quests" (2026-11-14 사용자 제보: 인구학이 이번 주 리에드린 퀘스트를 했는데 부자되기 탭에 없음)
#   목록에 없던 ID라 완료 기록(turnIns)이 남지 않고 최정상 보관함 받은 기록(cacheGets의 q=93766)만 남았다.
#   목록에 넣고, 실버문 주간은 보관함 받은 기록도 이번 주 완료로 본다 (run79 준비 부분 사용)
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
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["격냥패딩-데스윙"] = { money = 1, class = "PALADIN", level = 90 },
              ["인구학-데스윙"] = { money = 1, class = "MAGE", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash", chatNotify = true },
    cacheGets = {
      ["인구학-데스윙"] = { { id = 279527, n = 1, t = now - 600, q = 93766 } },          -- 이번 주 (인구학 실제 기록과 같은 모양)
      ["격냥패딩-데스윙"] = { { id = 279527, n = 1, t = now - 8 * 86400, q = 93766 } },  -- 지난주
    },
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


  print("== 1) 93766이 리에드린 칸에 있음: " .. tostring(QTR.SILVERMOON_WEEKLY_IDS[93766]) .. ", 완료 표시 안 믿음: " .. tostring(QTR.SILVERMOON_NOFLAG_IDS[93766]))
  local W
  for _, w in ipairs(QTR.SILVERMOON_WEEKLY) do if w.key == "liadrin" then W = w end end
  local since = now - 3 * 86400
  local t, q = QTR.WeeklyDoneTime("인구학-데스윙", W, since)
  print("== 2) 인구학: 보관함 받은 기록으로 이번 주 완료 " .. tostring(t == now - 600) .. " (퀘스트 " .. tostring(q) .. ")")
  print("  격냥패딩: 이번 주 완료 " .. tostring(QTR.WeeklyDoneTime("격냥패딩-데스윙", W, since)))
  -- 2026-11-14 사용자 제보: 2주 주기는 모두 같다 (10-29 주 시작, 11-12 주 새 주기). 주기 첫째 주에는 "지난주 완료"로 빼지 않는다
  local WK = 7 * 86400
  local ws1 = W.cycleRef - 3600          -- 주기 첫째 주의 시작 (cycleRef가 든 주)
  print("== 2b) 2주 주기 (cycleRef " .. os.date("%m-%d %H시", W.cycleRef) .. ")")
  DB.cacheGets["격냥패딩-데스윙"] = { { id = 279527, n = 1, t = ws1 + 1000, q = 93913 } }
  print("  첫째 주에 한 캐릭터, 둘째 주에 보면 지난주 완료: " .. tostring(QTR.WeeklyLastWeek("격냥패딩-데스윙", W, ws1 + WK) ~= nil))
  DB.cacheGets["격냥패딩-데스윙"] = { { id = 279527, n = 1, t = ws1 + WK + 1000, q = 93909 } }
  print("  둘째 주에 한 캐릭터(상암동누렁스 11-11), 새 주기 첫째 주에 보면 지난주 완료: " .. tostring(QTR.WeeklyLastWeek("격냥패딩-데스윙", W, ws1 + 2 * WK) ~= nil))
  DB.cacheGets["격냥패딩-데스윙"] = { { id = 279527, n = 1, t = ws1 + 2 * WK + 1000, q = 93766 } }
  print("  다음 주기 첫째 주에 한 캐릭터, 그 둘째 주에 보면 지난주 완료: " .. tostring(QTR.WeeklyLastWeek("격냥패딩-데스윙", W, ws1 + 3 * WK) ~= nil))
  DB.cacheGets["격냥패딩-데스윙"] = { { id = 279527, n = 1, t = now - 8 * 86400, q = 93766 } }
  SlashCmdList["QUESTSTORICHES"]("rich")
  rows("3) 부자되기 탭: 리에드린 줄 인구학 완료 1/3 (격냥패딩 기록은 8일 전이라 실제 주간 경계로는 지난주 밖)")
  print("== end")
end''')(addon, out)
