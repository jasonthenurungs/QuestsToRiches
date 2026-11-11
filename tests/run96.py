# 직업 선호 세 칸 화면 (2026-11-11 사용자 요청): 선호, 보통, 비선호 칸에 직업 단추. 끌어서 다른 칸에 놓거나
#   왼쪽 클릭은 선호 쪽으로, 오른쪽 클릭은 비선호 쪽으로 한 칸. AceGUI 칸 QTR_ClassTiers (흉내 AceGUI로 만든다)
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
      ["주술-데스윙"] = { level = 90, class = "SHAMAN", realm = "데스윙" },
    },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  -- 흉내 AceGUI: 칸 종류를 등록하면 만드는 함수를 기억한다
  local WIDGETS = {}
  local FAKEGUI = {
    RegisterWidgetType = function(_, name, ctor) WIDGETS[name] = ctor end,
    RegisterAsWidget = function(_, w)
      w.SetHeight = function(self, h) self.h = h end
      w.SetWidth = function(self, v) self:OnWidthSet(v) end
      return w
    end,
  }
  local oldLib = LibStub
  LibStub = function(name, ...) if name == "AceGUI-3.0" then return FAKEGUI end return oldLib(name, ...) end
  GameTooltip = { SetOwner = function() end, Show = function() end, Hide = function() end, AddLine = function() end }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local grp = OPTIONS.args.classGroup.args
  print("== 1) 설정창: 드롭다운 대신 세 칸 칸 하나 (" .. tostring(grp.tiers and grp.tiers.dialogControl) .. "), 직업별 드롭다운 " .. tostring(grp.classDRUID ~= nil))
  local w = WIDGETS["QTR_ClassTiers"]()
  w:OnAcquire()
  w:SetWidth(600)
  local function show(title)
    print("== " .. title)
    for t = 1, 3 do
      local names = {}
      for _, token in ipairs(QTR.CLASS_TOKENS) do
        if QTR.ClassTierOf(token) == t then
          local b = w.chips[token]
          table.insert(names, token .. "@" .. tostring(rawget(b, "_x")) .. "," .. tostring(rawget(b, "_y")))
        end
      end
      print("  " .. tostring(w.boxes[t].title._text) .. ": " .. table.concat(names, " "))
    end
    print("  저장: " .. (DB.settings.classPref and (function() local t = {} for k, v in pairs(DB.settings.classPref) do table.insert(t, k .. "=" .. v) end table.sort(t) return table.concat(t, ",") end)() or "없음"))
  end
  show("2) 처음: 13직업 모두 보통 (두 줄, 7행)")
  local function click(token, button) rawget(w.chips[token], "_scr_OnClick")(w.chips[token], button) end
  click("DRUID", "LeftButton")
  click("HUNTER", "LeftButton")
  click("SHAMAN", "RightButton")
  click("ROGUE", "RightButton")
  show("3) 드루이드, 사냥꾼 왼쪽 클릭 -> 선호, 주술사, 도적 오른쪽 클릭 -> 비선호")
  click("DRUID", "LeftButton")
  click("SHAMAN", "RightButton")
  click("ROGUE", "LeftButton")
  show("4) 끝 칸에서 더 밀어도 그대로, 도적 왼쪽 클릭 -> 보통")
  -- 끌어서 놓기: 비선호 칸 위에서 놓음
  for t = 1, 3 do w.boxes[t].IsMouseOver = function() return t == 3 end end
  rawget(w.chips["MAGE"], "_scr_OnDragStart")(w.chips["MAGE"])
  print("== 5) 마법사를 끄는 중: 따라오는 이름 " .. tostring(w.ghost._shown) .. " " .. tostring(w.ghost.text._text))
  rawget(w.chips["MAGE"], "_scr_OnDragStop")(w.chips["MAGE"])
  click("MAGE", "LeftButton") -- 끌어 놓은 직후의 클릭은 무시
  show("5b) 마법사를 비선호 칸에 놓음 (놓은 직후 클릭은 무시), 따라오는 이름 숨김 " .. tostring(not w.ghost._shown))
  for t = 1, 3 do w.boxes[t].IsMouseOver = function() return false end end
  NOWT = NOWT + 1
  rawget(w.chips["PRIEST"], "_scr_OnDragStop")(w.chips["PRIEST"])
  show("6) 칸 밖에 놓으면 그대로")
  DB.activeGQ = { [1] = { name = "퀘 1", zone = "공허폭풍", money = 10000000, expire = time() + 3600 * 5 } }
  print("== 7) 다음 추천은 선호 드루이드: " .. (QTR.RecommendText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "")))
  grp.reset.func()
  show("8) 모두 보통으로")
end''')(addon, out)
