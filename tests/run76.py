# 이 계정 보유량에 전투부대 은행 넣지 않기 (2026-11-03 사용자 결정, SF작가님 요청)
#   기록은 은행 포함 그대로, 보여 줄 때만 뺀다: 머리 영역(진행률, 순증), 보유량 요약/상세, /qtr list, 새 기록은 계속 은행 포함
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
PRINTS = {}
print = function(s) table.insert(PRINTS, s) end
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval('''function(QTR, out)
  QuestsToRichesDB = { chars = {}, days = {}, turnIns = {}, settings = { tab = "dash", goal = 1000000 } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local G = 10000
  local DB = QuestsToRichesDB
  local function day(n) return date("%Y-%m-%d", time() - n * 86400) end
  DB.chars = { ["가-데스윙"] = { level = 90, class = "WARRIOR", money = 300000 * G },
               ["나-데스윙"] = { level = 90, class = "MAGE", money = 100000 * G } }
  DB.warbandMoney = 200000 * G
  -- 4일 전: 은행 기록 전(날짜별 기록을 만들기 전 합계, 그때 은행 150,000) / 2일 전: 은행 150,000 / 오늘: 은행 200,000
  DB.snapshots = { [day(4)] = 350000 * G, [day(2)] = 450000 * G, [day(0)] = 600000 * G }
  DB.holdDays = {
    [day(2)] = { chars = { ["가-데스윙"] = 250000 * G, ["나-데스윙"] = 50000 * G }, warband = 150000 * G },
    [day(0)] = { chars = { ["가-데스윙"] = 300000 * G, ["나-데스윙"] = 100000 * G }, warband = 200000 * G },
  }
  local function clean(t) return (t:gsub("|TInterface\\\\MoneyFrame[^|]*|t", "G"):gsub("|TInterface[^|]*|t", "o"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local function dump(title)
    QTR:Refresh()
    local cells = {}
    for _, fs in ipairs(out) do if type(fs._text) == "string" and fs._text ~= "" and rawget(fs, "_y") and rawget(fs, "_y") <= 0 and rawget(fs, "_x") and rawget(fs, "_x") >= 0 and rawget(fs, "_x") < 420 then table.insert(cells, fs) end end
    table.sort(cells, function(a, b) if a._y ~= b._y then return a._y > b._y end return a._x < b._x end)
    print_ = _G.rawprint or nil
    local lines, line, lasty = {}, {}, nil
    for _, fs in ipairs(cells) do
      if lasty and fs._y ~= lasty then table.insert(lines, "  " .. table.concat(line, " | ")); line = {} end
      lasty = fs._y; table.insert(line, clean(fs._text))
    end
    table.insert(lines, "  " .. table.concat(line, " | "))
    table.insert(PRINTS, "== " .. title)
    for _, l in ipairs(lines) do table.insert(PRINTS, l) end
    -- 머리 영역 (창 위쪽 글자): 진행률 막대, 순증
    for _, fs in ipairs(out) do
      local t = type(fs._text) == "string" and fs._text or ""
      if t:find("순증") or t:find("%(%d+%.%d+%%%)") then table.insert(PRINTS, "  [hdr] " .. clean(t)) end
    end
  end
  local function shot(tag)
    for _, fs in ipairs(out) do fs._text = "" end
    SlashCmdList["QUESTSTORICHES"]("hold")
    DB.settings.holdMode = "sum"; dump(tag .. " sum")
    for _, fs in ipairs(out) do fs._text = "" end
    DB.settings.holdMode = "detail"; dump(tag .. " detail")
    SlashCmdList["QUESTSTORICHES"]("list")
  end
  table.insert(PRINTS, "SnapshotAt on: " .. QTR.SnapshotAt(day(4)) / G .. " " .. QTR.SnapshotAt(day(2)) / G .. " " .. QTR.SnapshotAt(day(0)) / G)
  shot("ON(기본)")
  DB.settings.holdNoWarband = true
  table.insert(PRINTS, "SnapshotAt off: " .. QTR.SnapshotAt(day(4)) / G .. " " .. QTR.SnapshotAt(day(2)) / G .. " " .. QTR.SnapshotAt(day(0)) / G)
  shot("OFF")
  -- 꺼 둔 상태에서 새 기록: snapshots는 은행 포함으로 남아야 한다
  DB.chars["봄이간다-데스윙"] = DB.chars["봄이간다-데스윙"] or { level = 90, class = "WARRIOR" }
  QTR:PLAYER_MONEY()
  table.insert(PRINTS, "recorded today (raw): " .. DB.snapshots[day(0)] / G .. " / shown: " .. QTR.SnapshotAt(day(0)) / G)
end''')(addon, out)
for s in lua.globals().PRINTS.values():
    print(s)
