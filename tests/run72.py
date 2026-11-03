# 내비게이션 기록 보관 수 (2026-11-01 사용자 요청): 기본 최근 10번, /qtr navlog all이면 모두 남김 (개발 PC용), /qtr navlog 10으로 되돌림
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
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local function starts(n) for i = 1, n do QTR.NavLogStart() end end
  print("== 1) 기본: 12번 시작 -> 10번만")
  starts(12)
  print("  " .. #DB.navLog)
  SlashCmdList["QUESTSTORICHES"]("navlog")
  print("== 2) /qtr navlog all 뒤 5번 더 -> 15번")
  SlashCmdList["QUESTSTORICHES"]("navlog all")
  starts(5)
  print("  " .. #DB.navLog .. " / navLogAll " .. tostring(DB.settings.navLogAll))
  print("== 3) /qtr navlog 10: 바로 지우지 않고, 다음 시작 때 10번으로")
  SlashCmdList["QUESTSTORICHES"]("navlog 10")
  starts(1)
  print("  " .. #DB.navLog .. " / navLogAll " .. tostring(DB.settings.navLogAll))
  print("== end")
end''')(addon, out)