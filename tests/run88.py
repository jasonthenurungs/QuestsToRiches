# 로드 완료 메시지에 애드온 버전 (2026-11-08 사용자 요청): TOC의 Version을 읽어 "(v1.6.2)"를 붙이고, 못 읽으면 예전 문구
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
toc = open(TD + '../src/QuestsToRiches/QuestsToRiches.toc', encoding='utf-8').read()
import re as _re
TOCVER = _re.search(r'## Version: *(\S+)', toc).group(1)
lua.execute('TOCVER = "' + TOCVER + '"')
def load(title, setup):
    lua.globals().print("== " + title)
    lua.execute(setup)
    chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
    chunk("QuestsToRiches")
    lua.eval('''function(QTR)
      QuestsToRichesDB = { chars = {}, days = {}, turnIns = {}, settings = {} }
      QTR:OnInitialize(); QTR:OnEnable()
    end''')(addon)
load("1) C_AddOns.GetAddOnMetadata로 TOC 버전을 읽음", 'C_AddOns = { GetAddOnMetadata = function(name, field) if name == "QuestsToRiches" and field == "Version" then return TOCVER end end }; GetAddOnMetadata = nil')
load("2) 예전 전역 함수 GetAddOnMetadata만 있음", 'C_AddOns = nil; function GetAddOnMetadata(name, field) if field == "Version" then return "9.9.9" end end')
load("3) 버전을 못 읽음 -> 예전 문구", 'C_AddOns = nil; GetAddOnMetadata = nil')
load("4) 읽다가 오류 -> 예전 문구", 'C_AddOns = { GetAddOnMetadata = function() error("x") end }')
lua.globals().print("== end")
