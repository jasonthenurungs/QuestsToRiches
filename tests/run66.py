# 다른 정점 보관함(최정상 보관함 등): 여는 골드 기록, 미개봉 알림창, 대박 판정과 별, 획득량 탭 보관함 묶음(대박 줄 접기, 일별 주별만 별) (run64 준비 부분 사용)
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
base = TD + ''
addon, out = lua.execute(open(base + 'harness2.lua', encoding='utf-8').read())
lua.execute('''
CHARNAME = "봄이간다"
NOWT = 1000
function GetTime() return NOWT end
Enum = { QuestTagType = { Capstone = 99 } }
NAMES = { [2395] = "영원노래 숲", [2437] = "줄아만", [2405] = "공허폭풍", [2413] = "하란다르", [2512] = "똬리의 섬" }
C_Map = { GetMapInfo = function(id) return { name = NAMES[id] or "실버문" } end, GetBestMapForUnit = function() return 9999 end }
Q = {}
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
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
-- 282183: 특별 과제 보관함, 279527: 최정상 보관함(ID로 앎), 888666: 모르는 정점 보관함(툴팁으로 앎), 777555: 정보를 아직 못 받은 아이템
CACHEITEMS = { [282183] = "실버문 정점 보관함", [279527] = "최정상 보관함", [888666] = "승리의 스토마리온 정점 보관함" }
LOADING = { [777555] = true }
C_TooltipInfo = { GetItemByID = function(id)
  if LOADING[id] then return { lines = { { leftText = "아이템 정보 받는 중" } } } end
  if CACHEITEMS[id] then return { lines = { { leftText = CACHEITEMS[id] }, { leftText = "|cff00ccff정점 보관함 - 한밤 2 시즌|r" } } } end
  return { lines = { { leftText = "잡템" .. id }, { leftText = "판매 가격" } } }
end }
BAG = { [0] = { [1] = 12345 } }
C_Container = { UseContainerItem = function() end,
  GetContainerNumSlots = function(b) return b == 0 and 8 or 0 end,
  GetContainerItemID = function(b, s) return BAG[b] and BAG[b][s] end }
C_Item = { GetItemCount = function(id) local n = 0 for _, b in pairs(BAG) do for _, v in pairs(b) do if v == id then n = n + 1 end end end return n end,
           GetItemIconByID = function(id) return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function(id) return CACHEITEMS[id] end, RequestLoadItemDataByID = function() end }
HOOKS = {}
function hooksecurefunc(t, name, fn) HOOKS[name] = fn end
C_EventUtils = { IsEventValid = function() return false end }
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
MerchantFrame = { IsShown = function() return false end }
QID = 0; QTITLE = ""; QREWARD = nil
function GetQuestID() return QID end
function GetTitleText() return QTITLE end
function GetNumQuestRewards() return QREWARD and 1 or 0 end
function GetQuestItemLink(kind, i) return QREWARD and ("|cffa335ee|Hitem:" .. QREWARD .. "::::|h[x]|h|r") end
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval(r'''function(QTR, out)
  local now = time()
  local G = 10000
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["여름이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 },
              ["격냥패딩-데스윙"] = { money = 1, class = "PALADIN", level = 90 } },
    days = {
      -- 지난주 (실제 데이터 10월 17일과 같은 금액)
      ["2026-10-09"] = {
        ["격냥패딩-데스윙"] = { count = 0, money = 17968 * G + 2074 * G, cacheCount = 2, cacheMoney = 17968 * G + 2074 * G,
          caches = { { id = 279527, money = 17968 * G, t = now - 7 * 86400 + 3600 }, { id = 279520, money = 2074 * G, t = now - 7 * 86400 + 4000 } } },
        ["여름이간다-데스윙"] = { count = 0, money = (17915 + 4427 + 4479 + 1966) * G, cacheCount = 4, cacheMoney = (17915 + 4427 + 4479 + 1966) * G,
          caches = { { id = 279527, money = 17915 * G, t = now - 7 * 86400 + 100 }, { id = 279527, money = 4427 * G, t = now - 7 * 86400 + 200 },
                     { id = 279526, money = 4479 * G, t = now - 7 * 86400 + 300 }, { id = 279527, money = 1966 * G, t = now - 7 * 86400 + 400 } } },
      },
    },
    turnIns = {},
    settings = { tab = "dash", chatNotify = true, cacheAlert = true },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local strip = function(s)
    s = tostring(s or "")
    s = s:gsub("|cffffd700\226\152\133|r", "[금별]"):gsub("|cffc0c0c0\226\152\133|r", "[은별]"):gsub("|cffcd7f32\226\152\133|r", "[동별]")
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / "))
  end

  print("== 1) 정점 보관함 알아보기")
  for _, id in ipairs({ 279520, 282183, 279527, 279526, 888666, 12345, 777555 }) do
    print("  " .. id .. ": " .. tostring(QTR.IsApexItem(id)))
  end
  LOADING[777555] = nil
  CACHEITEMS[777555] = "늦게 받은 정점 보관함"
  print("  777555 정보를 받은 뒤: " .. tostring(QTR.IsApexItem(777555)) .. " (못 받았을 때는 기억하지 않음)")

  print("== 2) 미개봉 알림창 (가방: 잡템, 최정상, 모르는 정점, 특별 과제)")
  local btn = QuestsToRichesCacheOpenButton
  local function alert(title)
    print("  " .. title .. ": 보임 " .. tostring(QuestsToRichesCacheAlert:IsShown()) .. " / " .. strip(btn.text._text)
      .. " / 누르면 " .. tostring(btn.itemID))
  end
  BAG[0][2] = 279527; QTR:BAG_UPDATE_DELAYED(); alert("최정상 1개")
  BAG[0][3] = 888666; QTR:BAG_UPDATE_DELAYED(); alert("모르는 정점 1개 더")
  BAG[0][4] = 282183; QTR:BAG_UPDATE_DELAYED(); alert("특별 과제 1개 더 (특별 과제를 먼저 연다)")
  local c = QuestsToRichesDB.chars["봄이간다-데스윙"]
  local bagIDs = {}
  for id, n in pairs(c.cacheBag or {}) do table.insert(bagIDs, id .. "x" .. n) end
  table.sort(bagIDs)
  print("  부자되기 탭용 가방 개수(다른 정점 보관함도): " .. table.concat(bagIDs, ", "))
  local gets = {}
  for _, g in ipairs(QuestsToRichesDB.cacheGets["봄이간다-데스윙"] or {}) do table.insert(gets, g.id) end
  print("  받은 기록(2026-10-29부터 다른 보관함도, 툴팁으로 늦게 안 보관함은 처음 개수를 기준으로만): " .. table.concat(gets, ", "))

  print("== 3) 열기와 대박 판정")
  local function open(slot, gold)
    local id = BAG[0][slot]
    HOOKS["UseContainerItem"](0, slot)
    NOWT = NOWT + 5
    BAG[0][slot] = nil
    MONEY = MONEY + gold * G
    QTR:PLAYER_MONEY()
    RunLater()
    QTR:BAG_UPDATE_DELAYED()
  end
  open(2, 17968)
  open(3, 4450)
  open(4, 2010)
  alert("다 연 뒤")
  local rec = QuestsToRichesDB.days[date("%Y-%m-%d", now)]["봄이간다-데스윙"]
  for _, cg in ipairs(rec.caches) do print("  기록: " .. cg.id .. " " .. (cg.money / G) .. "골드") end
  print("  오늘 합계: " .. (rec.money / G) .. "골드, 보관함 " .. rec.cacheCount .. "개")
  for _, g in ipairs({ 2999, 3000, 9999, 10000, 17968 }) do
    local tier, star = QTR.JackpotTier(g * G)
    print("  " .. g .. "골드: " .. tostring(tier) .. " " .. strip(star))
  end

  print("== 4) 획득량 탭 보관함 묶음")
  local CAP
  local orig = QTR.StatsCacheRows
  QTR.StatsCacheRows = function(a, m, e) CAP = e; return orig(a, m, e) end
  local function click(text)
    for _, fr in ipairs(ALLFRAMES) do if type(rawget(fr, "_text")) == "string" and fr._text:gsub(" %(%l%)$", "") == text and rawget(fr, "_scr_OnClick") then rawget(fr, "_scr_OnClick")(fr); return end end
  end
  local function show(title)
    print("  -- " .. title)
    for _, fs in ipairs(out) do
      local t = fs._text
      if type(t) == "string" and (t:find("^참여 캐릭터") or t:find("^수행한 날")) then print("    요약: " .. strip(t)) end
      if type(t) == "string" and t:find("^전체") then print("    기간 제목: " .. strip(t)) end
    end
    local on = false
    for _, e in ipairs(CAP or {}) do
      if type(e) == "string" then
        if strip(e) == "보관함 대박" then on = true end
        if strip(e) ~= "" then print("    " .. strip(e)) end
      else
        local parts = {}
        for _, cell in ipairs(e) do if cell.text ~= "" then table.insert(parts, strip(cell.text)) end end
        print("    " .. table.concat(parts, " | "))
        if on and e.tipLines and e.tipLines.title then
          for _, l in ipairs(e.tipLines.lines) do print("        툴팁: " .. strip(l.left) .. " = " .. strip(l.right)) end
        end
      end
    end
  end
  -- 묶음 줄의 +를 누른다 (줄 클릭)
  local function toggle(label)
    for _, e in ipairs(CAP or {}) do
      if type(e) == "table" and e[2] and strip(e[2].text):find(label, 1, true) == 1 then
        if e.onClick then e.onClick(); print("  (" .. label .. " 줄 누름)") else print("  (" .. label .. " 줄은 누를 수 없음)") end
        return
      end
    end
  end
  QuestsToRiches_ToggleDashboard()
  SlashCmdList["QUESTSTORICHES"]("stats")
  click("일별"); show("일별 (오늘, 처음에는 접힘)")
  toggle("초대박"); show("일별 (초대박 펼침)")
  click("주별"); show("주별 (이번 주, 펼친 상태 유지)")
  click("<"); show("주별 (지난주)")
  toggle("대박(")
  toggle("초대박"); show("주별 (지난주, 초대박 다시 접고 대박 펼침)")
  click("월별"); show("월별 (2026-10-29부터 별과 + 있음, 접힘)")
  toggle("초대박")
  show("월별 (펼침, 날짜는 10/9(금) 꼴)")
  click("전체"); show("전체 (펼친 상태 유지, 날짜는 26/10/09(금) 꼴, 기간 제목에 수집 기간)")
  -- 캐릭터 줄 툴팁의 별
  click("주별"); click("<")
  for _, e in ipairs(CAP) do
    if type(e) == "table" and e.tipLines and e.tipLines.title and strip(e.tipLines.title):find("여름이간다") then
      for _, l in ipairs(e.tipLines.lines) do print("  여름이간다 툴팁: " .. strip(l.left) .. " = " .. strip(l.right)) end
    end
  end
  CAP = nil
  print("== 5) 요약 줄 대박: 없으면 아무것도 붙이지 않는다")
  print("  대박 없음: " .. tostring(QTR.JackpotSummary({ { money = 2000 * G }, { money = 2999 * G } })))
  print("  보관함 없음: " .. tostring(QTR.JackpotSummary({})))
  print("  두 등급: " .. strip(QTR.JackpotSummary({ { money = 3000 * G }, { money = 9000 * G }, { money = 17968 * G }, { money = 17915 * G } })))

  print("== 6) 골드퀘 탭 클릭: 내비게이션 중에는 웨이포인트를 찍지 않고 채팅 한 줄 (10초에 한 번)")
  PIN = nil
  UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
  C_Map.CanSetUserWaypointOnMap = function() return true end
  C_Map.SetUserWaypoint = function(p) PIN = p end
  C_Map.GetUserWaypoint = function() return PIN end
  C_Map.HasUserWaypoint = function() return PIN ~= nil end
  C_Map.ClearUserWaypoint = function() PIN = nil end
  C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
  local wp = { 2405, 0.2, 0.3 }
  QTR.route = { { questID = 77, wp = { 2405, 0.5, 0.5 } } } -- 안내 중인 경로 (흉내)
  print("  누름 1: " .. tostring(QTR.TabWaypoint(5, "퀘 E", wp, "공허폭풍")) .. " / 핀 " .. tostring(PIN ~= nil))
  NOWT = NOWT + 3
  print("  3초 뒤 누름 2 (채팅 없음): " .. tostring(QTR.TabWaypoint(5, "퀘 E", wp, "공허폭풍")))
  NOWT = NOWT + 11
  print("  11초 뒤 누름 3 (채팅 다시): " .. tostring(QTR.TabWaypoint(5, "퀘 E", wp, "공허폭풍")))
  QTR.route = nil
  print("  내비게이션이 없을 때: " .. tostring(QTR.TabWaypoint(5, "퀘 E", wp, "공허폭풍")) .. " / 핀 " .. tostring(PIN and PIN.uiMapID))

  print("== 7) 부자되기 탭 다른 정점 보관함 (이번 주에 받은 캐릭터가 있을 때만)")
  -- 여름이간다가 이번 주에 최정상 보관함을 받고 열지 않았다 (받은 기록과 가방 개수만)
  -- 여름이간다는 두 퀘스트에서 두 개 받았다 (나중에 받은 10분 전 기준으로 보인다)
  QuestsToRichesDB.cacheGets["여름이간다-데스윙"] = { { id = 279527, n = 1, t = now - 3600 }, { id = 279527, n = 1, t = now - 600 } }
  -- 격냥패딩은 받은 기록 없이 연 기록만 두 개 (그전 시험판 데이터): 나중에 연 것 기준
  local todayRec = QuestsToRichesDB.days[date("%Y-%m-%d", now)]
  todayRec["격냥패딩-데스윙"] = { count = 0, money = 4000 * G, cacheCount = 2, cacheMoney = 4000 * G,
    caches = { { id = 279527, money = 2000 * G, t = now - 7200 }, { id = 279527, money = 2000 * G, t = now - 1800 } } }
  QuestsToRichesDB.chars["여름이간다-데스윙"].cacheBag = { [279527] = 1 }
  -- 이번 주 특별 과제 출처도 하나 (한 묶음 "정점 보관함"에 특별 과제 줄 먼저, 그 아래 다른 보관함 줄)
  QuestsToRichesDB.cacheSources["q95921"] = { kind = "quest", questID = 95921, title = "특별 과제: 수요와 공급", zone = "똬리의 섬",
    itemID = 282183, onMap = true, expire = now + 86400, lastSeen = now, learned = now }
  local function rows(title)
    for _, fs in ipairs(out) do fs._text = "" end
    QTR:Refresh()
    local cells = {}
    for _, fs in ipairs(out) do
      if fs._shown and type(fs._text) == "string" and fs._text ~= "" and rawget(fs, "_y") and rawget(fs, "_y") <= 0 and rawget(fs, "_x") and rawget(fs, "_x") < 400 then table.insert(cells, fs) end
    end
    table.sort(cells, function(a, b) if a._y ~= b._y then return a._y > b._y end return a._x < b._x end)
    print("  -- " .. title)
    local line, lasty = {}, nil
    for _, fs in ipairs(cells) do
      if lasty and fs._y ~= lasty then print("    " .. table.concat(line, " | ")); line = {} end
      lasty = fs._y; table.insert(line, strip(fs._text:gsub("|T.-|t", "[아이콘]")))
    end
    if #line > 0 then print("    " .. table.concat(line, " | ")) end
  end
  -- 이번 주 시작: 하네스의 주간 초기화는 6일 9시간 뒤라 지금부터 15시간 전
  local list = QTR.OtherApexThisWeek(time() - 15 * 3600)
  for _, o in ipairs(list) do
    local g = {}
    for k, t in pairs(o.got) do table.insert(g, k .. "@" .. (now - t)) end
    table.sort(g)
    print("  이번 주 받은 다른 보관함: " .. o.id .. " " .. table.concat(g, ", "))
  end
  SlashCmdList["QUESTSTORICHES"]("rich")
  rows("부자되기 탭 (접힘)")
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "tipItem") == 279527 and rawget(fr, "_scr_OnClick") then rawget(fr, "_scr_OnClick")(fr, "LeftButton"); break end
  end
  rows("최정상 보관함 줄은 2026-10-30부터 없음 (실버문 주간 두 줄이 대신한다)")
  print("== 7b) 실버문 주간 퀘스트 두 줄 (잘아타스 추적, 리에드린 주간)")
  QTR:QUEST_TURNED_IN("x", 98172, 0, 0) -- 봄이간다(지금 캐릭터)가 잘아타스 추적 완료
  QuestsToRichesDB.turnIns["여름이간다-데스윙"] = { [93913] = now - 100, [98172] = now - 8 * 86400 } -- 리에드린 이번 주, 잘아타스는 지난주
  QuestsToRichesDB.flagDone["격냥패딩-데스윙"] = { [93911] = now - 50 } -- 접속했을 때 게임 완료 표시로 본 리에드린 던전 (시각 모름)
  print("  봄이간다 turnIns[98172] 저장: " .. tostring(QuestsToRichesDB.turnIns["봄이간다-데스윙"] and QuestsToRichesDB.turnIns["봄이간다-데스윙"][98172] ~= nil))
  rows("부자되기 탭 (최정상 보관함 줄 대신 두 줄)")
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "tipQuest") == 98172 and rawget(fr, "_scr_OnClick") then rawget(fr, "_scr_OnClick")(fr, "LeftButton"); break end
  end
  rows("잘아타스 추적 펼침")
  -- 게임 완료 표시 기록 (지금 캐릭터): 리에드린 구렁 93909가 완료로 보이면 flagDone에 남긴다
  local oldFlag = C_QuestLog.IsQuestFlaggedCompleted
  C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 93909 end
  QTR.ScanWeeklyFlags()
  C_QuestLog.IsQuestFlaggedCompleted = oldFlag
  print("  봄이간다 flagDone[93909]: " .. tostring(QuestsToRichesDB.flagDone["봄이간다-데스윙"] and QuestsToRichesDB.flagDone["봄이간다-데스윙"][93909] ~= nil))
  -- 리에드린 주간을 이번 주에 아무도 안 했으면 그 줄은 없다 (2026-10-30 사용자 결정: 숙제처럼 보이지 않게)
  QuestsToRichesDB.turnIns["여름이간다-데스윙"][93913] = nil
  QuestsToRichesDB.flagDone["격냥패딩-데스윙"] = nil
  QuestsToRichesDB.flagDone["봄이간다-데스윙"][93909] = nil
  rows("리에드린 주간을 아무도 안 함 (잘아타스 추적 줄만)")
  -- 이번 주에 아무도 안 받았으면 묶음이 없다
  QuestsToRichesDB.cacheGets["여름이간다-데스윙"] = nil
  QuestsToRichesDB.cacheGets["봄이간다-데스윙"] = nil
  QuestsToRichesDB.days[date("%Y-%m-%d", now)] = nil
  print("  이번 주 기록을 지운 뒤 다른 보관함 수: " .. #QTR.OtherApexThisWeek(time() - 15 * 3600))

  print("== 8) 대박이 많을 때: 모든 보기에서 최근 것부터 10개와 \"그 밖의 대박 n회\"")
  local many = {}
  for i = 1, 16 do
    -- 금액: 2배급과 8배급을 섞고, 같은 금액(17,968)도 둘 (먼저 나온 것이 위)
    local g = (i % 3 == 0) and 17968 or (4400 + i)
    table.insert(many, { key = (i % 2 == 0) and "봄이간다-데스윙" or "여름이간다-데스윙", id = 279527, money = g * G, t = now - (20 - i) * 86400 })
  end
  local none = {}
  QTR.StatsCacheRows({ caches = { { key = "봄이간다-데스윙", id = 279520, money = 2000 * G, t = now }, { key = "봄이간다-데스윙", id = 279527, money = 2999 * G, t = now } } }, "week", none)
  print("  대박이 없는 기간의 보관함 대박 묶음 줄 수: " .. #none)
  QTR.statsJackpotOpen[2] = true; QTR.statsJackpotOpen[1] = true
  for _, mode in ipairs({ "all", "month" }) do
    local e = {}
    QTR.StatsCacheRows({ caches = many }, mode, e)
    print("  -- " .. mode)
    for _, row in ipairs(e) do
      if type(row) == "table" then
        local parts = {}
        for _, cell in ipairs(row) do if cell.text ~= "" then table.insert(parts, (strip(cell.text:gsub("|T.-|t", "g")))) end end
        print("    " .. table.concat(parts, " | "))
      end
    end
  end
  print("== end")
end''')(addon, out)
