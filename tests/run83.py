# 내비게이션 시작 단축키 (2026-11-08 사용자 요청: 창 열기, 1, R을 한 번에)
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
    days = {}, turnIns = {}, settings = { tab = "dash", chatNotify = true, keys = { route = "ALT-SHIFT-R", navStart = "ALT-SHIFT-N" } },
    flagDone = {},
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


  print("== 1) 설정에 저장한 키를 접속 때 덮어쓰기 바인딩으로 적용")
  print("  ALT-SHIFT-N -> " .. tostring(BINDS["ALT-SHIFT-N"]) .. " / ALT-SHIFT-R -> " .. tostring(BINDS["ALT-SHIFT-R"]))
  print("  게임 키 설정 화면 이름: " .. tostring(BINDING_NAME_QUESTSTORICHES_NAVSTART))
  print("== 2) 단축키 = 내비게이션 시작! 버튼 (경로 짜기, 내비게이션 창, 대시보드 닫기)")
  local calls = {}
  local rs, pu = QTR.RouteStart, QTR.RoutePopupUpdate
  QTR.RouteStart = function(...) table.insert(calls, "RouteStart") end
  QTR.RoutePopupUpdate = function(force) table.insert(calls, "RoutePopupUpdate(" .. tostring(force) .. ")") end
  SlashCmdList["QUESTSTORICHES"]("gq")
  print("  대시보드 열림: " .. tostring(QuestsToRichesFrame:IsShown()))
  QuestsToRiches_StartNav()
  print("  부른 것: " .. table.concat(calls, ", "))
  print("  대시보드 열림: " .. tostring(QuestsToRichesFrame:IsShown()))
  print("== 3) 창이 닫혀 있어도 같다")
  calls = {}
  QuestsToRiches_StartNav()
  print("  부른 것: " .. table.concat(calls, ", "))
  QTR.RouteStart, QTR.RoutePopupUpdate = rs, pu
  print("== 4) 키를 지우면 바인딩도 빠진다")
  DB.settings.keys.navStart = ""
  QTR:OnEnable()
  print("  ALT-SHIFT-N -> " .. tostring(BINDS["ALT-SHIFT-N"]) .. " / ALT-SHIFT-R -> " .. tostring(BINDS["ALT-SHIFT-R"]))
  print("== end")
end''')(addon, out)
import re as _re
x = open(TD + '../src/QuestsToRiches/Bindings.xml', encoding='utf-8').read()
m = _re.search(r'<Binding name="QUESTSTORICHES_NAVSTART"[^>]*>\s*(.*?)\s*</Binding>', x, _re.S)
print("Bindings.xml NAVSTART: " + (m.group(1) if m else "없음"))
