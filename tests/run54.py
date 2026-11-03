import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness3.lua', encoding='utf-8').read())
# 하부 버튼 단축키: 버튼 글자 표기와 탭별 단축키 (run39 준비 과정을 줄여 씀)
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
lua.eval('''function(QTR)
  QuestsToRichesDB = { chars = {}, days = {}, turnIns = {}, settings = { tab = "dash" } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local f = QuestsToRichesFrame
  local PROP
  rawset(f, "SetPropagateKeyboardInput", function(self, v) PROP = v end)
  -- 버튼 흉내: 처음엔 보이게, Click은 OnClick을 부른다
  local CLICKED
  local names = {}
  for panel, keys in pairs(QTR.panelKeys) do
    for key, btn in pairs(keys) do
      btn._shown = true
      names[btn] = btn._text
      rawset(btn, "Click", function(self) CLICKED = names[self]; local fn = rawget(self, "_scr_OnClick"); if fn then fn(self, "LeftButton") end end)
    end
  end
  -- 버튼 글자(단축키 표기 없음)와 툴팁
  local TIP = {}
  GameTooltip = { SetOwner = function() end, SetText = function(self, t) TIP = { t } end,
    AddLine = function(self, t) table.insert(TIP, t) end, Show = function() end, Hide = function() end }
  local list = {}
  for panel, keys in pairs(QTR.panelKeys) do for key, btn in pairs(keys) do
    rawget(btn, "_scr_OnEnter")(btn)
    table.insert(list, key .. " = " .. btn._text .. " w=" .. tostring(rawget(btn, "_w")) .. "  tip: " .. table.concat(TIP, " / "))
  end end
  table.sort(list)
  for _, s in ipairs(list) do print("label:", s) end

  local statsPanel, holdPanel
  for panel, keys in pairs(QTR.panelKeys) do
    if keys["E"] then statsPanel = panel elseif keys["W"] then holdPanel = panel end
  end
  local NAV = 0
  QTR.RouteStart = function() NAV = NAV + 1 end
  local function press(key)
    CLICKED = nil
    rawget(f, "_scr_OnKeyDown")(f, key)
    print(string.format("  key %-5s clicked=%-10s propagate=%s", key, tostring(CLICKED), tostring(PROP)))
  end
  local function wheel(panel, delta)
    CLICKED = nil
    rawget(panel, "_scr_OnMouseWheel")(panel, delta)
    print(string.format("  wheel %-3d clicked=%s", delta, tostring(CLICKED)))
  end
  QuestsToRiches_ToggleDashboard()
  print("== gq tab")
  SlashCmdList["QUESTSTORICHES"]("gq")
  press("R"); print("  nav started:", NAV, " dashboard shown:", f._shown)
  f._shown = true
  press("Q"); press("T")
  print("== stats tab")
  SlashCmdList["QUESTSTORICHES"]("stats")
  press("W"); press("E"); press("R"); press("Q")
  press(","); press("."); press("T"); press("N")
  MODKEY = true; press("Q"); MODKEY = false
  wheel(statsPanel, 1); wheel(statsPanel, -1)
  -- 목록 위 휠: 스크롤바가 보이면 목록 스크롤, 숨겨져 있으면 이전/다음
  local orig = QTR.PanelWheel
  local fwd
  QTR.PanelWheel = function(panel, delta) fwd = (panel == statsPanel and "stats" or "other") .. " " .. delta; orig(panel, delta) end
  local n = 0
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "_name") == "ScrollFrame" and rawget(fr, "_scr_OnMouseWheel") then
      n = n + 1
      fwd = nil; SCROLLED = nil
      fr.ScrollBar._shown = false
      rawget(fr, "_scr_OnMouseWheel")(fr, 1)
      local hiddenRes = tostring(fwd) .. "/" .. tostring(SCROLLED)
      fwd = nil; SCROLLED = nil
      fr.ScrollBar._shown = true
      rawget(fr, "_scr_OnMouseWheel")(fr, -1)
      print("  list", n, "bar hidden ->", hiddenRes, " bar shown ->", tostring(fwd) .. "/" .. tostring(SCROLLED))
    end
  end
  QTR.PanelWheel = orig
  print("== hold tab")
  SlashCmdList["QUESTSTORICHES"]("hold")
  press("W"); print("  holdMode:", QuestsToRichesDB.settings.holdMode)
  wheel(holdPanel, 1)
  press("Q"); print("  holdMode:", QuestsToRichesDB.settings.holdMode)
  press("E")
  -- 요약 보기에서는 상세 보기 버튼이 숨겨지므로 키와 휠 모두 눌리지 않아야 한다
  QTR.panelKeys[holdPanel][","]._shown = false
  press(",")
  wheel(holdPanel, 1)
  press("1")
  print("tab now:", QuestsToRichesDB.settings.tab)
end''')(addon)
