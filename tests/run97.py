# 부자되기 탭 보관함 줄의 대박 표시 (2026-11-11 사용자 요청: 동기부여): 받은 기록(cacheGets)과 연 기록(days의 caches)을
#   같은 캐릭터, 같은 보관함끼리 받은 차례와 연 차례로 짝지어 대박이면 별과 골드. 미개봉이 있으면 미개봉 개수가 먼저
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
      ["드루-데스윙"] = { level = 90, class = "DRUID", realm = "데스윙", cacheBag = { [279527] = 1 } },
    },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  GetMaxLevelForPlayerExpansion = function() return 90 end
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local now = time()
  local function clean(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "")) end
  local K = "봄이간다-데스윙"
  DB.cacheGets[K] = {
    { id = 279527, n = 1, t = now - 5000, q = 98172 },   -- 실버문 주간 (잘아타스 추적)
    { id = 279527, n = 1, t = now - 3000, q = 98200 },   -- 같은 보관함을 다른 주간 퀘스트로
    { id = 279520, n = 1, t = now - 2000, q = 93438 },   -- 특별 과제 보관함
  }
  DB.days["2026-10-16"] = { [K] = { caches = {
    { id = 279527, money = 9000000, t = now - 9000 },    -- 받기 전에 연 것 (짝 아님)
    { id = 279527, money = 44430000, t = now - 4900 },   -- 첫째 받은 것 -> 대박 4,443
    { id = 279527, money = 179120000, t = now - 2900 },  -- 둘째 받은 것 -> 초대박 17,912
    { id = 279520, money = 20000000, t = now - 1900 },   -- 특별 과제 보관함 2,000 (대박 아님)
  } } }
  local m = QTR.CacheOpenMatch(K)
  print("== 1) 짝짓기")
  for _, g in ipairs(DB.cacheGets[K]) do print("  q" .. g.q .. " -> " .. tostring(m[g] and m[g] / 10000)) end
  local since = now - 86400
  local function q(id) return function(g) return g.q == id end end
  print("== 2) 칸 글자")
  print("  잘아타스: " .. clean(QTR.CacheCellText(K, 279527, QTR.OpenGoldSince(K, since, q(98172)))))
  print("  다른 주간: " .. clean(QTR.CacheCellText(K, 279527, QTR.OpenGoldSince(K, since, q(98200)))))
  print("  특별 과제(대박 아님): " .. tostring((QTR.CacheCellText(K, 279520, QTR.OpenGoldSince(K, since, q(93438))))))
  print("  미개봉이 있으면 미개봉 먼저: " .. clean(QTR.CacheCellText("드루-데스윙", 279527, 179120000)))
  print("  연 기록 없음: " .. tostring((QTR.CacheCellText(K, 279527, nil))))
  print("  since 이전 받은 것은 안 봄: " .. tostring(QTR.OpenGoldSince(K, now - 4000, q(98172))))
end''')(addon, out)
