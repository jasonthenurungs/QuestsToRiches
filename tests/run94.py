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
      ["사냥-아즈샤라"] = { level = 90, class = "HUNTER", realm = "아즈샤라" },
      ["사냥2-데스윙"] = { level = 90, class = "HUNTER", realm = "데스윙" },
    },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local now = time()
  local DB = QuestsToRichesDB
  local function clean(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  GameTooltip = { SetOwner = function() end, Show = function() end, Hide = function() end,
    AddLine = function(self, t) print("  tip: " .. clean(t)) end }
  DB.activeGQ = {
    [1] = { name = "퀘 1", zone = "공허폭풍", money = 10000000, expire = now + 3 * 3600 },
    [2] = { name = "퀘 2", zone = "줄아만", money = 11000000, expire = now + 5 * 3600 },
    [3] = { name = "퀘 3", zone = "줄아만", money = 9000000, expire = now + 6 * 3600 },
    [4] = { name = "퀘 4", zone = "하란다르", money = 8000000, expire = now + 7 * 3600 },
  }
  local function done(key, ...)
    DB.turnIns[key] = DB.turnIns[key] or {}
    for _, id in ipairs({ ... }) do DB.turnIns[key][id] = now - 30 end
  end
  local function show(title)
    print("== " .. title)
    print("  text: " .. clean(QTR.RecommendText()))
    QTR.ShowRecTip(nil)
  end
  done("드루-데스윙", 3, 4)
  done("사냥2-데스윙", 4)
  show("1) 선호 설정 없음 -> 골드 순 (사냥-아즈샤라 3,800과 주술 3,800 같음) -> 같은 서버 주술")
  DB.settings.classPref = { DRUID = 1, SHAMAN = 3 }
  show("2) 드루이드 선호, 주술사 비선호 -> 골드가 적어도(2,100) 드루")
  done("드루-데스윙", 1)
  done("사냥-아즈샤라", 1)
  done("사냥2-데스윙", 1)
  show("3) 가장 빨리 끝나는 퀘 1을 주술만 안 함 -> 비선호여도 주술 (1번 기준이 먼저)")
  DB.turnIns["드루-데스윙"] = {}
  DB.turnIns["사냥-아즈샤라"] = {}
  DB.turnIns["사냥2-데스윙"] = {}
  DB.settings.classPref = { HUNTER = 1 }
  done("사냥2-데스윙", 4)
  show("4) 사냥꾼 선호 둘: 사냥-아즈샤라 3,800, 사냥2(같은 서버) 3,000 -> 800 차이라 같은 서버 사냥2")
  print("== 5) 부자되기 탭: 추천 줄은 글 그대로, 이름 위 마우스 영역에 툴팁")
  QuestsToRiches_ToggleDashboard()
  for _, fs in ipairs(out) do fs._text = "" end
  QTR:Refresh()
  for _, fs in ipairs(out) do
    if type(fs._text) == "string" and fs._text:find("다음 추천") then
      print("  line: " .. clean(fs._text))
      local h = QTR.recHovers[fs]
      print("  hover: " .. tostring(h and h._shown))
      if h then rawget(h, "_scr_OnEnter")(h) end
    end
  end
  print("== 6) 모두 보통으로 -> 설정 지움")
  DB.settings.classPref = nil
  show("6) 선호 없음")
end''')(addon, out)
