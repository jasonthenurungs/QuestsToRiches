# 직업 선호 세 칸 화면 (2026-11-11 사용자 요청): 선호, 보통, 비선호 칸에 직업 단추. 끌어서 다른 칸에 놓기만 (클릭으로 옮기기는 뺌)
#   끄는 동안 커서 아래 칸 테두리 노랑, "모두 보통으로" 단추는 보통 칸 아래 가운데, 처음 차례는 판금-사슬-가죽-천 안에서 이름순,
#   옮긴 직업은 옮긴 차례대로 칸 맨 끝. AceGUI 칸 QTR_ClassTiers (흉내 AceGUI로 만든다)
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
  LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "전사", PALADIN = "성기사", HUNTER = "사냥꾼", ROGUE = "도적", PRIEST = "사제",
    DEATHKNIGHT = "죽음의 기사", SHAMAN = "주술사", MAGE = "마법사", WARLOCK = "흑마법사", MONK = "수도사", DRUID = "드루이드",
    DEMONHUNTER = "악마사냥꾼", EVOKER = "기원사" }
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
  function GetCursorPosition() return 100, 100 end
  UIParent.GetEffectiveScale = function() return 1 end
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local grp = OPTIONS.args.classGroup.args
  print("== 1) 설정창: 세 칸 칸 하나 (" .. tostring(grp.tiers and grp.tiers.dialogControl) .. "), 설정창의 따로 된 '모두 보통으로' " .. tostring(grp.reset ~= nil))
  local w = WIDGETS["QTR_ClassTiers"]()
  w:OnAcquire()
  w:SetWidth(600)
  print("  높이 " .. tostring(w.h) .. ", '모두 보통으로' 단추: " .. tostring(w.reset._text) .. " 보통 칸 아래 " .. tostring(rawget(w.reset, "_x")) .. "," .. tostring(rawget(w.reset, "_y")))
  print("  직업 단추 클릭으로 옮기기: " .. tostring(rawget(w.chips.DRUID, "_scr_OnClick") ~= nil))
  local function show(title)
    print("== " .. title)
    for t = 1, 3 do
      local names = {}
      for _, token in ipairs(QTR.ClassTierList(t)) do
        local b = w.chips[token]
        table.insert(names, LOCALIZED_CLASS_NAMES_MALE[token] .. "@" .. tostring(rawget(b, "_x")) .. "," .. tostring(rawget(b, "_y")))
      end
      print("  " .. tostring(w.boxes[t].title._text) .. ": " .. table.concat(names, " "))
    end
  end
  local function drag(token, t)
    for k = 1, 3 do w.boxes[k].IsMouseOver = function() return k == t end end
    rawget(w.chips[token], "_scr_OnDragStart")(w.chips[token])
    rawget(w.ghost, "_scr_OnUpdate")(w.ghost)
    local lit = {}
    for k = 1, 3 do table.insert(lit, tostring(rawget(w.boxes[k], "lit") or false)) end
    rawget(w.chips[token], "_scr_OnDragStop")(w.chips[token])
    local after = {}
    for k = 1, 3 do table.insert(after, tostring(rawget(w.boxes[k], "lit") or false)) end
    return "끄는 중 노랑 테두리 " .. table.concat(lit, "/") .. ", 놓은 뒤 " .. table.concat(after, "/")
  end
  show("2) 처음: 모두 보통, 판금(성기사 전사 죽음의 기사) 사슬(기원사 사냥꾼 주술사) 가죽(도적 드루이드 수도사 악마사냥꾼) 천(마법사 사제 흑마법사)")
  print("  " .. drag("DRUID", 1))
  drag("HUNTER", 1)
  show("3) 드루이드, 사냥꾼 차례로 선호에 놓음 -> 선호: 드루이드, 사냥꾼")
  print("  " .. drag("MONK", 3))
  drag("ROGUE", 3)
  show("4) 수도사, 도적 차례로 비선호 (끄는 동안 비선호만 노랑)")
  drag("DRUID", 2)
  show("5) 드루이드를 다시 보통으로 -> 보통 맨 끝")
  drag("MONK", 3)
  show("6) 수도사를 같은 비선호 칸에 다시 놓음 -> 차례 그대로")
  print("  " .. drag("MAGE", nil))
  show("7) 칸 밖에 놓으면 그대로, 테두리 모두 원래대로")
  DB.activeGQ = { [1] = { name = "퀘 1", zone = "공허폭풍", money = 10000000, expire = time() + 3600 * 5 } }
  print("== 8) 다음 추천 (드루이드 보통, 주술사 보통 -> 이름순 드루): " .. (QTR.RecommendText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "")))
  rawget(w.reset, "_scr_OnClick")(w.reset)
  show("9) 모두 보통으로 -> 처음 차례")
  print("  저장: " .. tostring(DB.settings.classPref) .. " " .. tostring(DB.settings.classOrder))
end''')(addon, out)
