# 캐릭터 기록 합치기(이름 변경, 중복 정리), 캐릭터 GUID 저장, 순증 추세 달성 예상 문구 (run64 준비 부분 사용)
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
C_Map = { GetMapInfo = function(id) return { name = "실버문" } end, GetBestMapForUnit = function() return 9999 end }
C_TaskQuest = { GetQuestsOnMap = function() return {} end, GetQuestInfoByQuestID = function() return nil end,
  GetQuestTimeLeftSeconds = function() return nil end, GetQuestZoneID = function() return 2405 end }
function GetQuestLogRewardMoney() return 0 end
function GetNumQuestLogRewards() return 0 end
function GetQuestLogRewardInfo() return nil end
C_QuestLog.IsQuestFlaggedCompleted = function() return false end
C_QuestLog.GetQuestTagInfo = function() return {} end
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "잡템" }, { leftText = "판매 가격" } } } end }
BAG = { [0] = {} }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function(b) return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 5555 end, GetItemIDByGUID = function() return nil end,
           GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end }
HOOKS = {}
function hooksecurefunc(t, name, fn) HOOKS[name] = fn end
C_EventUtils = { IsEventValid = function() return false end }
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
MerchantFrame = { IsShown = function() return false end }
function GetQuestID() return 0 end
function GetTitleText() return "" end
function GetNumQuestRewards() return 0 end
function UnitGUID(u) return "Player-205-0ABCDEF1" end
''')
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
lua.eval(r'''function(QTR, out)
  local now = time()
  local G = 10000
  local A, B, C = "옛이름-데스윙", "새이름-데스윙", "다른캐릭-데스윙"
  local function rec(quests, caches)
    local r = { count = 0, money = 0, quests = {} }
    for _, q in ipairs(quests) do table.insert(r.quests, { id = q[1], name = "퀘" .. q[1], zone = "공허폭풍", money = q[2] * G, t = q[3] }); r.count = r.count + 1; r.money = r.money + q[2] * G end
    if caches then
      r.caches, r.cacheCount, r.cacheMoney = {}, 0, 0
      for _, c in ipairs(caches) do table.insert(r.caches, { id = 279520, money = c[1] * G, t = c[2] }); r.cacheCount = r.cacheCount + 1; r.cacheMoney = r.cacheMoney + c[1] * G; r.money = r.money + c[1] * G end
    end
    return r
  end
  QuestsToRichesDB = {
    chars = { [A] = { money = 500 * G, class = "MAGE", level = 90, lastSeen = now - 5 * 86400 },
              [B] = { money = 900 * G, class = "MAGE", level = 90, lastSeen = now },
              [C] = { money = 300 * G, class = "WARRIOR", level = 90, lastSeen = now },
              ["봄이간다-데스윙"] = { money = 100 * G, class = "WARRIOR", level = 90 } },
    days = {
      ["2026-10-10"] = { [A] = rec({ { 1, 1000, now - 6 * 86400 }, { 2, 1200, now - 6 * 86400 + 60 } }, { { 2000, now - 6 * 86400 + 120 } }),
                        [C] = rec({ { 1, 1000, now - 6 * 86400 + 30 } }) },
      -- 이름을 바꾼 날: 옛 이름과 새 이름 기록이 같은 날에 있다
      ["2026-10-14"] = { [A] = rec({ { 3, 900, now - 2 * 86400 } }),
                        [B] = rec({ { 4, 1100, now - 2 * 86400 + 3600 } }, { { 1950, now - 2 * 86400 + 4000 } }) },
      ["2026-10-15"] = { [B] = rec({ { 5, 1000, now - 86400 } }) },
    },
    holdDays = {
      ["2026-10-10"] = { chars = { [A] = 400 * G, [C] = 300 * G }, warband = 10 * G },
      ["2026-10-14"] = { chars = { [A] = 450 * G, [B] = 880 * G } },
      ["2026-10-15"] = { chars = { [B] = 900 * G } },
    },
    -- 퀘 3은 둘 다 완료 (B가 더 늦다), 퀘 1은 A만 (A가 더 늦은 경우는 퀘 4: A가 나중)
    turnIns = { [A] = { [1] = now - 6 * 86400, [3] = now - 2 * 86400, [4] = now - 50 }, [B] = { [3] = now - 100, [4] = now - 2 * 86400 + 3600 } },
    flagDone = { [A] = { [7] = now - 50 } },
    cacheGets = { [A] = { { id = 279520, n = 1, t = now - 6 * 86400 + 100 } }, [B] = { { id = 279520, n = 1, t = now - 2 * 86400 + 3900 } } },
    activeGQ = {
      [11] = { name = "퀘11", zone = "공허폭풍", mapID = 2405, money = 10000000, expire = now + 86400, seen = now,
               seenBy = { [A] = now - 300, [B] = now - 200 }, hiddenFor = { [A] = true } }, -- B가 직접 봤다: A의 숨김은 옮기지 않는다
      [12] = { name = "퀘12", zone = "공허폭풍", mapID = 2405, money = 10000000, expire = now + 86400, seen = now,
               seenBy = { [A] = now - 300 }, hiddenFor = { [A] = true }, notGoldFor = { [A] = true } }, -- B는 본 적 없다: 옮긴다
    },
    dayBoundary = "midnight", -- 날짜 기준 옮기기는 이미 끝난 상태
    settings = { tab = "dash", goal = 6500000 },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB

  print("== 1) 캐릭터 GUID 저장 (접속 때 조용히)")
  print("  봄이간다 guid: " .. tostring(DB.chars["봄이간다-데스윙"].guid))

  local function totals()
    local count, money, caches, perDay = 0, 0, 0, {}
    for dk, day in pairs(DB.days) do
      local dm = 0
      for key, r in pairs(day) do
        count = count + (r.count or 0); money = money + (r.money or 0); caches = caches + (r.cacheCount or 0); dm = dm + (r.money or 0)
      end
      perDay[dk] = dm
    end
    local keys = {}
    for dk in pairs(perDay) do table.insert(keys, dk) end
    table.sort(keys)
    local days = {}
    for _, dk in ipairs(keys) do table.insert(days, dk .. "=" .. (perDay[dk] / G)) end
    return string.format("골드퀘 %d개, 보관함 %d개, %d골드 / 날짜별 %s", count, caches, money / G, table.concat(days, ", "))
  end
  local function dump(title)
    print("  -- " .. title)
    local keys = {}
    for dk in pairs(DB.days) do table.insert(keys, dk) end
    table.sort(keys)
    for _, dk in ipairs(keys) do
      local names = {}
      for key, r in pairs(DB.days[dk]) do
        local ids = {}
        for _, q in ipairs(r.quests or {}) do table.insert(ids, q.id) end
        table.insert(names, key .. "(" .. r.count .. "개 " .. (r.money / G) .. "골드 보관함 " .. tostring(r.cacheCount) .. "/" .. tostring(r.cacheMoney and r.cacheMoney / G) .. " 퀘 " .. table.concat(ids, ",") .. ")")
      end
      table.sort(names)
      print("    days " .. dk .. ": " .. table.concat(names, " "))
    end
    local hk = {}
    for dk in pairs(DB.holdDays) do table.insert(hk, dk) end
    table.sort(hk)
    for _, dk in ipairs(hk) do
      local parts = {}
      for key, v in pairs(DB.holdDays[dk].chars) do table.insert(parts, key .. "=" .. (v / G)) end
      table.sort(parts)
      print("    holdDays " .. dk .. ": " .. table.concat(parts, " ") .. " warband=" .. tostring(DB.holdDays[dk].warband and DB.holdDays[dk].warband / G))
    end
    for _, key in ipairs({ A, B }) do
      local t = {}
      for q, v in pairs(DB.turnIns[key] or {}) do table.insert(t, q .. "@" .. (now - v)) end
      table.sort(t)
      print("    turnIns " .. key .. ": " .. table.concat(t, " ") .. " / flagDone " .. tostring(DB.flagDone and DB.flagDone[key] and DB.flagDone[key][7] and (now - DB.flagDone[key][7])))
      local g = {}
      for _, x in ipairs(DB.cacheGets[key] or {}) do table.insert(g, tostring(now - x.t)) end
      print("    cacheGets " .. key .. ": " .. table.concat(g, " "))
      print("    chars " .. key .. ": " .. tostring(DB.chars[key] and DB.chars[key].money / G))
    end
    for _, id in ipairs({ 11, 12 }) do
      local e = DB.activeGQ[id]
      local function f(t) local s = {} for k, v in pairs(t or {}) do table.insert(s, k .. "=" .. tostring(v == true and "true" or (now - v))) end table.sort(s) return table.concat(s, " ") end
      print("    activeGQ " .. id .. ": seenBy " .. f(e.seenBy) .. " / hiddenFor " .. f(e.hiddenFor) .. " / notGoldFor " .. f(e.notGoldFor))
    end
  end

  print("== 2) 기록 합치기 (옛이름 -> 새이름)")
  local before = totals()
  dump("합치기 전")
  local cg = OPTIONS.args.charGroup.args
  local function state(title)
    print("  " .. title .. ": 실행 " .. (cg.mergeRun.disabled() and "못 함" or "가능"))
  end
  state("아무것도 안 고름")
  cg.mergeFrom.set(nil, A); state("원본만 고름")
  cg.mergeTo.set(nil, A); state("원본과 대상이 같음")
  cg.mergeFrom.set(nil, "봄이간다-데스윙"); cg.mergeTo.set(nil, B); state("원본이 지금 접속한 캐릭터")
  cg.mergeFrom.set(nil, A); state("옛이름 -> 새이름")
  local vals = cg.mergeFrom.values()
  local vk = {}
  for k, v in pairs(vals) do table.insert(vk, k) end
  table.sort(vk)
  print("  고를 수 있는 캐릭터: " .. table.concat(vk, ", "))
  print("  확인 창:")
  for line in (cg.mergeRun.confirm() .. "\n"):gmatch("(.-)\n") do
    print("    " .. (line:gsub("|T.-|t", "골드")))
  end
  cg.mergeRun.func()
  local after = totals()
  dump("합친 뒤")
  print("  합계 전: " .. before)
  print("  합계 뒤: " .. after)
  print("  합계 같음: " .. tostring(before == after))
  print("  원본 고르기 비움: " .. tostring(QTR.mergeFrom) .. ", 대상 유지: " .. tostring(QTR.mergeTo))

  print("== 3) 다른 캐릭터를 합쳐도 합계는 같다 (중복 정리)")
  before = totals()
  QTR.MergeChars(C, B)
  after = totals()
  print("  합계 같음: " .. tostring(before == after) .. " / " .. after)
  print("  같은 캐릭터끼리는 아무것도 안 함: " .. tostring(QTR.MergeChars(B, B)))

  print("== 3b) 고르기 목록 순서와 빼는 캐릭터 (2026-10-31)")
  local saved = {}
  for k, v in pairs(DB.chars) do saved[k] = v end
  for _, k in ipairs({ "하늘-아즈샤라", "가람-아즈샤라", "나비-데스윙", "다솜-굴단", "마루-하이잘" }) do
    DB.chars[k] = { money = 0, realm = k:match("%-(.+)$"), name = k:match("^(.-)%-") }
  end
  local function order(opt)
    local vals, keys = opt.values(), opt.sorting()
    local n = 0
    for _ in pairs(vals) do n = n + 1 end
    print("    (값 " .. n .. "개, 순서 " .. #keys .. "개)")
    return table.concat(keys, ", ")
  end
  QTR.mergeFrom, QTR.mergeTo = nil, nil
  print("  지금 캐릭터: " .. tostring(QTR.charKeyForTest or "봄이간다-데스윙"))
  print("  관리 대상: " .. order(cg.target))
  print("  원본: " .. order(cg.mergeFrom))
  cg.mergeFrom.set(nil, "나비-데스윙")
  print("  원본 나비 고른 뒤 대상: " .. order(cg.mergeTo))
  cg.mergeTo.set(nil, "다솜-굴단")
  cg.mergeFrom.set(nil, "다솜-굴단")
  print("  대상과 같은 캐릭터를 원본으로 고르면 대상: " .. tostring(QTR.mergeTo) .. ", 실행 " .. (cg.mergeRun.disabled() and "못 함" or "가능"))
  QTR.mergeFrom, QTR.mergeTo = nil, nil
  for k in pairs(DB.chars) do DB.chars[k] = nil end
  for k, v in pairs(saved) do DB.chars[k] = v end

  print("== 4) 순증 추세 달성 예상")
  local function eta(title)
    QTR:UpdateHeader()
    local found
    for _, fs in ipairs(out) do
      local t = fs._text
      if type(t) == "string" and (t:find("보유량 감소 중") or t:find("변화 없음") or t:find("D%-") or t == "|cff808080-|r" or t:find("달성|r")) then found = (found and (found .. " | ") or "") .. t end
    end
    print("  " .. title .. ": " .. tostring(found and found:gsub("|c%x%x%x%x%x%x%x%x", "[색]"):gsub("|r", "")))
  end
  local today = date("%Y-%m-%d", now)
  local d3 = date("%Y-%m-%d", now - 3 * 86400)
  local total = 0
  for _, c in pairs(DB.chars) do total = total + (c.money or 0) end
  DB.snapshots = { [today] = total }
  eta("기록 1일 (-)")
  DB.snapshots = { [d3] = total + 3000 * G, [today] = total }
  eta("3일에 3,000골드 감소 (빨간 보유량 감소 중)")
  DB.snapshots = { [d3] = total, [today] = total }
  eta("변화 없음 (회색)")
  DB.snapshots = { [d3] = total - 3000 * G, [today] = total }
  eta("증가 (날짜)")
  DB.settings.goal = 100
  DB.snapshots = { [d3] = total + 3000 * G, [today] = total }
  eta("목표 달성이면 감소 중이어도 달성")

  print("== 5) 내비게이션 대기 화면: 넣을 골드퀘가 없으면 \"대시보드로 돌아가기\" (2026-10-30)")
  QuestsToRiches_ToggleDashboard() -- 대시보드를 닫아 둔다 (위에서 열렸으면)
  if QuestsToRichesFrame:IsShown() then QuestsToRiches_ToggleDashboard() end
  QTR.RoutePopupIdle()
  local btn
  for _, fr in ipairs(ALLFRAMES) do
    if rawget(fr, "_text") == "대시보드로 돌아가기" and rawget(fr, "_scr_OnClick") then btn = fr end
  end
  print("  버튼: " .. tostring(btn and btn._text) .. " / 내비게이션 창 보임 " .. tostring(QuestsToRichesRouteFrame:IsShown()))
  if btn then rawget(btn, "_scr_OnClick")(btn) end
  print("  누른 뒤: 내비게이션 창 보임 " .. tostring(QuestsToRichesRouteFrame:IsShown()) .. ", 대시보드 보임 " .. tostring(QuestsToRichesFrame:IsShown())
    .. ", 경로 " .. tostring(QTR.route))
  print("== end")
end''')(addon, out)
