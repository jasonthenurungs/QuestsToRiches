# 보유량 순증: 큰 변화 날은 빼고 계산 (2026-11-20 사용자 결정, 인벤 김다크님 글: 500만 골드 탈것을 산 뒤 일주일 내내 "보유량 감소 중")
#   이웃한 기록 사이 변화가 앞 기록의 20% 이상이면서 하루에 30만 골드 이상이면 늘었든 줄었든 뺀다 (run98 준비 부분 사용)
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
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["격냥패딩-데스윙"] = { money = 1, class = "PALADIN", level = 90 },
              ["인구학-데스윙"] = { money = 1, class = "MAGE", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash", chatNotify = true },
    cacheGets = {
      ["인구학-데스윙"] = { { id = 279527, n = 1, t = now - 600, q = 93766 } },          -- 이번 주 (인구학 실제 기록과 같은 모양)
      ["격냥패딩-데스윙"] = { { id = 279527, n = 1, t = now - 8 * 86400, q = 93766 } },  -- 지난주
    },
  }
  C_QuestLog.IsQuestFlaggedCompleted = function(id) return ALLFLAG end
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local strip = function(s)
    s = tostring(s or "")
    s = s:gsub("|cffffd100", "[노랑]"):gsub("|cffff4444", "[빨강]")
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
  end
  local G = 10000
  local function day(n) return date("%Y-%m-%d", now - n * 86400) end
  local function setSnaps(t) DB.snapshots = {}; for n, v in pairs(t) do DB.snapshots[day(n)] = v * G end end
  local function show(title)
    local tr, big = QTR.HoldingTrendForTest()
    print("== " .. title)
    print("  하루 순증: " .. (tr and string.format("%.0f", tr / G) or "nil") .. ", 뺀 날: " .. tostring(big))
    QTR:UpdateHeader()
    for _, fs in ipairs(out) do
      local t = fs._text
      if type(t) == "string" and t:find("보유량 순증") then print("  머리: " .. strip(t)) end
    end
  end
  -- 1) 김다크님 같은 경우: 매일 5만씩 벌다가 4일 전 500만 탈것을 삼 (그날도 5만 벎)
  setSnaps({ [7] = 5000000, [6] = 5050000, [5] = 5100000, [4] = 150000, [3] = 200000, [2] = 250000, [1] = 300000, [0] = 350000 })
  show("1) 500만 탈것 구매 -> 그날만 빼고 하루 +50,000")
  -- 2) 7일 안에 큰 지출이 두 번
  setSnaps({ [7] = 5000000, [6] = 5050000, [5] = 1050000, [4] = 1100000, [3] = 600000, [2] = 650000, [1] = 700000, [0] = 750000 })
  show("2) 400만, 50만 두 번 (50만은 110만의 45%) -> 두 날 빼고 +50,000")
  -- 3) 우편: 다른 캐릭터에 100만을 보내고 다음 날 받는 캐릭터 접속
  setSnaps({ [4] = 3000000, [3] = 3050000, [2] = 2100000, [1] = 3150000, [0] = 3200000 })
  show("3) 우편 100만 보냄(-31%) 받음(+50%) -> 둘 다 빼고 +50,000 (지출만 빼면 부풀려짐)")
  -- 4) 기준 아래: 20% 넘지만 10만 미만, 10만 넘지만 20% 미만
  setSnaps({ [1] = 300000, [0] = 400000 })
  show("4a) 30만->40만 (+10만, 33%지만 하루 30만 미만) -> 그대로 +100,000")
  setSnaps({ [1] = 4000000, [0] = 4350000 })
  show("4b) 400만->435만 (+35만, 하루 30만 넘지만 9%) -> 그대로 +350,000")
  -- 5) 큰 변화만 있음
  setSnaps({ [1] = 5000000, [0] = 100000 })
  show("5) 기록 2일, 그 사이가 큰 변화 -> 순증 없음 (회색 -)")
  -- 6) 큰 변화가 7일 범위 밖
  setSnaps({ [9] = 5000000, [8] = 100000, [7] = 150000, [3] = 350000, [0] = 500000 })
  show("6) 8일 전 구매는 범위 밖, 띄엄띄엄 접속(4일 사이 +20만은 하루 5만) -> 7일에 35만, +50,000, 표시 없음")
  setSnaps({ [6] = 5000000, [2] = 200000, [0] = 300000 })
  show("6b) 접속하지 않은 4일 사이에 500만 구매 (하루 120만) -> 그 4일 빼고 +50,000")
  -- 7) 줄어드는 중 (작은 지출)
  setSnaps({ [2] = 1000000, [1] = 950000, [0] = 900000 })
  show("7) 하루 5만씩 줄어듦 -> -50,000 (빨간)")
  print("== end")
end''')(addon, out)
