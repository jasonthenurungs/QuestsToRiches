# 부자되기 탭 캐릭터 상태 (2026-11-01 사용자 요청)
#   1) 특별 과제: 아직 안 한 캐릭터를 잠김(n/3) / 미완료(해금함) / 미확인(이번 회차에 그 캐릭터로 지도를 못 읽음)으로 나눈다
#      지도를 읽을 때 DB.saLock에 남긴다. 순서: 완료, 미완료, 잠김, 미확인
#   2) 실버문 주간 퀘스트: 수행중이면 "수행중" 대신 진행도 "0/100" (진행 막대는 "40%", 진행도를 모르면 "수행중")
#      퀘스트 목록이 바뀌면(QUEST_LOG_UPDATE) 2초 뒤 진행도를 다시 남긴다. 목록이 비어 있으면 덮지 않는다
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
C_Map = { GetMapInfo = function(id) return { name = (id == 2395) and "영원노래 숲" or "실버문" } end, GetBestMapForUnit = function() return 9999 end }
LOCKED = true
TITLES = { [92145] = "특별 과제: 그림자와 발톱", [80001] = "보통 전역퀘" }
C_TaskQuest = {
  GetQuestsOnMap = function(mapID)
    if mapID ~= 2395 then return {} end
    local r = { { questID = 80001, mapID = 2395, x = 0.4, y = 0.4 } }
    if not LOCKED then table.insert(r, { questID = 92145, mapID = 2395, x = 0.5, y = 0.5 }) end
    return r
  end,
  GetQuestInfoByQuestID = function(id)
    if id == 92145 and GetLocale() ~= "koKR" then return "Special Assignment: 그림자와 발톱" end -- 영어 클라이언트 시험용
    return TITLES[id]
  end,
  GetQuestTimeLeftSeconds = function(id) if id == 80001 or id == 92848 or id == 92145 then return 3 * 86400 end return nil end,
  GetQuestZoneID = function() return 2395 end,
}
function GetQuestLogRewardMoney(id) return 0 end
function GetNumQuestLogRewards(id) return 0 end
function GetQuestLogRewardInfo(i, id) return nil end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return false end
C_QuestLog.GetQuestTagInfo = function(id) return {} end
C_QuestLog.IsWorldQuest = function(id) return true end
ONQUEST = {}
C_QuestLog.IsOnQuest = function(id) return ONQUEST[id] == true end
OBJ = {}
C_QuestLog.GetQuestObjectives = function(id) return OBJ[id] end
function GetQuestProgressBarPercent(id) return 40.5 end
C_AreaPoiInfo = {
  GetAreaPOIForMap = function(mapID) if LOCKED and mapID == 2395 then return { 500 } end return {} end,
  GetAreaPOIInfo = function(mapID, id)
    if id == 500 then return { atlasName = "worldquest-Capstone-questmarker", isPrimaryMapForPOI = true, tooltipWidgetSet = 77,
      name = "특별 과제: 그림자와 발톱", position = { x = 0.5, y = 0.5 }, areaPoiID = 500 } end
  end,
}
C_UIWidgetManager = {
  GetTextWithStateWidgetVisualizationInfo = function(id) if id == 7710 and LOCKED then return { text = "2" } end return nil end,
  GetAllWidgetsBySetID = function(setID) if setID == 77 then return { { widgetID = 7710 } } end return {} end,
}
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "x" } } } end }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function(id) return "정점 보관함" end, RequestLoadItemDataByID = function() end }
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
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["여름이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["격냥패딩-데스윙"] = { money = 1, class = "PALADIN", level = 90 },
              ["인구학-데스윙"] = { money = 1, class = "MAGE", level = 90 },
              ["마온자로-데스윙"] = { money = 1, class = "MAGE", level = 90 },
              ["랩갈-데스윙"] = { money = 1, class = "HUNTER", level = 90 },
              ["후추-데스윙"] = { money = 1, class = "ROGUE", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash", chatNotify = true },
    cacheSources = { q92145 = { kind = "quest", questID = 92145, title = "특별 과제: 그림자와 발톱", zone = "영원노래 숲",
      itemID = 279520, onMap = true, lastSeen = now, learned = now - 86400, via = "map", expire = now + 3 * 86400 } },
  }
  -- 지금 캐릭터 봄이간다는 잘아타스 추적을 받아 두었다 (0/100)
  ONQUEST[98172] = true
  OBJ[98172] = { { type = "item", numFulfilled = 0, numRequired = 100, finished = false, text = "x" } }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  local strip = function(s)
    s = tostring(s or "")
    s = s:gsub("|cffffd100", "[노랑]"):gsub("|cffff4444", "[빨강]"):gsub("|cffaaaaaa", "[회색]"):gsub("|cff808080", "[회색]")
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
      if s:find("정점 보관함") == 1 or s:find("Pinnacle Caches") == 1 then on = true end
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
  local function lock(k)
    local s = DB.saLock[k] and DB.saLock[k][2395]
    return s and ("open=" .. tostring(s.open) .. " p=" .. tostring(s.p) .. " q=" .. tostring(s.q)) or "nil"
  end

  print("== 1) 접속 때 지도를 읽어 지금 캐릭터의 잠김 상태를 남긴다 (영원노래 숲 잠김, 전역퀘 2개 남음 -> 1/3)")
  QTR.forceScan = true
  QTR.ScanQuestBoard()
  print("  봄이간다 saLock: " .. lock("봄이간다-데스윙"))

  print("== 2) 특별 과제 줄 펼침: 완료, 미완료(해금), 잠김, 미확인 순")
  DB.turnIns["랩갈-데스윙"] = { [92145] = now - 50 }
  DB.saLock["여름이간다-데스윙"] = { [2395] = { t = now - 100, open = true, p = 3, q = 92145 } }
  DB.saLock["격냥패딩-데스윙"] = { [2395] = { t = now - 200, open = false, p = 2, q = 92145 } }
  -- 마온자로: 지난 회차에 본 상태 (이번 회차 시작 = 만료 7일 전 보다 이전) -> 미확인
  DB.saLock["마온자로-데스윙"] = { [2395] = { t = now - 5 * 86400, open = false, p = 0, q = 92145 } }
  -- 후추: 같은 지역 다른 특별 과제를 해금한 기록 -> 미확인
  DB.saLock["후추-데스윙"] = { [2395] = { t = now - 300, open = true, p = 3, q = 92139 } }
  -- 인구학: 기록 없음 -> 미확인
  SlashCmdList["QUESTSTORICHES"]("rich")
  expand(92145)
  rows("특별 과제 펼침")

  print("== 3) 봄이간다가 전역퀘를 마저 해서 해금 -> 지도를 다시 읽으면 미완료")
  LOCKED = false
  QTR.forceScan = true
  QTR.ScanQuestBoard()
  print("  봄이간다 saLock: " .. lock("봄이간다-데스윙"))

  print("== 4) 실버문 잘아타스 추적: 수행중 캐릭터는 진행도")
  DB.weeklyOn["여름이간다-데스윙"] = { t = now - 60, ids = { [98172] = true }, prog = { [98172] = { f = 37, r = 100 } } }
  DB.weeklyOn["격냥패딩-데스윙"] = { t = now - 60, ids = { [98172] = true }, prog = { [98172] = { p = 40 } } }
  -- 인구학: 진행도를 남기기 전 버전의 기록 -> "수행중"
  DB.weeklyOn["인구학-데스윙"] = { t = now - 60, ids = { [98172] = true } }
  DB.turnIns["랩갈-데스윙"][98172] = now - 40
  expand(98172)
  rows("특별 과제(봄이간다 해금 뒤) + 잘아타스 추적 펼침")

  print("== 5) 진행도 읽기")
  OBJ[93910] = { { type = "progressbar", numFulfilled = 0, numRequired = 1, finished = false } }
  OBJ[93911] = { { type = "monster", numFulfilled = 1, numRequired = 1, finished = true }, { type = "item", numFulfilled = 3, numRequired = 5, finished = false } }
  OBJ[93912] = { { type = "monster", numFulfilled = 1, numRequired = 1, finished = true }, { type = "item", numFulfilled = 5, numRequired = 5, finished = true } }
  local function pr(id) local p = QTR.QuestProgress(id); return p and (p.p and (p.p .. "%") or (p.f .. "/" .. p.r)) or "nil" end
  print("  진행 막대: " .. pr(93910) .. " / 둘째 목표 진행 중: " .. pr(93911) .. " / 모두 끝냄: " .. pr(93912) .. " / 목표 없음: " .. pr(93913))

  print("== 6) 창을 열지 않고 55/100까지 진행 (QUEST_LOG_UPDATE 여러 번 -> 2초 뒤 한 번) -> 진행도를 남긴다")
  OBJ[98172][1].numFulfilled = 55
  LATER = {}
  QTR:QUEST_LOG_UPDATE(); QTR:QUEST_LOG_UPDATE(); QTR:QUEST_LOG_UPDATE()
  print("  예약된 갱신: " .. #LATER)
  RunLater()
  local p = DB.weeklyOn["봄이간다-데스윙"].prog[98172]
  print("  봄이간다 잘아타스 진행도: " .. p.f .. "/" .. p.r)
  print("== 6b) 접속 종료 중처럼 퀘스트 목록이 비면 (2026-11-01 제보: 수행중 기록이 지워짐) -> 기록을 덮지 않는다")
  ONQUEST[98172] = nil
  C_QuestLog.GetNumQuestLogEntries = function() return 0 end
  QTR.ScanWeeklyFlags()
  p = DB.weeklyOn["봄이간다-데스윙"]
  print("  봄이간다 98172 수행중: " .. tostring(p.ids[98172]) .. " 진행도 " .. p.prog[98172].f .. "/" .. p.prog[98172].r)
  C_QuestLog.GetNumQuestLogEntries = function() return 5 end
  QTR.ScanWeeklyFlags()
  print("  목록이 있는데 없으면 (포기): " .. tostring(DB.weeklyOn["봄이간다-데스윙"].ids[98172]))
  C_QuestLog.GetNumQuestLogEntries = nil

  print("== 7) 캐릭터 합치기: saLock은 더 늦게 본 쪽")
  QTR.MergeChars("격냥패딩-데스윙", "인구학-데스윙")
  print("  인구학 saLock: " .. lock("인구학-데스윙") .. " / 격냥패딩 saLock: " .. tostring(DB.saLock["격냥패딩-데스윙"]))
  print("== end")
end''')(addon, out)
