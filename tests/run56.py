import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness3.lua', encoding='utf-8').read())
# 설정창 배치, 내비게이션 창 흐리게, 귀환석 장난감 감지 (run54 준비 부분을 그대로 씀)
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
C_Item = { GetItemSpell = function(id) if id == 228940 then return "x", 999001 end return nil end, GetItemCount = function() return 0 end, GetItemIconByID = function() return 1 end, GetItemIDByGUID = function() return nil end,
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
  QuestsToRichesDB = { chars = {}, days = {}, turnIns = {}, settings = { tab = "dash" } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  -- 설정창: 묶음 순서와 묶음 안 항목 (순서, 종류, 폭, 이름)
  local function sorted(args)
    local list = {}
    for k, v in pairs(args) do table.insert(list, { k = k, v = v }) end
    table.sort(list, function(a, b) return (a.v.order or 100) < (b.v.order or 100) end)
    return list
  end
  for _, g in ipairs(sorted(OPTIONS.args)) do
    print("[" .. tostring(g.v.order) .. "] " .. tostring(g.v.name))
    for _, it in ipairs(sorted(g.v.args or {})) do
      local name = type(it.v.name) == "function" and "(fn)" or tostring(it.v.name)
      if it.v.type == "description" and name ~= "" then name = "(설명)" end
      print(string.format("    %-5s %-11s %-5s %s", tostring(it.v.order), it.v.type, tostring(it.v.width), name))
    end
  end
  -- 내비게이션 창 흐리게
  local pop = QuestsToRichesRouteFrame
  local A = 1
  rawset(pop, "GetAlpha", function() return A end)
  rawset(pop, "SetAlpha", function(_, a) A = a end)
  local OVER = false
  rawset(pop, "IsMouseOver", function() return OVER end)
  local upd = rawget(pop, "_scr_OnUpdate")
  local function run(sec) for i = 1, sec * 20 do upd(pop, 0.05) end return string.format("%.2f", A) end
  print("fade off:", run(1))
  QuestsToRichesDB.settings.navFade = true
  print("fade on, mouse away (0.1s):", run(0.1), " after 1s:", run(1))
  OVER = true
  print("mouse over after 1s:", run(1))
  OVER = false
  QuestsToRichesDB.settings.navFadeAlpha = 0.4
  print("alpha 0.4 after 1s:", run(1))
  QuestsToRichesDB.settings.navFade = false
  print("fade turned off after 1s:", run(1))
  -- 귀환석 장난감 (228940의 주문을 999001이라고 흉내): 주문 ID만으로 바로 감지
  QuestsToRichesDB.chars["봄이간다-데스윙"] = QuestsToRichesDB.chars["봄이간다-데스윙"] or {}
  C_Container.GetItemCooldown = function() return 0, 0, 1 end
  LATER = {}
  QTR.OnPlayerSpellcast(999001)
  local me = QuestsToRichesDB.chars["봄이간다-데스윙"]
  print("toy spell -> uses:", #(me.hearthUses or {}))
  NOWT = NOWT + 100
  QTR.OnPlayerSpellcast(12345)
  RunLater()
  print("other spell -> uses:", #(me.hearthUses or {}))
  -- 보유량 상세: 전일비 골드(아이콘 없음)와 순위 등락
  local today = date("%Y-%m-%d", time())
  local yest = date("%Y-%m-%d", time() - 86400)
  QuestsToRichesDB.chars["가-데스윙"] = { level = 90, class = "WARRIOR" }
  QuestsToRichesDB.chars["나-데스윙"] = { level = 90, class = "WARRIOR" }
  QuestsToRichesDB.chars["다-데스윙"] = { level = 90, class = "WARRIOR" }
  QuestsToRichesDB.chars["라-데스윙"] = { level = 90, class = "WARRIOR" }
  QuestsToRichesDB.holdDays = {
    [yest] = { chars = { ["가-데스윙"] = 3000000, ["나-데스윙"] = 2000000, ["다-데스윙"] = 1000000 }, warband = 500000 },
    [today] = { chars = { ["가-데스윙"] = 1500000, ["나-데스윙"] = 2500000, ["다-데스윙"] = 1000000, ["라-데스윙"] = 800000 }, warband = 500000 },
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
end''')(addon, out)
