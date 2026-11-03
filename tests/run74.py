# 보유량 상세 전일비 칸 (2026-11-02 사용자 요청): 10만 골드부터 "+204k"처럼 줄인다 (버림), 그 아래와 윗줄 합계는 그대로
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness3.lua', encoding='utf-8').read())
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
C_Item = { GetItemSpell = function() return nil end, GetItemCount = function() return 0 end, GetItemIconByID = function() return 1 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end }
function hooksecurefunc() end
C_EventUtils = { IsEventValid = function() return false end }
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval('''function(QTR, out)
  QuestsToRichesDB = { chars = {}, days = {}, turnIns = {}, settings = { tab = "dash" } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local G = 10000
  local today = date("%Y-%m-%d", time())
  local yest = date("%Y-%m-%d", time() - 86400)
  local names = { "가", "나", "다", "라", "마", "바", "사" }
  for _, n in ipairs(names) do QuestsToRichesDB.chars[n .. "-데스윙"] = { level = 90, class = "WARRIOR" } end
  -- 가 +204,000 / 나 +99,999 (그대로) / 다 +100,000 경계 / 라 -150,500 / 마 +1,234,567 / 바 +0 / 사 +199,999 (버림 199k)
  QuestsToRichesDB.holdDays = {
    [yest] = { chars = { ["가-데스윙"] = 1163420 * G, ["나-데스윙"] = 1 * G, ["다-데스윙"] = 5 * G, ["라-데스윙"] = 200000 * G,
                         ["마-데스윙"] = 10 * G, ["바-데스윙"] = 7 * G, ["사-데스윙"] = 3 * G }, warband = 0 },
    [today] = { chars = { ["가-데스윙"] = 1367420 * G, ["나-데스윙"] = 100000 * G, ["다-데스윙"] = 100005 * G, ["라-데스윙"] = 49500 * G,
                          ["마-데스윙"] = 1234577 * G, ["바-데스윙"] = 7 * G, ["사-데스윙"] = 200002 * G }, warband = 0 },
  }
  QuestsToRichesDB.settings.holdMode = "detail"
  for _, fs in ipairs(out) do fs._text = "" end
  SlashCmdList["QUESTSTORICHES"]("hold")
  QTR:Refresh()
  local cells = {}
  for _, fs in ipairs(out) do if type(fs._text) == "string" and fs._text ~= "" and rawget(fs, "_y") and rawget(fs, "_y") <= 0 and rawget(fs, "_x") and rawget(fs, "_x") >= 0 and rawget(fs, "_x") < 420 then table.insert(cells, fs) end end
  table.sort(cells, function(a, b) if a._y ~= b._y then return a._y > b._y end return a._x < b._x end)
  local line, lasty = {}, nil
  local function clean(t) return (t:gsub("|TInterface\\\\MoneyFrame[^|]*|t", "G"):gsub("|TInterface[^|]*|t", "o"):gsub("\\226\\150\\178", "UP"):gsub("\\226\\150\\188", "DN")) end
  print("== hold detail")
  for _, fs in ipairs(cells) do
    if lasty and fs._y ~= lasty then print("  " .. table.concat(line, " | ")); line = {} end
    lasty = fs._y; table.insert(line, rawget(fs, "_x") .. ":" .. clean(fs._text))
  end
  print("  " .. table.concat(line, " | "))
  print("== end")
end''')(addon, out)
