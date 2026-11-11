# 만렙이 본 골드퀘만 부자되기 탭과 다음 추천에 (2026-11-11 사용자 결정): 84레벨 마래푸누렁스만 본 레벨업용 "어둠의 군대"(92566)가
#   만렙 기준 부자되기 탭에 0/7로 나왔다. 본 캐릭터 기록이 없는 예전 항목은 그대로
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness3.lua', encoding='utf-8').read())
# 다음 추천 캐릭터의 직업 선호와 추천 이유 툴팁 (2026-11-08 사용자 요청): 곧 끝나는 퀘스트 기준 다음, 골드보다 먼저.
#   추천 줄에는 글을 붙이지 않고 캐릭터 이름에 마우스를 올리면 이유 툴팁
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
  local now = time()
  QuestsToRichesDB = {
    chars = {
      ["봄이간다-데스윙"] = { level = 90, class = "WARRIOR", realm = "데스윙" },
      ["드루-데스윙"] = { level = 90, class = "DRUID", realm = "데스윙" },
      ["마래푸누렁스-아즈샤라"] = { level = 84, class = "DRUID", realm = "아즈샤라" },
    },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  GetMaxLevelForPlayerExpansion = function() return 90 end
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local now = time()
  local DB = QuestsToRichesDB
  local function clean(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "")) end
  DB.activeGQ = {
    [1] = { name = "만렙이 본 퀘", zone = "공허폭풍", money = 10000000, expire = now + 3 * 3600, seenBy = { ["봄이간다-데스윙"] = now } },
    [92566] = { name = "어둠의 군대", zone = "공허폭풍", money = 10553782, expire = now + 2 * 86400,
      seenBy = { ["마래푸누렁스-아즈샤라"] = now }, hiddenFor = { ["봄이간다-데스윙"] = true } },
    [3] = { name = "예전 항목 (본 캐릭터 기록 없음)", zone = "줄아만", money = 9000000, expire = now + 4 * 3600 },
    [4] = { name = "둘 다 본 퀘", zone = "하란다르", money = 8000000, expire = now + 5 * 3600,
      seenBy = { ["마래푸누렁스-아즈샤라"] = now, ["드루-데스윙"] = now } },
  }
  print("== 1) 다음 추천: 드루 (남은 골드에 어둠의 군대는 빠짐 -> 1,000 + 900 + 800 = 2,700)")
  print("  " .. clean(QTR.RecommendText()))
  print("== 2) 부자되기 탭: 어둠의 군대는 목록에 없음")
  QuestsToRiches_ToggleDashboard()
  for _, fs in ipairs(out) do fs._text = "" end
  QTR:Refresh()
  for _, fs in ipairs(out) do
    if type(fs._text) == "string" and (fs._text:find("퀘") or fs._text:find("골드퀘")) then print("  " .. clean(fs._text)) end
  end
  print("== 3) 마래푸가 90이 되어도 레벨업용으로 본 것이라 나오지 않음 (볼 때 레벨로 판단, 2026-11-11 사용자 지적)")
  DB.chars["마래푸누렁스-아즈샤라"].level = 90
  for _, fs in ipairs(out) do fs._text = "" end
  QTR:Refresh()
  for _, fs in ipairs(out) do
    if type(fs._text) == "string" and fs._text:find("어둠의 군대") then print("  " .. clean(fs._text)) end
  end
  print("  seenMax: 92566=" .. tostring(DB.activeGQ[92566].seenMax) .. ", 예전 항목=" .. tostring(DB.activeGQ[3].seenMax) .. ", 둘 다 본 퀘=" .. tostring(DB.activeGQ[4].seenMax))
end''')(addon, out)
