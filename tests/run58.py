import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness3.lua', encoding='utf-8').read())
# 다음 접속 추천 캐릭터 (run54 준비 부분을 그대로 씀)
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
      ["여름이간다-데스윙"] = { level = 90, class = "WARRIOR", realm = "데스윙" },
      ["가을-데스윙"] = { level = 90, class = "MAGE", realm = "데스윙" },
      ["압구정-아즈샤라"] = { level = 90, class = "MAGE", realm = "아즈샤라" },
      ["저렙-데스윙"] = { level = 40, class = "MAGE", realm = "데스윙" },
    },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  DB.activeGQ = {
    [1] = { name = "퀘 1", zone = "공허폭풍", money = 10000000, expire = now + 3 * 3600 },
    [2] = { name = "퀘 2", zone = "줄아만", money = 11000000, expire = now + 5 * 3600 },
    [3] = { name = "20분 남음", zone = "줄아만", money = 9000000, expire = now + 20 * 60 },
    [4] = { name = "보관함 퀘", zone = "공허폭풍", money = 0, cacheItem = 279520, expire = now + 3600 * 24 },
    [5] = { name = "퀘 5", zone = "하란다르", money = 5000000, expire = now + 4 * 3600, hiddenFor = { ["가을-데스윙"] = true } },
    [6] = { name = "5분 남음", zone = "하란다르", money = 9900000, expire = now + 5 * 60 },
  }
  local function show(title)
    local r = QTR.RecommendNextChar()
    print("== " .. title)
    print("  pick:", r and r.key, r and r.count, r and math.floor(r.money / 10000), r and r.sameRealm, r and r.urgent and r.urgent.e.name)
    print("  text:", (QTR.RecommendText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "[icon]")))
  end
  local function done(key, ...)
    DB.turnIns[key] = DB.turnIns[key] or {}
    for _, id in ipairs({ ... }) do DB.turnIns[key][id] = now - 30 end
  end
  -- 5분 남은 퀘스트는 세지 않는다 (아무도 안 했어도 1번 기준이 되지 않는다)
  done("여름이간다-데스윙", 1)
  show("S1 20분 퀘스트는 모두 미완료 -> 골드 순: 압구정 3,500 vs 가을 3,000 (같은 서버, 500 차이) -> 가을")
  done("가을-데스윙", 3)
  done("압구정-아즈샤라", 3)
  show("S2 20분 퀘스트를 여름만 안 함 -> 골드가 적어도 여름")
  done("여름이간다-데스윙", 3)
  show("S3 20분 퀘스트 모두 함 -> 다음으로 빨리 끝나는 퀘 1을 안 한 가을(2,100), 압구정(2,600) 중 같은 서버 가을")
  done("가을-데스윙", 1, 2)
  done("압구정-아즈샤라", 1, 2, 5)
  done("여름이간다-데스윙", 2, 5)
  show("S4 다 했음 (5분 퀘스트만 남음) -> 없음")
  -- 부자되기 탭 셋째 줄 (정점 보관함은 숫자와 아이콘)
  DB.turnIns["압구정-아즈샤라"] = {}
  DB.cacheSources = { q900 = { kind = "quest", questID = 900, title = "실버문 주간", zone = "실버문", itemID = 279520, lastSeen = now } }
  QuestsToRiches_ToggleDashboard()
  for _, fs in ipairs(out) do fs._text = "" end
  QTR:Refresh()
  for _, fs in ipairs(out) do if type(fs._text) == "string" and fs._text:find("다음 추천") then print("rich line y=" .. tostring(rawget(fs, "_y")) .. ": " .. (fs._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "[icon]"))) end end
end''')(addon, out)
