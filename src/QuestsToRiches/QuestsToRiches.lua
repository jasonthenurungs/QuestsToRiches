-- QuestsToRiches (QTR, 골드퀘로 부자되기)
-- 골드 전역퀘와 정점 보관함으로 버는 골드를 캐릭터별로 기록하고 목표 골드 진행률을 보여준다.
--   골드퀘 탭  : 지금 접속한 캐릭터가 할 수 있는 골드퀘와 이번 주 특별 과제 (보상: 정점 보관함)
--   부자되기 탭: 지금 떠 있는 골드퀘와 이번 주 특별 과제를 다른 캐릭터 중 누가 아직 안 했는지
--   획득량 탭  : 기간별 수익과 캐릭터 기여도 / 보유량 탭: 날짜별 보유 골드
-- 골드퀘 판정 기준: 월드퀘스트이면서 완료 시 받은 골드가 500골드 이상
-- 기록은 자동으로 지우지 않고 계속 쌓는다. (설정창의 기록 전체 삭제로만 지운다)
-- 모든 설정(단축키 포함)은 계정 공통 저장 데이터에 두어 모든 서버, 모든 캐릭터에 같이 적용한다.

local ADDON_NAME = ...

-- 화면 문구 (Locales 폴더, 2026-10-31 영어 클라이언트 지원): L["한국어 원문"]
--   한국어 클라이언트는 원문 그대로, 그 밖의 클라이언트는 Locales\enUS.lua의 영어 (번역이 없으면 원문)
--   원문 뒤의 "##..."는 같은 한국어가 뜻이 다를 때 가르는 꼬리표라 화면에는 나오지 않는다 (예: "일##요일")
--   Locales 없이 불러도(테스트) 한국어로 돈다
local L = (select(2, ...) or {}).L or setmetatable({}, { __index = function(_, k) return (k:gsub("##.*$", "")) end })

-- 키 바인딩 이름 (게임 키 설정 화면의 애드온 항목에 표시)
_G["BINDING_HEADER_QUESTSTORICHES"] = "QuestsToRiches"
_G["BINDING_NAME_QUESTSTORICHES_DASHBOARD"] = L["창 열기/닫기"]
_G["BINDING_NAME_QUESTSTORICHES_CONFIG"] = L["설정창 열기/닫기"]
_G["BINDING_NAME_QUESTSTORICHES_ROUTE"] = L["내비게이션 창 열기/닫기"]
_G["BINDING_NAME_QUESTSTORICHES_NAVSTART"] = L["내비게이션 시작!"]

local AceAddon = LibStub("AceAddon-3.0")
local QTR = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0")
-- 게임 글자와 맞춰 보는 값 (클라이언트 언어별, Locales). 없으면 nil이라 부르는 곳의 한국어 값을 쓴다
QTR.GameText = (select(2, ...) or {}).GameText or function() return nil end
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local GOLD_THRESHOLD = 500 * 10000   -- 500골드 (단위: 코퍼)
local AVG_DAYS = 7                   -- 전역퀘 일평균 계산에 쓰는 최근 기록 일수
local TREND_DAYS = 7                 -- 보유 골드 추세 계산에 쓰는 최근 일수
local MAX_ETA_DAYS = 36500           -- 예상일 표시 상한 (100년)

-- 골드 아이콘 (글자 높이에 맞춰 표시, 숫자와 2픽셀 간격)
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"

-- 목록에서 정점 보관함 줄 이름 (영웅 등급 보라색)
local CACHE_LABEL = "|cffa335ee" .. L["특별 과제"] .. "|r" -- 골드퀘, 부자되기 탭의 특별 과제(보상: 정점 보관함) 묶음 이름

-- 목록 칸 위치 (x, 너비). 같은 종류의 값은 같은 칸에 맞춰 세로로 정렬된다.
--   name : 1단계 이름 (캐릭터 또는 퀘스트)
--   sub  : 2단계 이름 (들여쓰기한 퀘스트 또는 캐릭터)
--   mid  : 개수 또는 지역
--   gold : 골드 (오른쪽 정렬)
--   pct  : 비중 또는 인원 (오른쪽 정렬)
-- 캐릭터 이름 칸은 "여덟글자캐릭이름-아즈샤라"(최대 길이 이름 + 가장 흔한 서버명)가
-- 기본 글자 크기(12)에서 잘리지 않는 폭을 기준으로 잡는다. 이름 칸은 모두 x = 172에서 끝난다.
-- 서버명이 더 길면 보이는 데까지만 나오고 뒤는 "..."으로 잘린다.
-- 목록 오른쪽 끝(404)은 "4.보유량" 버튼 오른쪽 끝(창 x = 420)에 맞춘다. 스크롤바는 그 바깥 여백에 둔다.
local COL = {
    name = { x = 4, w = 168 },
    sub = { x = 20, w = 152 },
    mid = { x = 176, w = 102 },
    gold = { x = 280, w = 80 },
    pct = { x = 362, w = 42 },
    -- 획득량 탭의 최근 추이 줄: 기간 이름이 길어 넓게 쓴다
    period = { x = 20, w = 196 },
    periodCount = { x = 216, w = 60 },
    -- 순위가 붙는 목록(획득량 기여도, 보유량): 순위 칸(오른쪽 정렬) 다음에 캐릭터 이름
    rank = { x = 4, w = 18 },
    rankName = { x = 26, w = 146 },
    -- 골드퀘 탭의 퀘스트 줄: 퀘스트 이름을 넓게, 남은 시간은 오른쪽 정렬
    --   이름 칸은 시간 글자("2d 23h 12m", 약 70폭)가 안 쓰는 시간 칸 앞부분까지 쓴다 (영어 이름이 길다, 2026-10-31. 전에는 w 142)
    --   시간 칸 오른쪽 끝은 골드 글자 앞의 빈자리까지 당겨 300 (사용자 요청 2026-10-31, 전에는 276. 이름 칸도 그만큼 넓힘)
    gqQuest = { x = 20, w = 204 },
    gqTime = { x = 164, w = 136 },
    -- 정점 보관함 줄: "퀘스트명 (지역명)"이 길어서 이름 칸을 넓히고, 남은 시간 칸은 오른쪽 끝 276
    --   (골드퀘 줄은 300으로 옮겼지만 이 줄은 보상 칸에 "미개봉 1" 글자가 있어 그대로 둔다)
    cacheName = { x = 20, w = 166 },
    cacheTime = { x = 188, w = 88 },
    -- 부자되기 탭 정점 보관함 줄: 보상 칸에 아이콘만 있으므로 남은 시간을 아이콘 바로 앞(340)까지 옮겨 이름 칸을 넓힌다
    --   (골드퀘 탭 보관함 줄은 보상 칸에 "미개봉 1" 같은 글자가 있어 위의 cacheName, cacheTime 그대로, 2026-10-31)
    richCacheName = { x = 20, w = 235 },
    richCacheTime = { x = 250, w = 90 },
    -- 보유량 탭 상세: 접속 표시 / 보유 골드(조금 왼쪽) / 전일비 / 비중
    holdDot = { x = 176, w = 16 },
    holdGold = { x = 194, w = 82 },
    holdDiff = { x = 278, w = 56 },  -- 전일비 골드 (오른쪽 정렬, 골드 아이콘 없이)
    holdRank = { x = 337, w = 24 },  -- 전일비 순위 등락 (왼쪽 정렬, 전일비 골드와 마주 보게)
    holdPct = { x = 362, w = 42 },   -- 비중 (다른 탭의 pct와 같은 폭, "40.6%"가 잘리지 않게)
}
local LIST_WIDTH = 404

-- 창 세로 길이는 지금 탭의 내용에 맞춰 자동으로 바뀐다 (위쪽은 고정, 아래로만 늘고 준다. 가로는 고정)
-- 최대 높이에서도 내용이 넘치면 그때만 창 오른쪽 여백에 스크롤바가 나온다
local FRAME_WIDTH = 440
local FRAME_HEIGHT_MIN, FRAME_HEIGHT_MAX = 400, 700

-- 획득량 탭의 최근 추이 표시 개수
local TREND_COUNT = { day = 14, week = 8, month = 12, all = 12 }

local BIND_DASHBOARD = "QUESTSTORICHES_DASHBOARD"
local BIND_CONFIG = "QUESTSTORICHES_CONFIG"
local BIND_ROUTE = "QUESTSTORICHES_ROUTE"

local DB
local charKey
local selectedChar
local currentTab = "dash"
local statsMode = "week"
local statsPeriodKey
local pendingBindings = false

-------------------------------------------------------------------------------
-- 유틸
-------------------------------------------------------------------------------

local function Print(msg)
    print("|cffffd100[QTR]|r " .. tostring(msg))
end

local function CopperToGold(copper)
    return math.floor((copper or 0) / 10000)
end

local function FormatGold(copper)
    return BreakUpLargeNumbers(CopperToGold(copper)) .. GOLD_ICON
end

-- 골드퀘, 부자되기 탭 목록의 퀘스트별 금액 (흰색)
local function FormatSubGold(copper)
    return "|cffffffff" .. FormatGold(copper) .. "|r"
end

local function FormatSignedGold(copper)
    local gold = CopperToGold(math.abs(copper or 0))
    local sign = "+"
    if (copper or 0) < 0 then
        sign = "-"
    end
    return sign .. BreakUpLargeNumbers(gold) .. GOLD_ICON
end

-- 날짜 키: 컴퓨터 시계의 0시 기준 날짜 (예전에는 와우 일일 초기화 시각 기준이었다)
local function GetDayKey()
    return date("%Y-%m-%d", time())
end

-- 날짜 키를 그날 정오의 시각 값으로 바꾼다 (날짜 계산용)
local function DayKeyToTime(key)
    local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function TimeToKey(t)
    return date("%Y-%m-%d", t)
end

-- 아무 시각 t가 속한 날짜 키 (0시 기준, GetDayKey와 같은 방식)
local function TimeToDayKey(t)
    return date("%Y-%m-%d", t)
end

-- 요일 (date의 %w: 0 = 일요일 ... 6 = 토요일)
local WEEKDAY_NAMES = { L["일##요일"], L["월##요일"], L["화##요일"], L["수##요일"], L["목##요일"], L["금##요일"], L["토##요일"] }

local function GetWeekdayName(t)
    return WEEKDAY_NAMES[tonumber(date("%w", t)) + 1]
end

-- 주말 요일 색: 채도를 끝까지 올린 파랑, 빨강
-- 파랑은 순수한 파랑(0000FF)이 검은 배경에서 너무 어두워, 채도와 밝기가 모두 최대인 파랑을 쓴다.
local WEEKEND_COLORS = {
    [L["토##요일"]] = "|cff0080ff",
    [L["일##요일"]] = "|cffff0000",
}

local function GetWeekendColor(name)
    return WEEKEND_COLORS[name]
end

-- 요일 표시 "(토)": 토요일, 일요일만 색을 입힌다.
-- 날짜 전체에 색이 입혀진 곳(baseColor)에서는 요일 색이 끝난 뒤 그 색을 다시 켠다.
local function FormatWeekday(t, baseColor)
    local name = GetWeekdayName(t)
    local color = GetWeekendColor(name)
    if not color then
        return "(" .. name .. ")"
    end
    return color .. "(" .. name .. ")|r" .. (baseColor or "")
end

-- 날짜 표시: "2026-10-16 (금)", short이면 "10-16 (금)" (요일 앞은 항상 한 칸 띄운다)
local function FormatDate(t, short, baseColor)
    if short then
        return date("%m-%d", t) .. " " .. FormatWeekday(t, baseColor)
    end
    return date("%Y-%m-%d", t) .. " " .. FormatWeekday(t, baseColor)
end

local function FormatDayKey(key, short, baseColor)
    return FormatDate(DayKeyToTime(key), short, baseColor)
end

local function DaysBetween(fromKey, toKey)
    return math.floor((DayKeyToTime(toKey) - DayKeyToTime(fromKey)) / 86400 + 0.5)
end

-- 주간 초기화 요일 (0 = 일요일 ... 6 = 토요일)
local function GetWeeklyResetWeekday()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local s = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if s and s > 0 then
            return tonumber(date("%w", time() + s))
        end
    end
    return 4 -- API를 못 쓸 때의 대체값: 목요일
end

-- 날짜 키가 속한 주(주간 초기화 기준)의 시작 날짜 키
local function GetWeekKey(dayKey)
    local t = DayKeyToTime(dayKey)
    local wd = tonumber(date("%w", t))
    local offset = (wd - GetWeeklyResetWeekday()) % 7
    return TimeToKey(t - offset * 86400)
end

local function GetPeriodKey(dayKey, mode)
    if mode == "week" then
        return GetWeekKey(dayKey)
    elseif mode == "month" then
        return dayKey:sub(1, 7)
    elseif mode == "all" then
        return "all"
    end
    return dayKey
end

-- 기간 표시: short이면 목록용 짧은 형태 (주별만 짧아진다)
-- baseColor: 기간 글자 전체에 입힌 색 (주말 요일 색이 끝난 뒤 다시 켠다)
local function GetPeriodLabel(mode, key, short, baseColor)
    if mode == "week" then
        local startTime = DayKeyToTime(key)
        local endTime = startTime + 6 * 86400
        if short then
            return FormatDate(startTime, true, baseColor) .. " ~ " .. FormatDate(endTime, true, baseColor)
        end
        return FormatDate(startTime, false, baseColor) .. " ~ " .. FormatDate(endTime, true, baseColor)
    elseif mode == "day" then
        return FormatDayKey(key, false, baseColor)
    elseif mode == "all" then
        -- 기록이 모인 기간: "전체 (26/10/15 ~ 26/10/29, 15일)" (첫 기록 날부터 오늘까지, 2026-10-29 사용자 요청)
        local first
        for dayKey in pairs(DB and DB.days or {}) do
            if not first or dayKey < first then
                first = dayKey
            end
        end
        if not first then
            return L["전체"]
        end
        local today = GetDayKey()
        local last = (first > today) and first or today
        local function short(k)
            return (k:sub(3):gsub("%-", "/"))
        end
        return L["전체 (%s ~ %s, %d일)"]:format(short(first), short(last), DaysBetween(first, last) + 1)
    end
    return key
end

local function GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm, name, realm
end

local function FormatPercent(part, whole)
    if not whole or whole <= 0 then
        return "0.0%"
    end
    local pct = part / whole * 100
    -- 100%는 소수점을 빼서 칸(폭 42)에 들어가게 한다
    if pct >= 99.95 then
        return string.format("%d%%", math.floor(pct + 0.5))
    end
    return string.format("%.1f%%", pct)
end

-------------------------------------------------------------------------------
-- 저장 데이터 (QuestsToRichesDB, 계정 공통)
-- chars[캐릭터키]        = { name, realm, class, money, lastSeen }
--                         귀환석: hearthUses = { 사용 시각 }, hearthCD, hearthCDGuild
--                         (hearth = { name, c, x, y, t }: 예전 시험판의 캐릭터별 귀환 지점, 지금은 hearthBinds로 옮겨 쓴다)
-- hearthBinds[여관 이름]  = { c, x, y, t } 귀환석으로 내린 곳 (계정 공용, 같은 여관을 쓰는 모든 캐릭터)
-- days[날짜키][캐릭터키] = { count, money, quests = { { id, name, zone, money, t } } }
-- snapshots[날짜키]      = 그날 마지막으로 확인한 계정 총 보유 골드 (코퍼)
-- holdDays[날짜키]       = { chars = { [캐릭터키] = 골드 }, warband = 골드 }
--   그날 마지막으로 확인한 캐릭터별, 전투부대 은행 보유 골드 (코퍼). 보유량 탭의 날짜별 보기에 쓴다.
--   그날 접속하지 않은 캐릭터는 들어 있지 않고, 보여줄 때 그 이전 기록을 쓴다.
-- turnIns, cacheSources, cacheGets, cacheKnown: 정점 보관함 부분 설명 참고
-- activeGQ[퀘스트ID]      = { name, zone, mapID, money, expire } 어느 캐릭터로든 본 현재 골드 전역퀘
-- gqPrevExpire[퀘스트ID]  = 그 퀘스트 직전 회차의 만료 시각 (이번 회차 완료 판정의 시작점)
-- settings               = { goal, chatNotify, alpha, frameLocked, pos(창 왼쪽 위 기준), keys = { dashboard, config, route, navStart } }
--   goal: 목표 골드 (골드 단위, 1 ~ GOAL_MAX). 예전 goalMan(만 골드 단위)은 처음 한 번 옮겨 온다.
--   dashPinned, navPinned: 대시보드, 내비게이션 창 고정 (Esc로 닫히지 않음). dashScale, navScale: 두 창의 크기 배율 (기본 1)
--   holdNoWarband: 이 계정 보유량에 전투부대 은행 넣지 않기 (QTR.WarbandCounted 참고)
--
-- 이전 이름(GoldQuestMakeMeRich, RoadToGold5M)의 저장 파일을 새 이름(QuestsToRiches.lua)으로 바꿔 넣으면
-- 그 안의 이전 변수(GoldQuestMakeMeRichDB, RoadToGold5MDB)가 함께 읽힌다.
-- 새 저장 데이터가 없을 때 한 번만 옮겨 오고(최근 이름 우선), 이전 변수는 비운다.
-------------------------------------------------------------------------------

local DEFAULT_GOAL = 5000000  -- 기본 목표 500만 골드
local GOAL_MAX = 999999999    -- 목표 상한 (약 10억 골드). 코퍼로 바꿔도 계산 오차가 없는 범위 안
local migratedFrom

-- 날짜 기준을 와우 일일 초기화 시각에서 0시로 바꾸면서 저장된 기록의 날짜를 다시 나눈다 (한 번만)
--   전역퀘, 정점 보관함: 기록마다 시각(t)이 있어 그 시각의 0시 기준 날짜로 옮긴다. 시각이 없으면 그대로 둔다.
--   보유량(holdDays): 시각이 없어, 캐릭터마다 가장 최근 기록만 마지막 접속 시각(lastSeen)의 날짜로 옮긴다.
--   계정 합계(snapshots): 시각이 없어 그대로 둔다.
local function MigrateToMidnight()
    if DB.dayBoundary == "midnight" then
        return
    end
    local newDays = {}
    local function GetRec(dayKey, key)
        newDays[dayKey] = newDays[dayKey] or {}
        local rec = newDays[dayKey][key]
        if not rec then
            rec = { count = 0, money = 0, quests = {}, cacheCount = 0, cacheMoney = 0, caches = {}, extraCount = 0, extraMoney = 0, extraCacheCount = 0 }
            newDays[dayKey][key] = rec
        end
        return rec
    end
    for dayKey, day in pairs(DB.days) do
        for key, rec in pairs(day) do
            local questMoney, cacheMoney = 0, 0
            for _, q in ipairs(rec.quests or {}) do
                local target = GetRec(q.t and TimeToDayKey(q.t) or dayKey, key)
                table.insert(target.quests, q)
                questMoney = questMoney + (q.money or 0)
            end
            for _, c in ipairs(rec.caches or {}) do
                local target = GetRec(c.t and TimeToDayKey(c.t) or dayKey, key)
                table.insert(target.caches, c)
                cacheMoney = cacheMoney + (c.money or 0)
            end
            -- 목록 없이 개수, 골드만 남은 예전 기록은 원래 날짜에 그대로 둔다
            local here = GetRec(dayKey, key)
            here.extraCount = here.extraCount + math.max((rec.count or 0) - #(rec.quests or {}), 0)
            here.extraCacheCount = here.extraCacheCount + math.max((rec.cacheCount or 0) - #(rec.caches or {}), 0)
            here.extraMoney = here.extraMoney + math.max((rec.money or 0) - questMoney - cacheMoney, 0)
        end
    end
    -- 개수와 합계 다시 계산
    for dayKey, day in pairs(newDays) do
        for key, rec in pairs(day) do
            local qm, cm = 0, 0
            for _, q in ipairs(rec.quests) do
                qm = qm + (q.money or 0)
            end
            for _, c in ipairs(rec.caches) do
                cm = cm + (c.money or 0)
            end
            rec.count = #rec.quests + rec.extraCount
            rec.cacheCount = #rec.caches + rec.extraCacheCount
            rec.cacheMoney = cm
            rec.money = qm + cm + rec.extraMoney
            rec.extraCount, rec.extraMoney, rec.extraCacheCount = nil, nil, nil
            if #rec.caches == 0 and rec.cacheCount == 0 then
                rec.caches, rec.cacheCount, rec.cacheMoney = nil, nil, nil
            end
            if rec.count == 0 and (rec.cacheCount or 0) == 0 and rec.money == 0 then
                day[key] = nil
            end
        end
        if next(day) == nil then
            newDays[dayKey] = nil
        end
    end
    DB.days = newDays

    for key, c in pairs(DB.chars) do
        if c.lastSeen then
            local latest
            for dayKey, h in pairs(DB.holdDays) do
                if h.chars and h.chars[key] and (not latest or dayKey > latest) then
                    latest = dayKey
                end
            end
            local target = TimeToDayKey(c.lastSeen)
            if latest and latest ~= target then
                local money = DB.holdDays[latest].chars[key]
                DB.holdDays[latest].chars[key] = nil
                if next(DB.holdDays[latest].chars) == nil and not DB.holdDays[latest].warband then
                    DB.holdDays[latest] = nil
                end
                DB.holdDays[target] = DB.holdDays[target] or { chars = {} }
                DB.holdDays[target].chars[key] = money
            end
        end
    end
    DB.dayBoundary = "midnight"
end

local function InitDB()
    if QuestsToRichesDB == nil then
        if type(GoldQuestMakeMeRichDB) == "table" then
            QuestsToRichesDB = GoldQuestMakeMeRichDB
            migratedFrom = "GoldQuestMakeMeRich"
        elseif type(RoadToGold5MDB) == "table" then
            QuestsToRichesDB = RoadToGold5MDB
            migratedFrom = "RoadToGold5M"
        end
    end
    GoldQuestMakeMeRichDB = nil
    RoadToGold5MDB = nil
    QuestsToRichesDB = QuestsToRichesDB or {}
    DB = QuestsToRichesDB
    -- 1.7.0: 이동 수단 채팅 알림을 한 번 끄고, 예전부터 쓰던 사람에게만 접속할 때 한 번 알린다 (2026-11-08 사용자 요청)
    --   1.6.2까지는 "동선에 넣었습니다", "귀환석은 넣지 않았습니다"가 늘 나왔고, 1.7.0부터는 설정(기본 끔)을 켰을 때만 나온다
    if not DB.whyNotice170 then
        DB.whyNotice170 = true
        if DB.settings then
            DB.settings.travelWhyOn = nil
        end
        QTR.whyNotice = DB.chars ~= nil and next(DB.chars) ~= nil
    end
    DB.chars = DB.chars or {}
    DB.days = DB.days or {}
    DB.snapshots = DB.snapshots or {}
    DB.settings = DB.settings or {}
    -- 날짜별 보유량 기록: 처음 만들 때는 캐릭터마다 마지막으로 확인한 날에 지금 저장된 값을 넣어 둔다
    if not DB.holdDays then
        DB.holdDays = {}
        for key, c in pairs(DB.chars) do
            if c.money and c.lastSeen then
                local dk = TimeToDayKey(c.lastSeen)
                DB.holdDays[dk] = DB.holdDays[dk] or { chars = {} }
                DB.holdDays[dk].chars[key] = c.money
            end
        end
        if DB.warbandMoney then
            local dk = GetDayKey()
            DB.holdDays[dk] = DB.holdDays[dk] or { chars = {} }
            DB.holdDays[dk].warband = DB.warbandMoney
        end
    end
    MigrateToMidnight()
    DB.cacheKnown = nil                     -- 예전: 툴팁으로 인식한 정점 보관함 (자동 인식을 없애 지운다)
    DB.cacheSources = DB.cacheSources or {} -- 보관함을 주는 출처 (특별 과제 퀘스트)
    DB.cacheGets = DB.cacheGets or {}       -- 캐릭터별 보관함 획득 기록
    DB.activeGQ = DB.activeGQ or {}         -- 어느 캐릭터로든 본 현재 골드 전역퀘 (만료되면 지운다)
    DB.gqPrevExpire = DB.gqPrevExpire or {} -- 골드 전역퀘의 직전 회차 만료 시각
    -- 캐릭터별 퀘스트 완료 시각: 처음 만들 때는 지금까지의 골드 전역퀘 기록에서 채운다
    if not DB.turnIns then
        DB.turnIns = {}
        for _, day in pairs(DB.days) do
            for key, rec in pairs(day) do
                for _, q in ipairs(rec.quests or {}) do
                    if q.id and q.t then
                        DB.turnIns[key] = DB.turnIns[key] or {}
                        DB.turnIns[key][q.id] = math.max(DB.turnIns[key][q.id] or 0, q.t)
                    end
                end
            end
        end
    end
    -- 퀘스트 완료 시각은 30일이 지나면 지운다 (완료 판정은 이번 회차, 이번 주만 본다)
    -- 예전 버전이 모든 퀘스트를 저장했던 것은 한 번 정리한다: 골드퀘 기록, 보관함 출처, 현재 골드퀘에 있는 퀘스트만 남긴다
    local keep
    if not DB.turnInsSlim then
        keep = {}
        for _, day in pairs(DB.days) do
            for _, rec in pairs(day) do
                for _, q in ipairs(rec.quests or {}) do
                    if q.id then
                        keep[q.id] = true
                    end
                end
            end
        end
        for _, src in pairs(DB.cacheSources) do
            if src.questID then
                keep[src.questID] = true
            end
        end
        for questID in pairs(DB.activeGQ) do
            keep[questID] = true
        end
        DB.turnInsSlim = true
    end
    local cutoff = time() - 30 * 86400
    for _, list in pairs(DB.turnIns) do
        for questID, t in pairs(list) do
            if t < cutoff or (keep and not keep[questID]) then
                list[questID] = nil
            end
        end
    end
    -- 게임이 완료로 본 퀘스트(QTR 완료 기록 없음): { [캐릭터키] = { [퀘스트ID] = 그렇게 본 시각 } }, 완료 시각처럼 30일 뒤 지운다
    DB.flagDone = DB.flagDone or {}
    -- 게임의 완료 표시를 믿지 않는 퀘스트(리에드린 주간, QTR.SILVERMOON_NOFLAG_IDS)는 예전에 남긴 것도 지운다
    for _, list in pairs(DB.flagDone) do
        for questID, t in pairs(list) do
            if t < cutoff or QTR.SILVERMOON_NOFLAG_IDS[questID] then
                list[questID] = nil
            end
        end
    end
    -- 실버문 주간 퀘스트를 퀘스트 목록에 받아 둔 캐릭터: { [캐릭터키] = { t = 본 시각, ids = { [퀘스트ID] = true }, prog = { [퀘스트ID] = 진행도 } } }
    --   그 캐릭터로 접속했을 때의 모습 (QTR.ScanWeeklyFlags가 매번 새로 쓴다, 2026-11-01)
    --   진행도: { f = 채운 수, r = 필요 수 } 또는 { p = 퍼센트 } (QTR.QuestProgress)
    DB.weeklyOn = DB.weeklyOn or {}
    -- 특별 과제 잠김 상태 (부자되기 탭 "잠김(n/3)", 2026-11-01): { [캐릭터키] = { [지역 지도] = { t = 본 시각, open = 해금했나, p = 진행도, q = 특별 과제 퀘스트 ID } } }
    --   그 캐릭터로 지도를 읽었을 때의 모습 (CollectGoldQuests가 새로 쓴다)
    DB.saLock = DB.saLock or {}
    local s = DB.settings
    if type(s.goal) ~= "number" then
        s.goal = (type(s.goalMan) == "number" and s.goalMan >= 1) and s.goalMan * 10000 or DEFAULT_GOAL
    end
    s.goal = math.max(1, math.min(GOAL_MAX, math.floor(s.goal)))
    s.goalMan = nil
    s.groupBy, s.detail, s.showDetail = nil, nil, nil -- 예전 부자되기 탭(날짜별 기록) 설정
    if s.tab ~= "gq" and s.tab ~= "dash" and s.tab ~= "stats" and s.tab ~= "hold" then s.tab = "gq" end -- 마지막으로 본 탭
    if s.holdMode ~= "sum" and s.holdMode ~= "detail" then s.holdMode = "sum" end -- 보유량 탭 보기: 요약 / 상세
    if s.chatNotify == nil then s.chatNotify = true end
    if s.alpha == nil then s.alpha = 0.8 end
    s.fontSize = nil -- 예전 목록 글자 크기 설정 (창 세로 길이 설정으로 대체)
    -- s.frameHeight: 예전 버전의 창 세로 길이 설정. 이제는 내용에 맞춰 자동으로 정한다.
    -- 예전 위치(창 가운데 기준)를 왼쪽 위 기준으로 바꿀 때 한 번 쓰고 지운다 (ApplyFramePosition)
    s.keys = s.keys or {}
    s.navSound, s.navSoundCustom = nil, nil -- 예전 시험판의 완료 소리 선택 (지금은 켜고 끄기만 한다: navSoundOff)
    if s.cacheAlert == nil then s.cacheAlert = true end
    s.cacheItems = nil -- 예전: 사용자가 직접 등록한 정점 보관함 (직접 등록을 없애 지운다)
    s.bannedQuests = s.bannedQuests or {} -- 추적에서 제외할 퀘스트 { [퀘스트ID] = 이름 }
    s.bannedZones = s.bannedZones or {}   -- 제외한 퀘스트의 지역 { [퀘스트ID] = 지역 이름 } ("퀘스트명 (지역명)" 표시용)
    if s.hideBanned == nil then s.hideBanned = true end -- 제외 목록 적용 (끄면 목록은 두고 다시 보여준다)
    QTR.CleanupCacheData()
end

-- 오늘 이 캐릭터의 기록 (없으면 만든다)
-- 기록 형식: { count, money, quests, cacheCount, cacheMoney, caches }
--   count  : 골드 전역퀘 개수
--   money  : 골드퀘 수익 합계 (전역퀘 + 정점 보관함, 코퍼)
--   caches : 정점 보관함 { { id, money, t } }
local function GetTodayRecord()
    local dayKey = GetDayKey()
    DB.days[dayKey] = DB.days[dayKey] or {}
    local rec = DB.days[dayKey][charKey]
    if not rec then
        rec = { count = 0, money = 0, quests = {} }
        DB.days[dayKey][charKey] = rec
    end
    return rec
end

-- 현재 캐릭터 정보와 보유 골드 저장
-- 로그아웃 시점에는 GetMoney 값을 믿을 수 없어 저장하지 않는다. (접속 직후와 골드 변동 시에만 저장)
local function UpdateCharInfo()
    if not DB or not charKey then
        return
    end
    local money = GetMoney()
    if type(money) ~= "number" then
        return
    end
    local _, name, realm = GetCharKey()
    local _, classFile = UnitClass("player")
    local c = DB.chars[charKey] or {}
    c.name = name
    c.realm = realm
    c.class = classFile
    c.level = UnitLevel("player") -- 보관함 탭에서 만렙 캐릭터만 추리는 데 쓴다
    c.money = money
    c.lastSeen = time()
    -- 캐릭터 GUID: 저장만 한다 (2026-10-29. 이름을 바꿔도 GUID가 같은지 확인한 뒤 옛 이름 기록 자동 합치기 제안에 쓸 예정. 화면에는 쓰지 않는다)
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, "player")
        -- 한밤의 비밀 값이면 저장하지 않는다 (자기 캐릭터라 그럴 일은 없을 것으로 보지만 확인 불가)
        if ok and not (issecretvalue and issecretvalue(guid)) and type(guid) == "string" and guid ~= "" then
            c.guid = guid
        end
    end
    DB.chars[charKey] = c
end

local function UpdateWarbandMoney()
    if not DB then
        return
    end
    if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType and Enum.BankType.Account then
        local ok, value = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
        if ok and type(value) == "number" then
            DB.warbandMoney = value
        end
    end
end

-- 이 계정 보유량에 전투부대 은행을 넣는지 (2026-11-03 사용자 결정, SF작가님 요청: 하위 계정 두 개의 골드 합이 중복됨)
--   한 와우 계정의 하위 계정(WoW1, WoW2)은 전투부대 은행을 함께 써서, 계정마다 넣으면 두 계정 합에 은행이 두 번 들어간다.
--   설정(DB.settings.holdNoWarband)은 저장 파일, 즉 계정마다 따로라 한 계정에서만 은행을 넣으면 된다.
--   기록(snapshots, holdDays)은 늘 은행을 포함해 남기고 보여 줄 때 뺀다 (설정을 껐다 켜도 지난 기록이 맞게).
function QTR.WarbandCounted()
    return not DB.settings.holdNoWarband
end

-- dayKey 날짜의 계정 합계 기록 (snapshots). 은행을 넣지 않으면 그날까지의 마지막 은행 기록(holdDays.warband)을 뺀다
--   RecordSnapshot이 두 값을 같은 순간에 쓰므로 같은 날 값끼리 맞는다.
--   그날 이전 은행 기록이 없으면(날짜별 보유량 기록을 만들기 전의 합계) 가장 오래된 은행 기록을 뺀다.
function QTR.SnapshotAt(dayKey)
    local total = DB.snapshots[dayKey]
    if not total or QTR.WarbandCounted() then
        return total
    end
    local lastKey, firstKey
    for k, h in pairs(DB.holdDays) do
        if h.warband then
            if k <= dayKey and (not lastKey or k > lastKey) then
                lastKey = k
            end
            if not firstKey or k < firstKey then
                firstKey = k
            end
        end
    end
    local k = lastKey or firstKey
    return total - (k and DB.holdDays[k].warband or 0)
end

-- raw: 설정과 상관없이 은행을 넣는다 (기록용)
local function GetAccountTotals(raw)
    local charSum = 0
    for _, c in pairs(DB.chars) do
        charSum = charSum + (c.money or 0)
    end
    local warband = (raw or QTR.WarbandCounted()) and DB.warbandMoney or 0
    return charSum + warband, charSum, warband
end

local function RecordSnapshot()
    if not DB or not charKey then
        return
    end
    local total = GetAccountTotals(true) -- 기록은 늘 은행 포함 (보여 줄 때 QTR.SnapshotAt이 뺀다)
    local today = GetDayKey()
    DB.snapshots[today] = total
    -- 보유량 탭의 날짜별 보기: 현재 캐릭터와 전투부대 은행의 그날 마지막 값
    local h = DB.holdDays[today] or { chars = {} }
    DB.holdDays[today] = h
    local c = DB.chars[charKey]
    if c and type(c.money) == "number" then
        h.chars[charKey] = c.money
    end
    if type(DB.warbandMoney) == "number" then
        h.warband = DB.warbandMoney
    end
end

-- 캐릭터 하나의 날짜별 보유량 기록이 있는지 / 지우기 (그 캐릭터만 있던 날은 날짜째 지운다)
local function HasHoldRecord(key)
    for _, h in pairs(DB.holdDays) do
        if h.chars and h.chars[key] then
            return true
        end
    end
    return false
end

local function DeleteHoldRecords(key)
    for dayKey, h in pairs(DB.holdDays) do
        if h.chars then
            h.chars[key] = nil
        end
        if (not h.chars or next(h.chars) == nil) and not h.warband then
            DB.holdDays[dayKey] = nil
        end
    end
end

-- 캐릭터 기록 합치기 (2026-10-29 사용자 요청, 인벤 댓글: 이름을 바꾸면 두 캐릭터로 중복 표시됨)
--   원본 a의 기록을 대상 b에 합치고 a의 기록은 모두 지운다. 이름 변경뿐 아니라 중복 정리에도 쓰는 일반 기능
--   days: 같은 날 둘 다 있으면 골드퀘, 보관함 목록을 잇고 개수와 골드를 더한다 (목록 없이 개수만 남은 예전 기록도 그대로 더해진다)
--   holdDays: 같은 날 둘 다 있으면 b 값을 남긴다 (b가 없는 날만 a 값을 옮긴다)
--   turnIns, flagDone: 같은 퀘스트를 둘 다 완료했으면 더 늦은 시각
--   cacheGets: 잇고 시각 순으로
--   weeklyOn: 더 늦게 본 쪽
--   saLock: 지역마다 더 늦게 본 쪽
--   activeGQ: seenBy는 더 늦은 시각. hiddenFor, notGoldFor는 b가 그 퀘스트를 본 적이 없을 때만 옮긴다 (b가 직접 본 것이 더 새롭다)
--   chars: b는 그대로, a는 지운다
-- 설정창 "캐릭터 관리"의 캐릭터 고르기 목록 (관리 대상, 합치기 원본과 대상이 같이 쓴다)
--   목록에서 제거한 캐릭터도 기록이 남아 있으면 고를 수 있게 한다 (완료 기록만 남은 캐릭터도, 2026-10-29)
function QTR.charOptValues()
    local values = {}
    for key in pairs(DB.chars) do
        values[key] = key
    end
    local function AddRecorded(key)
        if not values[key] then
            values[key] = key .. L[" |cff808080(목록에 없음)|r"]
        end
    end
    for _, day in pairs(DB.days) do
        for key in pairs(day) do
            AddRecorded(key)
        end
    end
    for _, h in pairs(DB.holdDays) do
        for key in pairs(h.chars or {}) do
            AddRecorded(key)
        end
    end
    for key in pairs(DB.turnIns) do
        AddRecorded(key)
    end
    return values
end

-- 합치기 원본 목록: 지금 접속한 캐릭터는 넣지 않는다 (2026-10-31 사용자 요청: 고를 수 없는 캐릭터는 아예 안 보이게)
function QTR.mergeFromValues()
    local values = QTR.charOptValues()
    if charKey then
        values[charKey] = nil
    end
    return values
end

-- 합치기 대상 목록: 고른 원본은 넣지 않는다 (같은 캐릭터끼리는 합칠 수 없으므로)
function QTR.mergeToValues()
    local values = QTR.charOptValues()
    if QTR.mergeFrom then
        values[QTR.mergeFrom] = nil
    end
    return values
end

-- QTR.MergePreview는 확인 창에 보여 줄 숫자 (실제로 바꾸지 않는다)
function QTR.MergePreview(a, b)
    local p = { days = 0, quests = 0, caches = 0, money = 0, sameDays = 0, holdDays = 0, holdKept = 0, turnIns = 0 }
    for _, day in pairs(DB.days) do
        local ra = day[a]
        if ra then
            p.days = p.days + 1
            p.quests = p.quests + (ra.count or 0)
            p.caches = p.caches + (ra.cacheCount or 0)
            p.money = p.money + (ra.money or 0)
            if day[b] then
                p.sameDays = p.sameDays + 1
            end
        end
    end
    for _, h in pairs(DB.holdDays) do
        if h.chars and h.chars[a] then
            if h.chars[b] then
                p.holdKept = p.holdKept + 1
            else
                p.holdDays = p.holdDays + 1
            end
        end
    end
    for _ in pairs(DB.turnIns[a] or {}) do
        p.turnIns = p.turnIns + 1
    end
    return p
end

function QTR.MergeChars(a, b)
    if not a or not b or a == b then
        return false
    end
    local function later(x, y)
        if x and y then
            return math.max(x, y)
        end
        return x or y
    end
    local function byTime(x, y)
        return (x.t or 0) < (y.t or 0)
    end
    for _, day in pairs(DB.days) do
        local ra, rb = day[a], day[b]
        if ra then
            if not rb then
                day[b] = ra
            else
                rb.quests = rb.quests or {}
                for _, q in ipairs(ra.quests or {}) do
                    table.insert(rb.quests, q)
                end
                table.sort(rb.quests, byTime)
                if ra.caches then
                    rb.caches = rb.caches or {}
                    for _, c in ipairs(ra.caches) do
                        table.insert(rb.caches, c)
                    end
                    table.sort(rb.caches, byTime)
                end
                rb.count = (rb.count or 0) + (ra.count or 0)
                rb.money = (rb.money or 0) + (ra.money or 0)
                if ra.cacheCount or rb.cacheCount then
                    rb.cacheCount = (rb.cacheCount or 0) + (ra.cacheCount or 0)
                    rb.cacheMoney = (rb.cacheMoney or 0) + (ra.cacheMoney or 0)
                end
            end
            day[a] = nil
        end
    end
    for _, h in pairs(DB.holdDays) do
        if h.chars and h.chars[a] then
            if h.chars[b] == nil then
                h.chars[b] = h.chars[a]
            end
            h.chars[a] = nil
        end
    end
    for _, store in ipairs({ DB.turnIns, DB.flagDone or {} }) do
        if store[a] then
            store[b] = store[b] or {}
            for questID, t in pairs(store[a]) do
                store[b][questID] = later(store[b][questID], t)
            end
            store[a] = nil
        end
    end
    -- weeklyOn: 더 늦게 본 쪽을 남긴다
    local wa, wb = DB.weeklyOn and DB.weeklyOn[a], DB.weeklyOn and DB.weeklyOn[b]
    if wa then
        if not wb or (wa.t or 0) > (wb.t or 0) then
            DB.weeklyOn[b] = wa
        end
        DB.weeklyOn[a] = nil
    end
    -- saLock: 지역마다 더 늦게 본 쪽을 남긴다
    local la = DB.saLock and DB.saLock[a]
    if la then
        DB.saLock[b] = DB.saLock[b] or {}
        for mapID, s in pairs(la) do
            local o = DB.saLock[b][mapID]
            if not o or (s.t or 0) > (o.t or 0) then
                DB.saLock[b][mapID] = s
            end
        end
        DB.saLock[a] = nil
    end
    if DB.cacheGets[a] then
        DB.cacheGets[b] = DB.cacheGets[b] or {}
        for _, g in ipairs(DB.cacheGets[a]) do
            table.insert(DB.cacheGets[b], g)
        end
        table.sort(DB.cacheGets[b], byTime)
        DB.cacheGets[a] = nil
    end
    for _, e in pairs(DB.activeGQ) do
        local bSeen = e.seenBy and e.seenBy[b]
        if e.seenBy and e.seenBy[a] then
            e.seenBy[b] = later(e.seenBy[b], e.seenBy[a])
            e.seenBy[a] = nil
        end
        for _, field in ipairs({ "hiddenFor", "notGoldFor" }) do
            local t = e[field]
            if t and t[a] ~= nil then
                if not bSeen and t[b] == nil then
                    t[b] = t[a]
                end
                t[a] = nil
            end
        end
    end
    DB.chars[a] = nil
    return true
end

local function GetSortedDayKeys()
    local keys = {}
    local today = GetDayKey()
    local hasToday = false
    for k in pairs(DB.days) do
        table.insert(keys, k)
        if k == today then
            hasToday = true
        end
    end
    if not hasToday then
        table.insert(keys, today)
    end
    table.sort(keys)
    return keys
end

local function GetStoredDayCount()
    local n = 0
    for _ in pairs(DB.days) do
        n = n + 1
    end
    return n
end

-- 하루 합계: 전역퀘 개수, 골드퀘 수익(코퍼), 정점 보관함 개수
local function GetDayTotal(dayKey)
    local count, money, cacheCount = 0, 0, 0
    local day = DB.days[dayKey]
    if day then
        for _, rec in pairs(day) do
            count = count + (rec.count or 0)
            money = money + (rec.money or 0)
            cacheCount = cacheCount + (rec.cacheCount or 0)
        end
    end
    return count, money, cacheCount
end

-- 최근 기록 numDays일 중 수익이 있었던 날 기준 골드퀘 수익 일평균 (코퍼)
local function GetRecentAverage(numDays)
    local keys = GetSortedDayKeys()
    local sum, active = 0, 0
    local startIndex = math.max(1, #keys - numDays + 1)
    for i = startIndex, #keys do
        local _, money = GetDayTotal(keys[i])
        if money > 0 then
            sum = sum + money
            active = active + 1
        end
    end
    if active == 0 then
        return 0
    end
    return sum / active
end

-- 보유 골드 하루 증가량 (최근 TREND_DAYS일 안의 가장 오래된 기록과 가장 최근 기록 비교, 코퍼)
-- 기록이 2일치 미만이면 nil
local function GetHoldingTrend()
    local keys = {}
    for k in pairs(DB.snapshots) do
        table.insert(keys, k)
    end
    table.sort(keys)
    if #keys < 2 then
        return nil
    end
    local lastKey = keys[#keys]
    local firstKey
    for _, k in ipairs(keys) do
        if DaysBetween(k, lastKey) <= TREND_DAYS then
            firstKey = k
            break
        end
    end
    if not firstKey or firstKey == lastKey then
        return nil
    end
    local days = DaysBetween(firstKey, lastKey)
    if days < 1 then
        return nil
    end
    return (QTR.SnapshotAt(lastKey) - QTR.SnapshotAt(firstKey)) / days
end

-- 목표까지 예상 달성일 문자열
-- hold: 순증 추세 줄 (2026-10-29 사용자 요청: 기록 부족과 감소를 구분한다)
--   음수 빨간 "보유량 감소 중", 0(골드 단위로 0, 보유량 순증 "+0"과 같은 기준) 회색 "변화 없음", 기록 2일 미만 회색 "-"
local function FormatEta(goal, total, perDay, hold)
    local remain = goal * 10000 - total
    if remain <= 0 then
        return L["|cff00ff00달성|r"]
    end
    if hold and perDay then
        if CopperToGold(math.abs(perDay)) == 0 then
            return L["|cff808080변화 없음|r"]
        elseif perDay < 0 then
            return L["|cffff4444보유량 감소 중|r"]
        end
    end
    if not perDay or perDay <= 0 then
        return "|cff808080-|r"
    end
    if remain / perDay > MAX_ETA_DAYS then
        return L["100년 이상"]
    end
    -- 하루 평균으로 남은 골드를 나눈 시각까지 그대로 보여준다 (골드를 벌 때마다 시각이 앞당겨지는 게 보이게)
    local eta = time() + math.floor(remain / perDay * 86400)
    local days = DaysBetween(GetDayKey(), TimeToDayKey(eta))
    return FormatDate(eta) .. " " .. date("%H:%M", eta) .. " D-" .. days
end

-- 목표 골드 (골드 단위, 설정의 만 골드 값 x 10000)
local function GetGoalGold()
    return DB.settings.goal
end

-- 기간 표시: 3일 4시간, 5시간 12분, 36분 (1분 미만은 "1분 미만")
-- 기간 표시 (짧게): "1d 2h 5m", "3h 12m", "36m" (앞자리 단위가 0이면 생략, 1분 미만은 "0m")
local function FormatDurationDHM(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    local days = math.floor(minutes / 1440)
    local hours = math.floor((minutes % 1440) / 60)
    local mins = minutes % 60
    if days > 0 then
        return days .. "d " .. hours .. "h " .. mins .. "m"
    elseif hours > 0 then
        return hours .. "h " .. mins .. "m"
    end
    return mins .. "m"
end

local function FormatDuration(seconds)
    seconds = math.floor(seconds or 0)
    if seconds < 60 then
        return L["1분 미만"]
    end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return L["%d분"]:format(minutes)
    end
    local hours = math.floor(minutes / 60)
    if hours < 24 then
        local m = minutes % 60
        if m == 0 then
            return L["%d시간"]:format(hours)
        end
        return L["%d시간 %d분"]:format(hours, m)
    end
    local days = math.floor(hours / 24)
    local h = hours % 24
    if h == 0 then
        return L["%d일"]:format(days)
    end
    return L["%d일 %d시간"]:format(days, h)
end

-- 번 골드만큼 달성 예상 시점이 앞당겨진 시간(초)
-- 골드퀘 추세(최근 하루 평균 골드퀘 수익) 기준: 하루 평균의 몇 배를 벌었는지를 시간으로 바꾼 값
-- 목표를 이미 달성했거나 평균이 없으면 nil
local function GetTimeSaved(copper, perDay, total)
    if not copper or copper <= 0 or not perDay or perDay <= 0 then
        return nil
    end
    if total and total >= GetGoalGold() * 10000 then
        return nil
    end
    return copper / perDay * 86400
end

-- 채팅 알림에 붙이는 문구: " / 달성률 +0.03%" (이번에 번 골드가 목표의 몇 %인지)
local function FormatGoalNote(copper)
    local goalCopper = GetGoalGold() * 10000
    if not copper or copper <= 0 or goalCopper <= 0 then
        return ""
    end
    return string.format(L[" / 달성률 +%.2f%%"], copper / goalCopper * 100)
end

-- 채팅 알림 끝에 붙이는 문구: " / 달성 예상 36분 단축"
-- 이번 골드를 기록한 뒤의 하루 평균 기준이다. 계산할 수 없으면 빈 문자열.
local function FormatSavedNote(copper)
    local total = GetAccountTotals()
    local saved = GetTimeSaved(copper, GetRecentAverage(AVG_DAYS), total)
    if not saved then
        return ""
    end
    return L[" / |cff00ff00달성 예상 %s 단축|r"]:format(FormatDuration(saved))
end

-- 기간별 집계: mode = day/week/month/all
local function Aggregate(mode, periodKey)
    local result = { count = 0, money = 0, cacheCount = 0, days = 0, chars = {}, caches = {} }
    for dayKey, day in pairs(DB.days) do
        if mode == "all" or GetPeriodKey(dayKey, mode) == periodKey then
            local dayMoney = 0
            for key, rec in pairs(day) do
                local c = result.chars[key]
                if not c then
                    c = { count = 0, money = 0, cacheCount = 0 }
                    result.chars[key] = c
                end
                c.count = c.count + (rec.count or 0)
                c.money = c.money + (rec.money or 0)
                c.cacheCount = c.cacheCount + (rec.cacheCount or 0)
                -- 획득 내역 (획득량 탭 툴팁용): 골드퀘와 정점 보관함 하나하나
                c.items = c.items or {}
                for _, q in ipairs(rec.quests or {}) do
                    -- 지역: 완료 기록에 남긴 지역 (예전 기록에 없으면 계정 공용 목록에서 찾는다)
                    local zone = q.zone or (q.id and DB.activeGQ[q.id] and DB.activeGQ[q.id].zone)
                    table.insert(c.items, { t = q.t, name = q.name, zone = zone, money = q.money or 0 })
                end
                for _, cg in ipairs(rec.caches or {}) do
                    table.insert(c.items, { t = cg.t, cacheID = cg.id, money = cg.money or 0 })
                    -- 획득량 탭 "보관함" 묶음과 최근 추이의 대박 별
                    table.insert(result.caches, { key = key, id = cg.id, t = cg.t, money = cg.money or 0 })
                end
                result.count = result.count + (rec.count or 0)
                result.money = result.money + (rec.money or 0)
                result.cacheCount = result.cacheCount + (rec.cacheCount or 0)
                dayMoney = dayMoney + (rec.money or 0)
            end
            if dayMoney > 0 then
                result.days = result.days + 1
            end
        end
    end
    return result
end

local function GetSortedPeriodKeys(mode)
    local set = {}
    for dayKey in pairs(DB.days) do
        set[GetPeriodKey(dayKey, mode)] = true
    end
    set[GetPeriodKey(GetDayKey(), mode)] = true
    local keys = {}
    for k in pairs(set) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

local function ColorName(key)
    local c = DB.chars[key]
    if c and c.class and RAID_CLASS_COLORS[c.class] and RAID_CLASS_COLORS[c.class].colorStr then
        return "|c" .. RAID_CLASS_COLORS[c.class].colorStr .. key .. "|r"
    end
    return key
end

-------------------------------------------------------------------------------
-- 퀘스트 정보
-------------------------------------------------------------------------------

local function GetQuestTitle(questID)
    local title
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        title = C_TaskQuest.GetQuestInfoByQuestID(questID)
    end
    if (not title or title == "") and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end
    if not title or title == "" then
        title = L["퀘스트 %s"]:format(questID)
    end
    return title
end

-- 완료 기록에 남길 지역 이름: 골드퀘 지역 이름으로 맞춘다 (하위 지도 이름이 아니라 "공허폭풍"처럼)
--   1) 골드퀘 목록이 기억한 지역 (QTR.QuestZone)  2) 퀘스트 지도나 내 지도가 속한 골드퀘 지역  3) 그 지도 이름
local function GetQuestZoneName(questID)
    local known = QTR.QuestZone and QTR.QuestZone(questID)
    if known then
        return known
    end
    local mapID
    if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
        mapID = C_TaskQuest.GetQuestZoneID(questID)
    end
    if not mapID or mapID == 0 then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    local gqZone = mapID and QTR.GQZoneNameOfMap and QTR.GQZoneNameOfMap(mapID)
    if gqZone then
        return gqZone
    end
    if mapID then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name then
            return info.name
        end
    end
    return GetRealZoneText() or L["알 수 없음"]
end

-------------------------------------------------------------------------------
-- 정점 보관함 (출처와 받은 기록은 특별 과제의 주간 보상 상자 2종만. 2026-10-24부터)
-- 출처, 골드퀘 탭, 부자되기 탭은 특별 과제 보상 2종(DEFAULT_CACHE_ITEMS)만 본다. (예전의 /qtr cache 수동 등록은 없앴다)
-- 실버문 주간퀘 등의 다른 정점 보관함은 여는 골드 기록과 미개봉 알림창만 (QTR.IsApexItem, 2026-10-27)
-- 보관함을 열 때 늘어난 골드를 그날 그 캐릭터 기록에 더한다.
--   열기 시작: 가방에서 우클릭(C_Container.UseContainerItem 후킹), 알림창 클릭, 또는 전리품 창 출처 확인
--   마무리   : 골드가 들어오고 1초 뒤(또는 전리품 창이 닫힌 뒤) 골드 차이를 계산한다.
--              보관함이 실제로 쓰였을 때(가방의 개수가 줄었거나 전리품 창이 열렸을 때)만 기록한다.
--   (2026-10-16: 정점 보관함은 전리품 창 없이 보상이 바로 들어오는 것을 인게임에서 확인.
--    처음에는 전리품 창이 열린 경우만 기록하게 해서 골드가 빠졌다)
-------------------------------------------------------------------------------

-- 추적하는 정점 보관함: 특별 과제 보상 2종만 (2026-10-24 사용자 결정)
--   QTR은 골드퀘(와 그 밖의 필드 전역퀘)를 하다 열리는 특별 과제와 그 보상 보관함만 따라간다.
--   최정상 보관함(279527, 잘아타스 추적 등)과 그 밖의 보관함은 출처를 따라가지 않는다 (여는 골드만 기록, 아래 QTR.IsApexItem).
--   다음 시즌에 특별 과제 보상 상자가 바뀌면 이 표만 고친다.
--   279520: 전설적인 역전용사의 보관함 (한밤 2시즌 특별 과제 보상, 2026-10-16 인게임 확인)
--   282183: 전설적인 띠리의 섬 역전용사의 보관함 (똬리의 섬 특별 과제 보상, 2026-10-17 인게임 확인)
local DEFAULT_CACHE_ITEMS = { 279520, 282183 }

-- 아이템 정보를 아직 못 받았을 때 보여줄 이름
local CACHE_NAMES = {
    [279520] = L["전설적인 역전용사의 보관함"],
    [282183] = L["전설적인 띠리의 섬 역전용사의 보관함"],
}

local CACHE_SOURCE_WINDOW = 10   -- 퀘스트 완료 후 이 시간(초) 안에 들어온 보관함은 그 퀘스트 보상으로 본다
local CACHE_GET_KEEP_DAYS = 60   -- 보관함 획득 기록 보관 기간

local pendingCache
local pendingAlertUpdate = false

local function GetItemCountSafe(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID) or 0
    end
    if GetItemCount then
        return GetItemCount(itemID) or 0
    end
    return 0
end

local function GetItemNameSafe(itemID)
    local name
    if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(itemID)
    end
    if (not name or name == "") and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    if not name or name == "" then
        name = CACHE_NAMES[itemID] or L["아이템 %s"]:format(itemID)
    end
    return name
end

local function GetItemIconSafe(itemID)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    return icon or "Interface\\Icons\\INV_Misc_Bag_10"
end

-- 추적하는 정점 보관함 아이템 ID 목록 (특별 과제 보상 2종)
local function GetAllCacheItems()
    return DEFAULT_CACHE_ITEMS
end

-- 툴팁 글자에서 색 코드와 앞뒤 공백을 뺀다
function QTR.PlainText(text)
    if type(text) ~= "string" then
        return ""
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return strtrim(text)
end

-- 퀘스트 이름 앞의 "특별 과제:"를 뗀다. 채팅 "...: 이름" 뒤에 붙어 쌍점이 겹치지 않게 (2026-10-26 사용자 요청)
function QTR.NoPrefix(text)
    text = tostring(text or "")
    -- 클라이언트 언어의 앞말(Locales의 SPECIAL_PREFIX)도 뗀다 (영어 앞말이 추정과 다를 때 Locales만 고치면 되게)
    local p = QTR.SPECIAL_PREFIX
    if p and text:sub(1, #p) == p then
        text = text:sub(#p + 1)
    end
    return (text:gsub("^특별 과제:%s*", ""):gsub("^Special Assignment:%s*", ""):gsub("^%s+", ""))
end

local function IsCacheItem(itemID)
    for _, id in ipairs(DEFAULT_CACHE_ITEMS) do
        if id == itemID then
            return true
        end
    end
    return false
end

-- 특별 과제 2종 말고 다른 정점 보관함 (2026-10-27 사용자 결정, 인벤 봉구c 피드백)
--   여는 골드 기록(획득량 탭)과 미개봉 알림창만. 출처, 골드퀘 탭, 부자되기 탭, 내비게이션에는 넣지 않는다.
--   알려진 것은 ID로, 모르는 것은 아이템 툴팁의 "정점 보관함 - ..." 줄로 알아본다 (판정 결과는 이번 접속 동안 기억)
--   279527: 최정상 보관함 (실버문 주간, 잘아타스 추적), 279526: 스토마리온 공격, 279523: 예전 사용자 등록
QTR.APEX_OTHER = { [279527] = true, [279526] = true, [279523] = true }
QTR.apexSeen = {}

function QTR.IsApexItem(itemID)
    if not itemID then
        return false
    end
    if IsCacheItem(itemID) or QTR.APEX_OTHER[itemID] then
        return true
    end
    if QTR.apexSeen[itemID] ~= nil then
        return QTR.apexSeen[itemID]
    end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then
        return false
    end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    -- 아이템 정보를 아직 못 받아 줄이 모자라면 기억하지 않고 다음에 다시 본다
    if not (ok and type(data) == "table" and type(data.lines) == "table" and #data.lines >= 2) then
        return false
    end
    local found = false
    for _, line in ipairs(data.lines) do
        if QTR.PlainText(line.leftText):find(QTR.GameText("APEX_TOOLTIP") or "^정점 보관함 %- ") then
            found = true
            break
        end
    end
    QTR.apexSeen[itemID] = found
    return found
end

-- 보관함 대박 판정: 보통은 1,900~2,100골드인데, 최정상 보관함에서 4,4xx골드와 17,9xx골드를 받았다
--   두 단계 (2026-10-29 사용자 결정, 영어권 자료 확인): 블리자드 포럼 보고로는 보통 약 2,000 / 4,000(약 2배) / 18,000(약 9배)
--   세 덩어리뿐이고 8~9천골드 구간은 보고가 없다 (내부 전쟁은 1,600 / 3,200 / 16,000). 처음 시험판의 2배, 4배, 8배는 어림이었다
--   3,000골드 이상 대박(은별), 10,000골드 이상 초대박(금별). 두 덩어리 사이가 넓어 정확한 배수를 몰라도 된다
--   { 경계(코퍼), 등급, 색 }. 등급 2 = 초대박, 1 = 대박 (큰 것부터)
QTR.JACKPOT = { { 100000000, 2, "ffd700" }, { 30000000, 1, "c0c0c0" } }
QTR.JACKPOT_NAMES = { [2] = L["초대박"], [1] = L["대박"] } -- 획득량 탭 "보관함 대박" 묶음 줄 이름

-- 대박이면 배수와 색을 입힌 별, 아니면 nil
function QTR.JackpotTier(copper)
    for _, j in ipairs(QTR.JACKPOT) do
        if (copper or 0) >= j[1] then
            return j[2], "|cff" .. j[3] .. "\226\152\133|r"
        end
    end
    return nil
end

-- 획득량 탭 요약 줄의 대박 횟수 (2026-10-27 사용자 요청): "보관함 대박 7회 (금별2, 은별5)". 대박이 없으면 nil (줄을 붙이지 않는다)
function QTR.JackpotSummary(caches)
    local count, total = {}, 0
    for _, c in ipairs(caches) do
        local tier = QTR.JackpotTier(c.money)
        if tier then
            count[tier] = (count[tier] or 0) + 1
            total = total + 1
        end
    end
    if total == 0 then
        return nil
    end
    local parts = {}
    for _, j in ipairs(QTR.JACKPOT) do
        if count[j[2]] then
            local _, star = QTR.JackpotTier(j[1])
            table.insert(parts, star .. count[j[2]])
        end
    end
    return L["보관함 대박 %d회 (%s)"]:format(total, table.concat(parts, ", "))
end

-- 가방의 모든 정점 보관함 (알림창용): 총 개수, 처음 찾은 아이템 ID. 특별 과제 2종을 먼저 센다
--   골드퀘 탭의 "가방에 열지 않은 보관함"은 2종만 센다 (GetCacheInBags)
function QTR.ApexInBags()
    local total, firstID = 0, nil
    for _, id in ipairs(DEFAULT_CACHE_ITEMS) do
        local n = GetItemCountSafe(id)
        if n > 0 then
            total = total + n
            firstID = firstID or id
        end
    end
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then
        return total, firstID
    end
    local seen = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] and not IsCacheItem(id) and QTR.IsApexItem(id) then
                seen[id] = true
                local n = GetItemCountSafe(id)
                if n > 0 then
                    total = total + n
                    firstID = firstID or id
                end
            end
        end
    end
    return total, firstID
end

-- 받은 기록(cacheGets)과 가방 개수(cacheBag)에 쓰는 정점 보관함 ID 목록 (2026-10-29: 부자되기 탭 "다른 정점 보관함" 묶음용으로 다른 보관함도)
--   특별 과제 2종, 아는 다른 보관함, 이번 접속에 툴팁으로 알아본 보관함, 지금 가방에 있는 정점 보관함
function QTR.ApexIDs()
    local set, list = {}, {}
    local function add(id)
        if id and not set[id] then
            set[id] = true
            table.insert(list, id)
        end
    end
    for _, id in ipairs(DEFAULT_CACHE_ITEMS) do
        add(id)
    end
    for id in pairs(QTR.APEX_OTHER) do
        add(id)
    end
    for id, yes in pairs(QTR.apexSeen) do
        if yes then
            add(id)
        end
    end
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID then
        for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id and not set[id] and QTR.IsApexItem(id) then
                    add(id)
                end
            end
        end
    end
    table.sort(list)
    return list
end

-- 추적하지 않는 보관함의 출처와 받은 기록을 지운다 (InitDB 끝에서, 2026-10-24 범위를 특별 과제 보관함 2종으로 좁힘)
--   출처: 퀘스트 출처 중 추적하는 보관함을 주는 것만 남긴다 (퀘스트 없이 받은 보관함 출처, 최정상 보관함 출처 등은 지운다)
--   받은 기록(cacheGets)과 가방 개수(cacheBag)는 2026-10-29부터 지우지 않는다: 다른 정점 보관함도 부자되기 탭
--   "다른 정점 보관함" 묶음에서 캐릭터별 획득 여부를 보여 주려고 기록한다 (사용자 결정. 출처는 여전히 2종만)
--   (접속 직후에는 툴팁을 못 읽어 모르는 보관함을 가릴 수 없으므로 여기서 가려 지우지 않는다)
function QTR.CleanupCacheData()
    for key, src in pairs(DB.cacheSources) do
        if src.kind ~= "quest" or not IsCacheItem(src.itemID) then
            DB.cacheSources[key] = nil
        end
    end
    for _, c in pairs(DB.chars) do
        c.emptyZones = nil -- 2026-10-25 시험판의 "퀘스트 없는 지역" 기억 (캐릭터별 골드 아님 기억으로 대신해 없앴다)
    end
end

-- 주간 초기화: 이번 주 시작 시각, 다음 초기화 시각
local function GetWeekBounds()
    local nextReset
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local s = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if s and s > 0 then
            nextReset = time() + s
        end
    end
    if not nextReset then
        -- API를 못 쓸 때: 0시 기준 주 시작(목요일)으로 대신한다
        nextReset = DayKeyToTime(GetWeekKey(GetDayKey())) - 12 * 3600 + 7 * 86400
    end
    return nextReset - 7 * 86400, nextReset
end

-- 추적 제외 퀘스트 (PVP 퀘스트처럼 하지 않는 퀘스트를 골드퀘, 부자되기 탭에서 숨긴다)
function QTR.IsHiddenQuest(questID)
    return DB.settings.hideBanned and DB.settings.bannedQuests[questID] ~= nil
end

-- 퀘스트의 지역 이름 (계정 공용 골드퀘 목록, 정점 보관함 출처에서 찾는다. 모르면 nil)
function QTR.QuestZone(questID)
    local e = DB.activeGQ[questID]
    if e and e.zone then
        return e.zone
    end
    local src = DB.cacheSources["q" .. questID]
    return src and src.zone
end

-- 추적 제외 목록에 넣고 빼기 (지역도 함께 남겨, 퀘스트가 지도에서 사라진 뒤에도 "퀘스트명 (지역명)"으로 보여 준다)
function QTR.BanQuest(questID, name)
    DB.settings.bannedQuests[questID] = name or tostring(questID)
    DB.settings.bannedZones[questID] = QTR.QuestZone(questID) or DB.settings.bannedZones[questID]
end
function QTR.UnbanQuest(questID)
    DB.settings.bannedQuests[questID] = nil
    DB.settings.bannedZones[questID] = nil
end

-- 제외한 퀘스트 표시: "퀘스트명 (지역명)" (지역을 모르면 퀘스트명만)
function QTR.BanLabel(questID)
    local name = QTR.NoPrefix(DB.settings.bannedQuests[questID] or tostring(questID))
    local zone = DB.settings.bannedZones[questID] or QTR.QuestZone(questID)
    return name .. ((zone and zone ~= "") and (" (" .. zone .. ")") or "")
end

-- 제외 목록에 있지만 숨기기를 꺼 둔 퀘스트에 붙이는 표시
function QTR.BanMark(questID)
    if DB.settings.bannedQuests[questID] and not DB.settings.hideBanned then
        return L[" |cff808080(제외)|r"]
    end
    return ""
end

-- 퀘스트 링크(대화창에 Shift+클릭) 또는 숫자 ID에서 퀘스트 ID와 이름
function QTR.ParseQuestArg(arg)
    if type(arg) ~= "string" then
        return nil
    end
    local questID = tonumber(arg:match("quest:(%d+)") or "") or tonumber(arg)
    if not questID then
        return nil
    end
    local name = arg:match("%[(.-)%]")
    if not name or name == "" then
        local e = DB.activeGQ[questID]
        name = (e and e.name) or GetQuestTitle(questID)
    end
    return questID, name
end

-------------------------------------------------------------------------------
-- 퀘스트 완료 기록과 보관함 출처 학습
-- turnIns[캐릭터키][퀘스트ID] = 마지막 완료 시각 (모든 퀘스트, 부자되기 탭의 완료 판정에 쓴다)
-- cacheSources[키] = 보관함을 주는 출처
--   키 "q퀘스트ID": 퀘스트 { kind = "quest", questID, title, zone, itemID, learned, lastSeen, via }
--   키 "i아이템ID": 퀘스트 없이 들어온 보관함 { kind = "item", itemID, learned, lastSeen, via = "bag" }
--   lastSeen: 받을 수 있는 상태로 마지막으로 본 시각 (이번 주에 본 출처인지 판단)
-- cacheGets[캐릭터키] = { { id, n, t, q } } 보관함이 가방에 들어온 기록 (q: 출처 퀘스트 ID)
-------------------------------------------------------------------------------

local questTitles = {}  -- 이번 접속에서 본 퀘스트 이름 (완료 뒤에는 이름을 못 읽는 퀘스트 대비)
local lastTurnIn        -- { questID, at = GetTime() }

local function RememberQuestTitle(questID, title)
    if questID and type(title) == "string" and title ~= "" then
        questTitles[questID] = title
    end
end

local function GetKnownQuestTitle(questID)
    return questTitles[questID] or GetQuestTitle(questID)
end

-- 계정 공용 기록에 남은 이름(퀘스트, 지역)은 그 이름을 본 클라이언트 언어 그대로다 (2026-10-31 영어 클라이언트 지원)
-- 저장한 이름이 지금 클라이언트와 다른 언어면(한글이 있는지로 가린다) 게임에서 지금 읽은 이름을 대신 쓴다
function QTR.WrongLang(text)
    if type(text) ~= "string" or text == "" then
        return false
    end
    return (text:find("[\234-\237][\128-\191][\128-\191]") ~= nil) ~= (GetLocale() == "koKR")
end

-- 괄호 안에 붙이는 짧은 지역명: 한국어가 아닌 클라이언트는 앞의 "The ", 뒤의 " City", " Woods"를 뗀다
--   ("The Coiled Isle" -> "Coiled Isle", "Silvermoon City" -> "Silvermoon". 영어 지역명이 길어 퀘스트 이름이 잘렸다, 2026-10-31)
--   내비게이션 창 줄과 정점 보관함 줄의 "퀘스트명 (지역명)"에만 쓴다. 골드퀘 지역 묶음 제목은 자리가 넉넉해 원래 이름 그대로 (사용자 결정)
function QTR.ShortZone(zone)
    if type(zone) ~= "string" or zone == "" or GetLocale() == "koKR" then
        return zone
    end
    return (zone:gsub("^The ", ""):gsub(" City$", ""):gsub(" Woods$", ""))
end

-- 게임에서 지금 읽은 퀘스트 이름 (못 읽으면 nil, 다음에 읽히도록 요청해 둔다)
function QTR.LiveQuestTitle(questID)
    local title = questID and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if (not title or title == "") and questID and C_QuestLog.RequestLoadQuestByID then
        pcall(C_QuestLog.RequestLoadQuestByID, questID)
    end
    return (type(title) == "string" and title ~= "") and title or nil
end

-- 저장한 퀘스트 이름을 보여 줄 때: 다른 언어로 저장된 이름이면 게임에서 읽은 이름 (없으면 저장한 이름)
function QTR.ShownTitle(questID, stored)
    if stored and QTR.WrongLang(stored) then
        return QTR.LiveQuestTitle(questID) or stored
    end
    return stored
end

local function GetPlayerZoneName()
    local mapID = C_Map.GetBestMapForUnit("player")
    local info = mapID and C_Map.GetMapInfo(mapID)
    return (info and info.name) or GetRealZoneText()
end

-- 지도에 뜨는 출처(특별 과제 등)인지: 지도에서 배운 출처, 또는 NPC 대화 등으로 배웠어도 특별 과제인 퀘스트
-- (특별 과제는 캐릭터마다 잠금 해제 여부가 달라서, 골드퀘 탭은 지금 캐릭터 지도에 떠 있을 때만 보여준다)
-- 예전에 저장된 출처도 여기서 판정해 표시를 남긴다
QTR.SPECIAL_PREFIX = QTR.GameText("SPECIAL_PREFIX") or "특별 과제:"

-- 한밤 특별 과제 퀘스트 ID 표
--   [특별 과제 퀘스트 ID] = { unlock = 잠겨 있는 동안 게임이 대신 보여주는 퀘스트 ID, mapID = 지역 지도 }
--   잠겨 있어도 이번 주 특별 과제인지, 남은 시간이 얼마인지 알 수 있다. 이름은 게임에서 읽는다.
-- 출처: GoldWQ (Marcus, CurseForge, Public Domain)가 정리한 표의 퀘스트 ID.
--   원 출처는 WeeklyRewards (https://github.com/cybertk/WeeklyRewards)
--   Copyright (c) 2025 Quanlong, MIT License. 코드는 가져오지 않았다.
QTR.SPECIAL_ASSIGNMENTS = {
    [92145] = { unlock = 92848, mapID = 2395 }, -- 영원노래 숲
    [92139] = { unlock = 95435, mapID = 2395 },
    [91390] = { unlock = 94865, mapID = 2437 }, -- 줄아만 (부서진 사원의 잔재)
    [91796] = { unlock = 94866, mapID = 2437 },
    [92063] = { unlock = 94390, mapID = 2413 }, -- 하란다르
    [93013] = { unlock = 94391, mapID = 2413 }, -- 하란다르 (빛을 몰아내라)
    [93438] = { unlock = 94743, mapID = 2405 }, -- 공허폭풍
    [93244] = { unlock = 94795, mapID = 2405 },
    [95918] = { unlock = 96307, mapID = 2512 }, -- 똬리의 섬
    [95921] = { unlock = 96492, mapID = 2512 }, -- 똬리의 섬 (수요와 공급)
    [95922] = { unlock = 96029, mapID = 2512 },
}

-- 실버문 주간 퀘스트 (2026-10-30 사용자 요청): 둘 다 최정상 보관함(279527)을 준다. 부자되기 탭 "정점 보관함" 묶음에서
-- 두 퀘스트를 따로, 캐릭터별 이번 주 완료 여부로 보여 준다 (보관함 한 줄로는 둘 중 하나만 했는지 알 수 없어서)
--   잘아타스 추적은 퀘스트 하나. 리에드린 주간은 "한밤:" 퀘스트 10종 중 하나 (어느 것이든 이번 주에 하나 완료하면 완료)
--   퀘스트 ID 출처: Apex Ledger (Andrew, MIT License) Data.lua. 코드는 가져오지 않고 ID만
QTR.SILVERMOON_CACHE = 279527
QTR.SILVERMOON_WEEKLY = {
    { key = "xalatath", name = L["잘아타스 추적"], ids = { 98172 } },
    -- 93913 야외 우두머리, 93769 주거, 93889 연회, 93890 풍요, 93891 하란다르 전설, 93892 스토마리온 공격,
    -- 93909 구렁, 93910 사냥감, 93911 던전, 93912 공격대
    -- noFlag: 게임의 완료 표시(IsQuestFlaggedCompleted)를 믿지 않는다 (2026-11-05 사용자 제보: 리에드린 주간이 없는 주인데 "완료").
    --   저장 데이터에서 10종이 캐릭터마다 접속 시각에 한꺼번에 완료로 잡혔고, 실제로 한 것은 하나(10-29 93913, 보관함 출처 기록)뿐이었다.
    --   그래서 이 줄은 QTR이 직접 본 완료(QUEST_TURNED_IN)와 수행중만 쓴다. QTR이 꺼진 채 완료한 것은 잡지 못한다
    -- skipNext: 한 번 하면 다음 주에는 받을 수 없다 (2026-11-07 사용자 제보: 10-29에 한 13캐릭터는 11-05 주에 퀘스트가 없고,
    --   이번 주 처음 만렙이 된 캐릭터는 받음. 유럽 포럼에도 같은 글). 그 캐릭터는 이번 주 "지난주 완료"로 빼고 개수에서도 뺀다.
    --   2주 주기인지는 11-12 초기화 뒤 13캐릭터가 다시 받는지 봐야 확정 (확인 불가). 위 완료 표시도 "지금 받을 수 없음"이었던 것으로 보인다
    { key = "liadrin", name = L["리에드린 주간 퀘스트"], noFlag = true, skipNext = true,
      ids = { 93913, 93769, 93889, 93890, 93891, 93892, 93909, 93910, 93911, 93912 } },
}
QTR.SILVERMOON_WEEKLY_IDS = {}
QTR.SILVERMOON_NOFLAG_IDS = {}
-- 줄 이름: 한국어가 아닌 클라이언트는 퀘스트 하나짜리(잘아타스 추적)를 게임에서 읽은 이름으로
function QTR.WeeklyName(w)
    if #w.ids == 1 and GetLocale() ~= "koKR" then
        return QTR.LiveQuestTitle(w.ids[1]) or w.name
    end
    return w.name
end
for _, w in ipairs(QTR.SILVERMOON_WEEKLY) do
    for _, id in ipairs(w.ids) do
        QTR.SILVERMOON_WEEKLY_IDS[id] = true
        if w.noFlag then
            QTR.SILVERMOON_NOFLAG_IDS[id] = true
        end
    end
end

-- 특별 과제의 남은 시간(초): 잠금 해제된 퀘스트를 먼저, 없으면 잠김 상태용 퀘스트를 본다.
-- 이번 주 특별 과제가 아니면(둘 다 시간이 없으면) nil
-- 반환 둘째: 어디서 읽었나 ("quest" 특별 과제 자체, "kept" 전에 특별 과제에서 읽어 둔 만료 시각, "unlock" 잠김 상태용 퀘스트)
--   잠김 상태용 퀘스트의 시간은 실제 특별 과제보다 길 수 있다 (2026-11-01 망령과 발톱: 특별 과제가 만료된 뒤에도
--   주간 초기화까지 남아 만료 시각이 초기화 시각으로 덮였다, 사용자 제보). 특별 과제에서 읽어 둔 만료 시각
--   (cacheSources의 expireSeen)이 있으면 그것을 따르고, 그 시각이 이번 주에 지났으면 초기화 전까지는 끝난 것으로 본다
function QTR.GetSpecialTimeLeft(questID)
    local sa = QTR.SPECIAL_ASSIGNMENTS[questID]
    if not (sa and C_TaskQuest and C_TaskQuest.GetQuestTimeLeftSeconds) then
        return nil
    end
    local ok, left = pcall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)
    if ok and type(left) == "number" and left > 0 then
        return left, "quest"
    end
    ok, left = pcall(C_TaskQuest.GetQuestTimeLeftSeconds, sa.unlock)
    if not (ok and type(left) == "number" and left > 0) then
        return nil
    end
    local src = DB and DB.cacheSources and DB.cacheSources["q" .. questID]
    if src and src.expireSeen and src.expire then
        local now = time()
        if src.expire > now then
            return src.expire - now, "kept"
        end
        if src.expire >= (GetWeekBounds()) then
            return nil
        end
    end
    return left, "unlock"
end

-- 이번 주 이 지역 특별 과제 퀘스트 ID (특별 과제 ID 표에서 남은 시간이 있는 것, 없으면 nil)
function QTR.ZoneSpecialID(mapID)
    for id, sa in pairs(QTR.SPECIAL_ASSIGNMENTS) do
        if sa.mapID == mapID and QTR.GetSpecialTimeLeft(id) then
            return id
        end
    end
    return nil
end

function QTR.IsMapSource(src)
    if src.onMap then
        return true
    end
    if src.kind ~= "quest" then
        return false
    end
    if QTR.SPECIAL_ASSIGNMENTS[src.questID] then
        src.onMap = true
        return true
    end
    local special = type(src.title) == "string" and src.title:find(QTR.SPECIAL_PREFIX, 1, true) == 1
    if not special and src.questID and C_QuestLog.GetQuestTagInfo
        and Enum and Enum.QuestTagType and Enum.QuestTagType.Capstone then
        local ok, info = pcall(C_QuestLog.GetQuestTagInfo, src.questID)
        special = ok and type(info) == "table" and info.worldQuestType == Enum.QuestTagType.Capstone
    end
    if special then
        src.onMap = true
    end
    return special and true or false
end

local function LearnQuestSource(questID, itemID, title, zone, via, expire)
    if not questID or not itemID then
        return
    end
    local key = "q" .. questID
    local s = DB.cacheSources[key]
    local isNew = not s
    s = s or { kind = "quest", questID = questID, learned = time(), via = via }
    s.itemID = itemID
    s.title = title or s.title or GetKnownQuestTitle(questID)
    s.zone = zone or s.zone
    s.lastSeen = time()
    if expire then
        s.expire = expire -- 지도에서 본 퀘스트(특별 과제)는 만료 시각을 안다
        s.expireSeen = true -- 퀘스트 자체에서 읽은 시각 (QTR.GetSpecialTimeLeft)
    elseif via == "map" and s.expire and s.expire <= time() then
        -- 지금 지도에 떠 있는데 저장된 만료 시각이 지났으면 그 시각이 틀렸다 (예전 버전이 남긴 주간 초기화 어림값 등, 2026-11-05)
        s.expire, s.expireSeen = nil, nil
    end
    if via == "map" then
        -- 지도에 뜨는 퀘스트(특별 과제 등): 정점 보관함 묶음에 넣되,
        -- 매주 바뀌므로 지금 할 수 있을 때(만료 전, 이번 주에 본 것)만 보여준다
        s.onMap = true
    else
        QTR.IsMapSource(s) -- NPC 대화 등으로 배웠어도 특별 과제면 같은 표시를 남긴다
    end
    DB.cacheSources[key] = s
    -- 같은 보관함을 퀘스트 없이 받았던 기록으로 만든 출처는 퀘스트 출처로 대신한다
    local itemKey = "i" .. itemID
    if DB.cacheSources[itemKey] and DB.cacheSources[itemKey].via == "bag" then
        DB.cacheSources[itemKey] = nil
    end
    if isNew then
        Print(L["보관함 출처 학습: "] .. QTR.NoPrefix(s.title or questID) .. (s.zone and (" (" .. s.zone .. ")") or "")
            .. " -> " .. GetItemNameSafe(itemID))
    end
end

-- 퀘스트 완료 시각 저장: 완료 판정에 쓰는 퀘스트(전역퀘, 보관함 출처 퀘스트)만 저장한다.
-- 직전에 완료한 퀘스트(lastTurnIn)는 모든 퀘스트에 대해 메모리에만 둔다 (보관함 출처 학습용)
local function SaveTurnIn(questID)
    DB.turnIns[charKey] = DB.turnIns[charKey] or {}
    DB.turnIns[charKey][questID] = time()
end

local function RecordTurnIn(questID)
    if not DB or not charKey or not questID then
        return
    end
    lastTurnIn = { questID = questID, at = GetTime() }
    local isWorldQuest = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID)
    -- 실버문 주간 퀘스트도 저장한다 (부자되기 탭 정점 보관함 묶음, 2026-10-30)
    if isWorldQuest or DB.cacheSources["q" .. questID] or DB.activeGQ[questID] or QTR.SILVERMOON_WEEKLY_IDS[questID] then
        SaveTurnIn(questID)
    end
end

-- 아이템 링크에서 아이템 ID
local function ItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

-- 퀘스트 로그/전역퀘의 보상 아이템 중 정점 보관함 (없으면 nil, 정보가 아직 없으면 nil)
local function GetQuestLogCacheReward(questID)
    if not GetNumQuestLogRewards or not GetQuestLogRewardInfo then
        return nil
    end
    local ok, n = pcall(GetNumQuestLogRewards, questID)
    if not ok or not n then
        return nil
    end
    for i = 1, n do
        local ok2, _, _, _, _, _, itemID = pcall(GetQuestLogRewardInfo, i, questID)
        if ok2 and itemID and IsCacheItem(itemID) then
            return itemID
        end
    end
    return nil
end

-- NPC 퀘스트 창(수락, 완료)의 보상 아이템 중 정점 보관함
local function GetQuestFrameCacheReward()
    if not GetNumQuestRewards then
        return nil
    end
    for i = 1, GetNumQuestRewards() or 0 do
        local itemID
        if GetQuestItemLink then
            itemID = ItemIDFromLink(GetQuestItemLink("reward", i))
        end
        if not itemID and GetQuestItemInfo then
            local _, _, _, _, _, id = GetQuestItemInfo("reward", i)
            itemID = id
        end
        if itemID and IsCacheItem(itemID) then
            return itemID
        end
    end
    return nil
end

-- NPC 퀘스트 창이 열렸을 때 (QUEST_DETAIL, QUEST_COMPLETE): 보상이 정점 보관함이면 출처로 학습
local function LearnFromQuestFrame()
    local questID = GetQuestID and GetQuestID()
    if not questID or questID == 0 then
        return
    end
    local title = GetTitleText and GetTitleText()
    RememberQuestTitle(questID, title)
    local itemID = GetQuestFrameCacheReward()
    if itemID then
        LearnQuestSource(questID, itemID, title, GetPlayerZoneName(), "npc")
    end
end

-- 퀘스트를 수락했을 때: 퀘스트 로그의 보상으로 확인
local function LearnFromQuestLog(questID)
    if not questID then
        return
    end
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    RememberQuestTitle(questID, title)
    local itemID = GetQuestLogCacheReward(questID)
    if itemID then
        LearnQuestSource(questID, itemID, title, GetPlayerZoneName(), "log")
    end
end

-- 보관함이 가방에 들어온 것 기록 (종류별 개수 증가를 보고 판단)
local lastCacheCounts -- 접속 후 첫 확인 전에는 nil (그때는 기준값만 잡는다)

local function RecordCacheGet(itemID, n)
    local src
    if lastTurnIn and GetTime() - lastTurnIn.at <= CACHE_SOURCE_WINDOW then
        src = lastTurnIn.questID
    end
    DB.cacheGets[charKey] = DB.cacheGets[charKey] or {}
    table.insert(DB.cacheGets[charKey], { id = itemID, n = n, t = time(), q = src })
    -- 오래된 기록 정리
    local cutoff = time() - CACHE_GET_KEEP_DAYS * 86400
    local list = DB.cacheGets[charKey]
    for i = #list, 1, -1 do
        if (list[i].t or 0) < cutoff then
            table.remove(list, i)
        end
    end
    -- 출처는 보관함을 준 퀘스트(특별 과제)만 배운다 (퀘스트 없이 받은 보관함, 다른 정점 보관함은 출처로 남기지 않는다)
    if src and IsCacheItem(itemID) then
        local s = DB.cacheSources["q" .. src]
        LearnQuestSource(src, itemID, s and s.title or GetKnownQuestTitle(src), s and s.zone or GetPlayerZoneName(), "bag")
        SaveTurnIn(src) -- 완료할 때는 출처인지 몰라 저장하지 않았을 수 있다
    end
    if DB.settings.chatNotify then
        local srcText = src and (" (" .. QTR.NoPrefix(GetKnownQuestTitle(src) or src) .. ")") or ""
        Print(L["정점 보관함 획득: "] .. GetItemNameSafe(itemID) .. srcText)
    end
end

local function IsTradeWindowOpen()
    return (MerchantFrame and MerchantFrame:IsShown())
        or (BankFrame and BankFrame:IsShown())
        or (SendMailFrame and SendMailFrame:IsShown())
end

local function UpdateCacheGets()
    if not DB or not charKey then
        return
    end
    -- 특별 과제 2종과 다른 정점 보관함 (2026-10-29부터 다른 보관함도 받은 기록을 남긴다)
    local counts = {}
    for _, id in ipairs(QTR.ApexIDs()) do
        counts[id] = GetItemCountSafe(id)
    end
    local tradeOpen = IsTradeWindowOpen()
    if lastCacheCounts and not tradeOpen then
        for id, n in pairs(counts) do
            local prev = lastCacheCounts[id]
            -- 툴팁으로 늦게 알아본 보관함은 처음 본 개수를 기준으로만 잡는다 (전부터 가방에 있던 것을 새로 받은 것으로 세지 않게)
            local known = IsCacheItem(id) or QTR.APEX_OTHER[id]
            if (prev ~= nil or known) and n > (prev or 0) then
                RecordCacheGet(id, n - (prev or 0))
            end
        end
    end
    lastCacheCounts = counts
end

-- 가방 안의 정점 보관함: 총 개수, 처음 찾은 아이템 ID
local function GetCacheInBags()
    local total, firstID = 0, nil
    for _, id in ipairs(GetAllCacheItems()) do
        local n = GetItemCountSafe(id)
        if n > 0 then
            total = total + n
            firstID = firstID or id
        end
    end
    return total, firstID
end

-- 현재 캐릭터 가방에 있는 보관함 개수를 종류별로 저장 (부자되기 탭에서 "미개봉 N"으로 보여준다)
local function RecordCacheBag()
    if not DB or not charKey or not DB.chars[charKey] then
        return
    end
    local bag = {}
    for _, id in ipairs(QTR.ApexIDs()) do -- 다른 정점 보관함도 (2026-10-29)
        local n = GetItemCountSafe(id)
        if n > 0 then
            bag[id] = n
        end
    end
    DB.chars[charKey].cacheBag = bag
    DB.chars[charKey].cacheBagTime = time()
end

local function FinishCache()
    if not pendingCache then
        return
    end
    local p = pendingCache
    pendingCache = nil
    local gained = GetMoney() - p.money
    if gained <= 0 then
        return
    end
    -- 보관함이 실제로 쓰였는지 확인 (가방의 개수가 줄었거나 전리품 창이 열렸을 때)
    local consumed = p.lootSeen or GetItemCountSafe(p.itemID) < p.count
    if not consumed or IsTradeWindowOpen() then
        return
    end
    local rec = GetTodayRecord()
    rec.caches = rec.caches or {}
    table.insert(rec.caches, { id = p.itemID, money = gained, t = time() })
    rec.cacheCount = (rec.cacheCount or 0) + 1
    rec.cacheMoney = (rec.cacheMoney or 0) + gained
    rec.money = (rec.money or 0) + gained
    if DB.settings.chatNotify then
        -- 대박이면 "정점 보관함 대박 (별)" (2026-10-27)
        local _, star = QTR.JackpotTier(gained)
        Print(string.format(L["정점 보관함%s +%s / 오늘 합계 %s"], star and (L[" |cffff8000대박|r "] .. star) or "", FormatGold(gained), FormatGold(rec.money))
            .. FormatGoalNote(gained) .. FormatSavedNote(gained))
    end
    -- 내비게이션에서 완료한 보관함 퀘스트의 보관함이면 내비게이션 창의 "정점 보관함"을 나온 골드로 바꾼다
    if QTR.NavCacheOpened then
        QTR.NavCacheOpened(p.itemID, gained)
    end
    QTR:Refresh()
end

local function StartCache(itemID)
    if IsTradeWindowOpen() then
        return
    end
    -- 같은 보관함을 짧은 시간에 두 번 시작하지 않는다 (버튼 누름/뗌이 모두 들어오는 경우)
    if pendingCache and pendingCache.itemID == itemID and GetTime() - pendingCache.started < 1 then
        return
    end
    if pendingCache then
        FinishCache()
    end
    local token = GetTime()
    pendingCache = {
        itemID = itemID,
        money = GetMoney(),
        count = GetItemCountSafe(itemID),
        started = token,
        lootSeen = false,
    }
    -- 골드가 들어오지 않는 경우를 대비해 잠시 뒤 마무리
    C_Timer.After(10, function()
        if pendingCache and pendingCache.started == token then
            FinishCache()
        end
    end)
end

-- 보관함을 여는 중에 골드가 들어오면 1초 뒤 마무리 (그 사이 더 들어오는 골드도 합친다)
local function OnCacheMoneyChanged()
    if not pendingCache then
        return
    end
    local token = GetTime()
    pendingCache.moneyToken = token
    C_Timer.After(1, function()
        if pendingCache and pendingCache.moneyToken == token then
            FinishCache()
        end
    end)
end

-- 전리품 창의 출처가 정점 보관함인지 확인 (가방 우클릭을 놓친 경우 대비)
local function GetLootSourceCacheID()
    if not (GetNumLootItems and GetLootSourceInfo and C_Item and C_Item.GetItemIDByGUID) then
        return nil
    end
    for slot = 1, GetNumLootItems() do
        local ok, guid = pcall(GetLootSourceInfo, slot)
        if ok and type(guid) == "string" and guid:find("^Item%-") then
            local ok2, itemID = pcall(C_Item.GetItemIDByGUID, guid)
            if ok2 and QTR.IsApexItem(itemID) then
                return itemID
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- 정점 보관함 알림창 (HDT 은혜 알림과 같은 방식)
-- 위쪽 띠: 끌어서 옮기기, 닫기 / 아래 버튼: 클릭하면 보관함을 연다 (보안 버튼)
-- 보안 버튼이 들어 있어 전투 중에는 표시/숨김을 바꿀 수 없으므로 전투가 끝난 뒤 갱신한다.
-------------------------------------------------------------------------------

local cacheAlert = CreateFrame("Frame", "QuestsToRichesCacheAlert", UIParent)
cacheAlert:SetSize(290, 66)
cacheAlert:SetFrameStrata("HIGH")
cacheAlert:SetMovable(true)
cacheAlert:SetClampedToScreen(true)
cacheAlert:Hide()
cacheAlert.closedByUser = false
cacheAlert.lastCount = 0

local cacheAlertBg = cacheAlert:CreateTexture(nil, "BACKGROUND")
cacheAlertBg:SetAllPoints(cacheAlert)
cacheAlertBg:SetColorTexture(0, 0, 0, 0.85)

local cacheAlertHandle = CreateFrame("Frame", nil, cacheAlert)
cacheAlertHandle:SetPoint("TOPLEFT", cacheAlert, "TOPLEFT", 0, 0)
cacheAlertHandle:SetPoint("TOPRIGHT", cacheAlert, "TOPRIGHT", 0, 0)
cacheAlertHandle:SetHeight(18)
cacheAlertHandle:EnableMouse(true)
cacheAlertHandle:RegisterForDrag("LeftButton")
cacheAlertHandle:SetScript("OnDragStart", function()
    cacheAlert:StartMoving()
end)
cacheAlertHandle:SetScript("OnDragStop", function()
    cacheAlert:StopMovingOrSizing()
    local point, _, relativePoint, x, y = cacheAlert:GetPoint()
    if DB then
        DB.settings.cacheAlertPos = { point, relativePoint, x, y }
    end
end)

local cacheAlertTitle = cacheAlertHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cacheAlertTitle:SetPoint("LEFT", cacheAlertHandle, "LEFT", 8, -2)
cacheAlertTitle:SetText(L["골드퀘로 부자되기"])

local cacheAlertClose = CreateFrame("Button", nil, cacheAlert, "UIPanelCloseButton")
cacheAlertClose:SetSize(22, 22)
cacheAlertClose:SetPoint("TOPRIGHT", cacheAlert, "TOPRIGHT", 2, 2)
cacheAlertClose:SetScript("OnClick", function()
    cacheAlert.closedByUser = true
    if not InCombatLockdown() then
        cacheAlert:Hide()
    end
end)

local cacheOpenBtn = CreateFrame("Button", "QuestsToRichesCacheOpenButton", cacheAlert, "SecureActionButtonTemplate")
cacheOpenBtn:SetPoint("TOPLEFT", cacheAlert, "TOPLEFT", 0, -18)
cacheOpenBtn:SetPoint("BOTTOMRIGHT", cacheAlert, "BOTTOMRIGHT", 0, 0)
cacheOpenBtn:RegisterForClicks("AnyUp", "AnyDown")
cacheOpenBtn:SetAttribute("type", "item")

local cacheOpenHighlight = cacheOpenBtn:CreateTexture(nil, "HIGHLIGHT")
cacheOpenHighlight:SetAllPoints(cacheOpenBtn)
cacheOpenHighlight:SetColorTexture(1, 1, 1, 0.08)

cacheOpenBtn.icon = cacheOpenBtn:CreateTexture(nil, "ARTWORK")
cacheOpenBtn.icon:SetSize(36, 36)
cacheOpenBtn.icon:SetPoint("LEFT", cacheOpenBtn, "LEFT", 10, 0)

cacheOpenBtn.text = cacheOpenBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cacheOpenBtn.text:SetPoint("LEFT", cacheOpenBtn.icon, "RIGHT", 10, 0)
cacheOpenBtn.text:SetJustifyH("LEFT")

cacheOpenBtn:SetScript("PreClick", function(self)
    if self.itemID then
        StartCache(self.itemID)
    end
end)

local function ApplyCacheAlertPosition()
    cacheAlert:ClearAllPoints()
    local p = DB and DB.settings.cacheAlertPos
    if p then
        cacheAlert:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        cacheAlert:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    end
end

local function UpdateCacheAlert()
    if not DB then
        return
    end
    if InCombatLockdown() then
        pendingAlertUpdate = true
        return
    end
    pendingAlertUpdate = false
    local count, itemID = QTR.ApexInBags() -- 특별 과제 2종 말고 다른 정점 보관함도 (2026-10-27)
    -- 새 보관함을 받으면 사용자가 닫았던 알림도 다시 보여준다
    if count > cacheAlert.lastCount then
        cacheAlert.closedByUser = false
    end
    cacheAlert.lastCount = count
    if DB.settings.cacheAlert and count > 0 and itemID and not cacheAlert.closedByUser then
        cacheOpenBtn.itemID = itemID
        cacheOpenBtn:SetAttribute("item", "item:" .. itemID)
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
        cacheOpenBtn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Bag_10")
        cacheOpenBtn.text:SetText(L["열지 않은 정점 보관함 %d개\n|cffffffff클릭해서 열기|r"]:format(count))
        cacheAlert:Show()
    else
        cacheAlert:Hide()
    end
end

-------------------------------------------------------------------------------
-- 메인 창 (HDT와 같은 방식: 검은 배경, 제목, 닫기 버튼)
-------------------------------------------------------------------------------

local f = CreateFrame("Frame", "QuestsToRichesFrame", UIParent)
f:SetSize(FRAME_WIDTH, FRAME_HEIGHT_MIN)
f:SetPoint("CENTER")
f:Hide()
f:SetFrameStrata("MEDIUM")
f:SetFrameLevel(100)
f:EnableMouse(true)
f:SetMovable(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")

-- 창 위치는 왼쪽 위 모서리 기준으로 저장한다 (세로 길이가 바뀌어도 위쪽이 그대로 있도록)
function QTR.SaveFramePosition()
    local left, top = f:GetLeft(), f:GetTop()
    if not (DB and left and top) then
        return
    end
    DB.settings.pos = { "TOPLEFT", "BOTTOMLEFT", left, top }
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- "창 위치 고정"을 켜면 끌어서 옮기지 못한다
f:SetScript("OnDragStart", function(self)
    if DB and DB.settings.frameLocked then
        return
    end
    self:StartMoving()
end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    QTR.SaveFramePosition()
end)
tinsert(UISpecialFrames, f:GetName()) -- Esc로 닫힘 (고정 버튼을 켜면 뺀다)

local customBg = f:CreateTexture(nil, "BACKGROUND")
customBg:SetAllPoints(f)
customBg:SetColorTexture(0, 0, 0, 0.8)
f.CustomBg = customBg

f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
f.Title:SetPoint("TOP", f, "TOP", 0, -10)
f.Title:SetText(L["[QTR] 골드퀘로 부자되기"])

local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

-- 창 배치 (위에서부터)
--   제목
--   머리 영역: 진행률 막대(총 보유 / 목표), 하루 평균, 달성 예상 (어느 탭에서나 항상 보인다)
--   탭 버튼: 골드퀘 / 부자되기 / 획득량 / 보유량 (마우스가 창 위에 있을 때 숫자키 1~4로도 전환)
--   탭 영역
local TAB_Y = -120      -- 탭 버튼 위치
local PANEL_TOP = -148  -- 탭 영역 시작 위치

local function CreateTabButton(text)
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(94, 22)
    btn:SetText(text)
    return btn
end

-- 탭 4개: 폭 94, 간격 8 (20 ~ 420)
local tabGQ = CreateTabButton(L["1.골드퀘"])
tabGQ:SetPoint("TOPLEFT", f, "TOPLEFT", 20, TAB_Y)

local tabDash = CreateTabButton(L["2.부자되기"])
tabDash:SetPoint("LEFT", tabGQ, "RIGHT", 8, 0)

local tabStats = CreateTabButton(L["3.획득량"])
tabStats:SetPoint("LEFT", tabDash, "RIGHT", 8, 0)

local tabHold = CreateTabButton(L["4.보유량"])
tabHold:SetPoint("LEFT", tabStats, "RIGHT", 8, 0)

-- 설정 버튼: 닫기(X) 버튼 왼쪽의 톱니바퀴 아이콘 (HDT의 M 버튼과 같은 자리, 조금 작게)
local configBtn = CreateFrame("Button", nil, f)
configBtn:SetSize(16, 16)
configBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, -8)
configBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
configBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
configBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L["설정"])
    GameTooltip:Show()
end)
configBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- 고정 버튼 (설정 버튼 왼쪽 압정, 내비게이션 창과 같은 모양): 켜면 Esc 목록(UISpecialFrames)에서 빼서 Esc로 닫히지 않게 한다
-- 설정 dashPinned. "창 위치 고정"(frameLocked, 끌어서 옮기지 못하게)과는 따로다
do
    local pinBtn = CreateFrame("Button", nil, f)
    pinBtn:SetSize(20, 20)
    pinBtn:SetPoint("RIGHT", configBtn, "LEFT", -2, 0)
    local pinTex = pinBtn:CreateTexture(nil, "ARTWORK")
    pinTex:SetTexture("Interface\\AddOns\\QuestsToRiches\\Media\\Pin")
    pinTex:SetAllPoints(pinBtn)
    pinBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    -- 저장된 고정 상태를 Esc 목록과 압정 모양(켜짐 빨강, 꺼짐 회색)에 적용한다
    local function ApplyPinned()
        local name = "QuestsToRichesFrame"
        for k = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[k] == name then
                table.remove(UISpecialFrames, k)
            end
        end
        local pinned = DB and DB.settings.dashPinned
        if not pinned then
            tinsert(UISpecialFrames, name)
        end
        pinTex:SetDesaturated(not pinned)
        pinTex:SetAlpha(pinned and 1 or 0.5)
    end
    local function ShowPinTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["고정"])
        if DB.settings.dashPinned then
            GameTooltip:AddLine(L["켜짐: Esc를 눌러도 창이 닫히지 않습니다."], 1, 1, 1, true)
        else
            GameTooltip:AddLine(L["꺼짐: Esc를 누르면 창이 닫힙니다."], 1, 1, 1, true)
        end
        GameTooltip:AddLine(L["창을 끌어서 옮기지 못하게 하려면 설정의 \"창 위치 고정\"을 켜세요."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
    pinBtn:SetScript("OnClick", function(self)
        DB.settings.dashPinned = not DB.settings.dashPinned
        ApplyPinned()
        ShowPinTip(self)
    end)
    pinBtn:SetScript("OnEnter", ShowPinTip)
    pinBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    ApplyPinned() -- 설정을 읽은 뒤(OnInitialize) 다시 적용한다
    QTR.ApplyDashPinned = ApplyPinned
end

-- 탭별 영역
local function CreatePanel()
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, PANEL_TOP)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    panel:Hide()
    return panel
end

local gqPanel = CreatePanel()
local dashPanel = CreatePanel()
local statsPanel = CreatePanel()
local holdPanel = CreatePanel()

-- 스크롤 목록
-- 한 줄은 칸(cell) 목록으로 그린다. 칸마다 위치와 너비가 정해져 있어 요소별로 세로 정렬된다.
-- 줄 항목이 문자열이면 줄 전체를 차지하는 한 칸으로 그린다. (제목, 빈 줄 등)
-- 목록 아래 여백
local LIST_BOTTOM = 16

local function CreateList(parent, topOffset)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    -- 목록은 창 x = 16 ~ 420 (오른쪽 끝을 "4.보유량" 버튼에 맞춘다)
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, topOffset)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(FRAME_WIDTH - 16 - LIST_WIDTH), LIST_BOTTOM)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(LIST_WIDTH, 1)
    scroll:SetScrollChild(content)
    local list = { scroll = scroll, content = content, rows = {} }
    -- 스크롤바는 목록 위를 덮지 않도록 목록 오른쪽 바깥(창 오른쪽 여백)에 둔다
    local bar = scroll.ScrollBar
    if type(bar) == "table" and bar.ClearAllPoints then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, -16)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 16)
    end
    -- 창 세로 길이를 이 목록 내용에 맞춘다 (지금 보이는 목록일 때만. 최소~최대 사이)
    -- 창은 위쪽이 고정돼 있어 아래로만 늘고 준다
    function list.FitFrame()
        if not (parent:IsShown() and scroll:IsShown()) then
            return
        end
        local need = -PANEL_TOP - topOffset + content:GetHeight() + LIST_BOTTOM
        -- 창 크기를 키웠을 때 화면 밖으로 넘치지 않게 최대 높이를 화면 높이(창 배율 기준)에 맞춰 줄인다
        local maxH = math.min(FRAME_HEIGHT_MAX, math.floor(UIParent:GetHeight() / f:GetScale()) - 40)
        local h = math.max(FRAME_HEIGHT_MIN, math.min(maxH, math.ceil(need)))
        if math.abs(f:GetHeight() - h) >= 1 then
            f:SetHeight(h)
        end
    end
    -- 최대 높이에서도 다 안 들어가면 스크롤바를 보이고, 다 들어가면 숨긴다 (내용 높이나 창 크기가 바뀔 때마다 다시 판단)
    scroll.scrollBarHideable = true
    local function UpdateScrollBar()
        local bar = scroll.ScrollBar
        if type(bar) ~= "table" then
            return
        end
        local need = content:GetHeight() > scroll:GetHeight() + 1
        bar:SetShown(need)
        if not need then
            scroll:SetVerticalScroll(0)
        end
    end
    list.UpdateScrollBar = UpdateScrollBar
    -- 휠: 스크롤바가 보이면(목록이 넘치면) 목록을 스크롤하고, 아니면 탭 영역의 이전/다음으로 넘긴다
    local wheelScroll = scroll:GetScript("OnMouseWheel") or ScrollFrame_OnMouseWheel
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar
        if wheelScroll and type(bar) == "table" and bar:IsShown() then
            wheelScroll(self, delta)
        else
            QTR.PanelWheel(parent, delta)
        end
    end)
    scroll:HookScript("OnScrollRangeChanged", UpdateScrollBar)
    scroll:HookScript("OnSizeChanged", UpdateScrollBar)
    return list
end

-- 칸 만들기: col은 COL의 항목, justify는 "LEFT" 또는 "RIGHT"
local function Cell(text, col, justify)
    return { text = text, x = col.x, w = col.w, justify = justify or "LEFT" }
end

-- 목록 줄에 마우스를 올렸을 때의 툴팁
--   퀘스트: 이름, 남은 시간, 요구 조건, 보상 (게임 데이터를 읽어 직접 쓴다)
--   아이템: 아이템 툴팁 (퀘스트 없이 받는 정점 보관함)
-- 툴팁에 넣는 "보상" 줄: 정점 보관함이면 아이콘과 이름
-------------------------------------------------------------------------------
-- 퀘스트 툴팁 내용: 게임 툴팁이 보여주는 "요구 조건"과 "보상"을 게임 데이터에서 직접 읽어 글자로 쓴다.
-- (값을 읽기만 하는 함수들이라 툴팁 부품을 오염시키지 않는다. 줄마다 pcall로 감싸 하나가 실패해도 나머지는 나온다)
-- fallbackItem: 보상 정보를 아직 못 받았을 때 대신 보여줄 보관함 아이템 (잠긴 특별 과제 등)
-------------------------------------------------------------------------------
local QUALITY_HEX = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80", "ff00ccff" }

function QTR.AddQuestDetails(questID, fallbackItem)
    -- 퀘스트 정보와 보상 정보를 아직 못 받았으면 요청해 둔다 (다음에 마우스를 올리면 나온다)
    if HaveQuestData and not HaveQuestData(questID) and C_QuestLog.RequestLoadQuestByID then
        pcall(C_QuestLog.RequestLoadQuestByID, questID)
    end
    local rewardsReady = not HaveQuestRewardData or HaveQuestRewardData(questID)
    if not rewardsReady and C_TaskQuest.RequestPreloadRewardData then
        pcall(C_TaskQuest.RequestPreloadRewardData, questID)
    end

    -- 요구 조건 (게임이 진행도까지 붙여 준 문장을 그대로 쓴다. 진행 막대형은 문장에 % 가 없을 때만 붙인다)
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if ok and type(objectives) == "table" and #objectives > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["요구 조건"], 1, 0.82, 0)
        for _, o in ipairs(objectives) do
            pcall(function()
                local text = o.text or ""
                if o.type == "progressbar" and GetQuestProgressBarPercent and not text:find("%d%%") then
                    local pct = GetQuestProgressBarPercent(questID)
                    if pct then
                        text = (text ~= "" and text or L["진행도"]) .. " (" .. math.floor(pct) .. "%)"
                    end
                end
                if text ~= "" then
                    local c = o.finished and 0.5 or 1
                    GameTooltip:AddLine("- " .. text, c, c, c, true)
                end
            end)
        end
    end

    -- 보상: 골드(지금 캐릭터 기준, 전쟁 모드 보너스 포함), 화폐, 아이템
    local lines = {}
    pcall(function()
        local money = GetQuestLogRewardMoney(questID)
        if type(money) == "number" and money > 0 then
            table.insert(lines, FormatGold(QTR.WithWarBonus(questID, money)))
        end
    end)
    pcall(function()
        if C_QuestLog.GetQuestRewardCurrencies then
            for _, c in ipairs(C_QuestLog.GetQuestRewardCurrencies(questID) or {}) do
                local amount = c.totalRewardAmount or c.baseRewardAmount
                table.insert(lines, "|T" .. (c.texture or 134400) .. ":0|t " .. (c.name or "?")
                    .. (amount and (" x" .. amount) or ""))
            end
        end
    end)
    local hasItem = false
    pcall(function()
        for i = 1, (GetNumQuestLogRewards(questID) or 0) do
            local name, texture, count, quality = GetQuestLogRewardInfo(i, questID)
            if name then
                hasItem = true
                table.insert(lines, "|T" .. (texture or 134400) .. ":0|t |c" .. (QUALITY_HEX[quality] or "ffffffff") .. name .. "|r"
                    .. ((count and count > 1) and (" x" .. count) or ""))
            end
        end
    end)
    if not hasItem and fallbackItem then
        table.insert(lines, "|T" .. GetItemIconSafe(fallbackItem) .. ":0|t |cffa335ee" .. GetItemNameSafe(fallbackItem) .. "|r")
    end
    if #lines > 0 or not rewardsReady then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["보상"], 1, 0.82, 0)
        for _, l in ipairs(lines) do
            GameTooltip:AddLine(l, 1, 1, 1)
        end
        if not rewardsReady and #lines == 0 then
            GameTooltip:AddLine(L["보상 정보를 불러오는 중..."], 0.5, 0.5, 0.5)
        end
    end
end

function QTR.ShowRowTooltip(btn)
    local questID, itemID = rawget(btn, "tipQuest"), rawget(btn, "tipItem")
    local tipLines = rawget(btn, "tipLines")
    local tipPOI = rawget(btn, "tipPOI")
    -- 주의: 게임의 툴팁 위젯(GameTooltip_AddWidgetSet)이나 세계 지도 툴팁 함수(TaskPOI_OnEnter 등)를 부르지 않는다.
    -- 한밤부터 그 함수들은 "비밀 값"을 다루는데, 애드온이 부르면 툴팁 부품이 오염되어
    -- 나중에 세계 지도의 특별 과제 툴팁 등 게임 자체 코드에서 오류가 난다. 아는 정보로 글자만 직접 쓴다.
    if tipPOI then
        -- 골드퀘 탭 지역 줄: 아직 잠긴 특별 과제
        local info = tipPOI.info
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(info.name or L["특별 과제"], 1, 0.82, 0)
        if type(info.description) == "string" and info.description ~= "" then
            GameTooltip:AddLine(info.description, 1, 1, 1, true)
        end
        if tipPOI.progress and tipPOI.total then
            GameTooltip:AddDoubleLine(L["잠금 해제"], L["이 지역 전역퀘 %d/%d 완료"]:format(tipPOI.progress, tipPOI.total),
                1, 0.82, 0, 1, 1, 1)
        end
        -- 이번 주 이 지역 특별 과제: 특별 과제 ID 표에서 남은 시간이 있는 것 (요구 조건과 보상도 함께)
        for qid, sa in pairs(QTR.SPECIAL_ASSIGNMENTS) do
            local left = (sa.mapID == tipPOI.mapID) and QTR.GetSpecialTimeLeft(qid)
            if left then
                GameTooltip:AddDoubleLine(L["남은 시간"], QTR.FormatTimeLeft(left), 1, 0.82, 0, 1, 1, 1)
                local src = DB.cacheSources["q" .. qid]
                QTR.AddQuestDetails(qid, src and src.itemID)
                break
            end
        end
        GameTooltip:Show()
    elseif tipLines then
        -- 획득량 탭: 캐릭터의 획득 내역 (퀘스트 툴팁과 같은 자리)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(tipLines.title)
        for _, l in ipairs(tipLines.lines) do
            GameTooltip:AddDoubleLine(l.left, l.right, 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    elseif questID then
        -- 퀘스트: 이름, 남은 시간, 요구 조건, 보상 (골드는 지금 캐릭터 기준, 전쟁 모드 보너스 포함)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(GetKnownQuestTitle(questID) or L["퀘스트 %s"]:format(questID), 1, 0.82, 0)
        local ok, left = pcall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)
        if not (ok and type(left) == "number" and left > 0) then
            left = QTR.GetSpecialTimeLeft(questID)
        end
        if left then
            GameTooltip:AddDoubleLine(L["남은 시간"], QTR.FormatTimeLeft(left), 1, 0.82, 0, 1, 1, 1)
        end
        local src = DB.cacheSources["q" .. questID]
        QTR.AddQuestDetails(questID, src and src.itemID)
        GameTooltip:Show()
    elseif itemID then
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end
end

function QTR.HideRowTooltip()
    GameTooltip:Hide()
end

-------------------------------------------------------------------------------
-- 웨이포인트: 퀘스트 위치에 지도 핀을 찍고 화면 화살표로 안내한다 (게임 기본 기능)
-- wp = { 지도 ID, x, y } (스캔할 때 조회한 지역 지도 기준 좌표)
-- 그 퀘스트를 완료하면 핀이 아직 그 자리에 있을 때만 지운다 (그사이 다른 핀을 찍었다면 그대로 둔다)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- /qtr pos: 지금 서 있는 곳의 지도 ID와 좌표를 저장한다 (포탈 위치, 포탈 도착 위치 수집용)
-- DB.posLog = { { note, mapID, map, path, x, y, continent, wx, wy, t }, ... }
--   map: 지도 이름, path: 위쪽 지도 이름들 (예: "실버문 < 영원노래 숲 < 쿠엘탈라스")
--   x, y: 그 지도 기준 좌표 (0~1), wx, wy: 월드 좌표 (대륙 continent 기준, 야드)
-- 저장한 값은 /reload 하거나 접속을 끊을 때 SavedVariables 파일(QuestsToRiches.lua)에 기록된다.
-------------------------------------------------------------------------------
function QTR.PosCommand(arg)
    DB.posLog = DB.posLog or {}
    local sub = arg:lower()
    if sub == "list" then
        if #DB.posLog == 0 then
            Print(L["저장한 좌표가 없습니다. 포탈 앞에서 /qtr pos 메모 를 입력하세요."])
        end
        for i, e in ipairs(DB.posLog) do
            Print(string.format(L["#%d %s / 지도 %d %s / %.2f, %.2f"], i, e.note ~= "" and e.note or L["(메모 없음)"],
                e.mapID, e.map or "?", e.x * 100, e.y * 100))
        end
        return
    elseif sub == "clear" then
        DB.posLog = {}
        Print(L["저장한 좌표를 모두 지웠습니다."])
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local p = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not p then
        Print(L["지금 위치에서는 좌표를 읽을 수 없습니다. (인스턴스 안 등)"])
        return
    end
    local x, y = p.x, p.y
    if p.GetXY then
        x, y = p:GetXY()
    end
    -- 지도 이름과 위쪽 지도들
    local info = C_Map.GetMapInfo(mapID)
    local names, parent = {}, info and info.parentMapID
    while parent and parent > 0 and #names < 5 do
        local pi = C_Map.GetMapInfo(parent)
        if not pi then
            break
        end
        table.insert(names, pi.name)
        parent = pi.parentMapID
    end
    local e = {
        note = arg, mapID = mapID, map = info and info.name, path = table.concat(names, " < "),
        x = math.floor(x * 1000000 + 0.5) / 1000000, y = math.floor(y * 1000000 + 0.5) / 1000000,
        subzone = GetSubZoneText and GetSubZoneText() or nil, t = time(),
    }
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok, continent, wpos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
        if ok and continent and wpos then
            e.continent = continent
            e.wx, e.wy = math.floor(wpos.x * 10 + 0.5) / 10, math.floor(wpos.y * 10 + 0.5) / 10
        end
    end
    table.insert(DB.posLog, e)
    Print(string.format(L["좌표 #%d 저장: %s / 지도 %d %s%s / %.2f, %.2f"], #DB.posLog,
        arg ~= "" and arg or L["(메모 없음)"], mapID, e.map or "?",
        (e.subzone and e.subzone ~= "") and (" (" .. e.subzone .. ")") or "", x * 100, y * 100))
end

-- TomTom이 있으면 TomTom 웨이포인트와 화살표를 쓰고(내비게이션과 같은 방식), 없으면 게임 기본 지도 핀을 쓴다.
-- zone: 채팅 안내에 붙일 지역 이름 (없어도 된다)
function QTR.HasTomTom()
    return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
end

-- silent: 채팅 안내를 하지 않는다 (내비게이션이 "다음 목적지"를 따로 알릴 때)
function QTR.SetWaypoint(questID, title, wp, zone, silent)
    local label = QTR.NoPrefix(title or tostring(questID)) .. ((zone and zone ~= "") and (" (" .. zone .. ")") or "")
    if not wp then
        Print(L["이 퀘스트는 아직 위치를 모릅니다. 그 지역 지도에 이 퀘스트가 보이는 캐릭터로 접속하면 위치를 기억합니다."])
        return false
    end
    local mapID, x, y = wp[1], wp[2], wp[3]
    -- 먼저 찍어 둔 우리 웨이포인트는 지운다 (한 번에 하나만)
    if QTR.waypoint then
        QTR.ClearWaypointFor(QTR.waypoint.questID)
    end

    if QTR.HasTomTom() then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, {
            title = label, persistent = false, minimap = true, world = true, from = "QuestsToRiches",
        })
        if ok and uid then
            if TomTom.SetCrazyArrow then
                pcall(TomTom.SetCrazyArrow, TomTom, uid, 15, label)
            end
            QTR.waypoint = { questID = questID, uid = uid }
            if not silent then
                Print(L["웨이포인트: "] .. label)
            end
            return true
        end
        -- TomTom 등록에 실패하면 아래 게임 기본 핀으로 다시 시도한다
    end

    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        -- 하위 지도(예: 하란다르의 "소굴")에는 핀을 못 찍을 수 있다: 같은 자리를 위쪽 지도 좌표로 바꿔 찍는다
        local info = C_Map.GetMapInfo(mapID)
        local parent = info and info.parentMapID
        local moved = false
        if parent and parent > 0 and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D then
            local ok, cont, wpos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
            if ok and cont and wpos then
                local ok2, _, ppos = pcall(C_Map.GetMapPosFromWorldPos, cont, wpos, parent)
                if ok2 and ppos and C_Map.CanSetUserWaypointOnMap(parent) then
                    mapID, x, y = parent, ppos.x, ppos.y
                    moved = true
                end
            end
        end
        if not moved then
            Print(L["이 지도에는 웨이포인트를 찍을 수 없습니다: "] .. label)
            return false
        end
    end
    local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
    -- 실제로 핀이 생겼는지 확인한다 (호출이 오류 없이 끝나도 핀이 안 생기는 경우를 잡는다)
    if not ok or (C_Map.HasUserWaypoint and not C_Map.HasUserWaypoint()) then
        Print(L["웨이포인트를 찍지 못했습니다: "] .. label)
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    QTR.waypoint = { questID = questID, mapID = mapID, x = x, y = y }
    if not silent then
        Print(L["웨이포인트: "] .. label)
    end
    return true
end

-- 골드퀘 탭 줄 클릭: 내비게이션 중에는 웨이포인트를 찍지 않는다 (2026-10-27 사용자 요청: 내비게이션 안내와 겹치지 않게)
--   아무 반응이 없으면 고장으로 보일 수 있어 채팅으로 한 줄 알린다 (연달아 누를 때 도배하지 않게 10초에 한 번)
function QTR.TabWaypoint(questID, title, wp, zone)
    if QTR.route then
        local now = GetTime()
        if not QTR.tabWpNote or now - QTR.tabWpNote > 10 then
            QTR.tabWpNote = now
            Print(L["내비게이션 중에는 퀘스트를 눌러도 웨이포인트를 찍지 않습니다. 순서를 바꾸려면 내비게이션 창의 퀘스트 줄을 우클릭하세요."])
        end
        return false
    end
    return QTR.SetWaypoint(questID, title, wp, zone)
end

-------------------------------------------------------------------------------
-- 전쟁 모드 보너스: 전쟁 모드를 켠 캐릭터는 보너스를 받을 수 있는 전역퀘에서 골드를 더 받는다.
-- 골드퀘 탭의 골드는 지금 캐릭터가 실제로 받을 금액(보너스 포함)으로 보여준다.
-- 골드퀘 기준(GOLD_THRESHOLD) 판단과 계정 공용 목록(부자되기 탭)은 보너스 없는 기본 금액을 쓴다.
-- (퀘스트 보상 골드 API가 기본 금액을 돌려준다고 보고 계산한다. 게임 안에서 확인 필요)
-------------------------------------------------------------------------------
function QTR.WarBonusPct()
    if not (C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired()) then
        return 0
    end
    local b = C_PvP.GetWarModeRewardBonus and C_PvP.GetWarModeRewardBonus()
    return (type(b) == "number" and b > 0) and b or 0
end

function QTR.WithWarBonus(questID, money)
    local b = QTR.WarBonusPct()
    if b > 0 and C_QuestLog.QuestCanHaveWarModeBonus and C_QuestLog.QuestCanHaveWarModeBonus(questID) then
        return math.floor(money * (1 + b / 100))
    end
    return money
end

-- 퀘스트 완료 시: 우리가 찍은 핀이 아직 그대로면 지운다
function QTR.ClearWaypointFor(questID)
    local w = QTR.waypoint
    if not (w and w.questID == questID) then
        return
    end
    QTR.waypoint = nil
    if w.uid then
        -- TomTom으로 찍은 웨이포인트
        if QTR.HasTomTom() and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, w.uid)
        end
        return
    end
    local p = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    local pos = p and p.position
    if p and p.uiMapID == w.mapID and pos and math.abs(pos.x - w.x) < 0.0005 and math.abs(pos.y - w.y) < 0.0005 then
        pcall(C_Map.ClearUserWaypoint)
    end
end

local function RenderList(list, entries)
    local fontPath, _, fontFlags = GameFontHighlight:GetFont()
    local size = 12
    local lineHeight = size + 4
    for i, entry in ipairs(entries) do
        local cells = entry
        if type(entry) == "string" then
            cells = { { text = entry, x = COL.name.x, w = LIST_WIDTH - COL.name.x, justify = "LEFT" } }
        end
        local row = list.rows[i]
        if not row then
            row = {}
            list.rows[i] = row
        end
        for j, cell in ipairs(cells) do
            local fs = row[j]
            if not fs then
                fs = list.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetWordWrap(false)
                row[j] = fs
            end
            fs:SetFont(fontPath, size, fontFlags)
            fs:SetJustifyH(cell.justify)
            fs:SetWidth(cell.w)
            fs:SetHeight(lineHeight)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", list.content, "TOPLEFT", cell.x, -(i - 1) * lineHeight)
            fs:SetText(cell.text)
            fs:Show()
        end
        for j = #cells + 1, #row do
            row[j]:Hide()
        end
    end
    for i = #entries + 1, #list.rows do
        for _, fs in ipairs(list.rows[i]) do
            fs:Hide()
        end
    end
    -- 강조 줄(highlight): 지금 접속한 캐릭터 줄을 밝은 노란색 사각형 테두리로 감싼다 (안쪽은 비워 글자를 가리지 않는다)
    list.bands = list.bands or {}
    for i, entry in ipairs(entries) do
        local box = list.bands[i]
        if type(entry) == "table" and entry.highlight then
            if not box then
                box = CreateFrame("Frame", nil, list.content)
                local edges = {}
                for k = 1, 4 do
                    local t = box:CreateTexture(nil, "OVERLAY")
                    t:SetColorTexture(1, 1, 0, 1)
                    edges[k] = t
                end
                -- 위, 아래, 왼쪽, 오른쪽 (두께 1)
                edges[1]:SetPoint("TOPLEFT", box, "TOPLEFT")
                edges[1]:SetPoint("TOPRIGHT", box, "TOPRIGHT")
                edges[1]:SetHeight(1)
                edges[2]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
                edges[2]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
                edges[2]:SetHeight(1)
                edges[3]:SetPoint("TOPLEFT", box, "TOPLEFT")
                edges[3]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
                edges[3]:SetWidth(1)
                edges[4]:SetPoint("TOPRIGHT", box, "TOPRIGHT")
                edges[4]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
                edges[4]:SetWidth(1)
                list.bands[i] = box
            end
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(i - 1) * lineHeight)
            box:SetSize(LIST_WIDTH, lineHeight)
            box:Show()
        elseif box then
            box:Hide()
        end
    end
    -- 강조 상자는 일부 줄에만 만들어지는 띄엄띄엄한 표라서 #으로 길이를 셀 수 없다. pairs로 모두 확인한다.
    for i, box in pairs(list.bands) do
        if i > #entries then
            box:Hide()
        end
    end

    -- 누를 수 있는 줄(onClick)이나 툴팁이 있는 줄(tipQuest, tipItem)은 그 줄 전체를 버튼으로 덮는다
    list.clicks = list.clicks or {}
    for i, entry in ipairs(entries) do
        local btn = list.clicks[i]
        if type(entry) == "table" and (entry.onClick or entry.onRightClick or entry.tipQuest or entry.tipItem
            or entry.tipLines or entry.tipPOI) then
            if not btn then
                btn = CreateFrame("Button", nil, list.content)
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(btn)
                hl:SetColorTexture(1, 1, 1, 0.08)
                -- 왼쪽 클릭과 오른쪽 클릭을 줄마다 다르게 쓴다 (예: 부자되기 탭은 왼쪽 펼치기, 오른쪽 웨이포인트)
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function(self, button)
                    local fn = (button == "RightButton") and self.rightFn or self.leftFn
                    if fn then
                        fn(self)
                    end
                end)
                list.clicks[i] = btn
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(i - 1) * lineHeight)
            btn:SetSize(LIST_WIDTH, lineHeight)
            btn.leftFn, btn.rightFn = entry.onClick, entry.onRightClick
            btn.tipQuest, btn.tipItem, btn.tipLines, btn.tipPOI = entry.tipQuest, entry.tipItem, entry.tipLines, entry.tipPOI
            if entry.tipQuest or entry.tipItem or entry.tipLines or entry.tipPOI then
                btn:SetScript("OnEnter", QTR.ShowRowTooltip)
                btn:SetScript("OnLeave", QTR.HideRowTooltip)
            else
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
            end
            btn:Show()
        elseif btn then
            btn:Hide()
        end
    end
    -- 줄 버튼도 일부 줄에만 만들어지므로 pairs로 모두 확인한다.
    for i, btn in pairs(list.clicks) do
        if i > #entries then
            btn:Hide()
        end
    end
    list.content:SetHeight(math.max(#entries * lineHeight, 1))
    list.FitFrame()
    list.UpdateScrollBar()
end

local function CreateText(parent, x, y, fontObject)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    return fs
end

-- 탭 영역 버튼의 대시보드 단축키: QTR.panelKeys[탭 영역][키] = 버튼 (대시보드 OnKeyDown이 지금 탭의 것만 누른다)
QTR.panelKeys = {}

-- key를 주면 그 탭에서 key로도 누를 수 있다. 버튼 글자에는 표기하지 않고 툴팁으로 알린다.
-- 툴팁 제목은 tip (없으면 버튼 글자). 쉼표, 마침표 키는 마우스 휠로도 누른다 (QTR.PanelWheel).
local function CreateButton(parent, text, width, key, tip)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetText(text)
    if key then
        QTR.panelKeys[parent] = QTR.panelKeys[parent] or {}
        QTR.panelKeys[parent][key] = btn
        if key == "," then
            -- 이전/다음 버튼이 있는 탭 영역은 휠로도 넘긴다 (목록 위는 CreateList가 스크롤할 게 없을 때만 넘겨준다)
            parent:EnableMouseWheel(true)
            parent:SetScript("OnMouseWheel", QTR.PanelWheel)
        end
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tip or text)
            local keyName = ({ [","] = L["쉼표(,) 또는 마우스 휠 위로"], ["."] = L["마침표(.) 또는 마우스 휠 아래로"] })[key] or key
            GameTooltip:AddLine(L["단축키 "] .. keyName, 0.25, 1, 0.25, true)
            GameTooltip:AddLine(L["창 위에 마우스가 있고 전투 중이 아닐 때 작동합니다."], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    return btn
end

-- 마우스 휠: 위로 돌리면 쉼표(이전), 아래로 돌리면 마침표(다음) 버튼을 누른다 (보이고 눌 수 있을 때만)
function QTR.PanelWheel(panel, delta)
    local keys = QTR.panelKeys[panel]
    local btn = keys and keys[delta > 0 and "," or "."]
    if btn and btn:IsShown() and btn:IsEnabled() ~= false then
        btn:Click()
    end
end

-------------------------------------------------------------------------------
-- 머리 영역 (어느 탭에서나 항상 보인다)
-------------------------------------------------------------------------------

local hdr = {}



local function CreateBar(y)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetSize(400, 22)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.82, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- 총 보유와 목표 금액은 이 막대 글자(보유 / 목표)로 보여준다
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    bar.text:SetPoint("CENTER")
    return bar
end

-- 목표 진행률 (목표 금액은 설정창에서 정한다)
hdr.goalBar = CreateBar(-34) -- 창 제목 바로 아래

-- 일평균과 달성 예상일: 세 줄 모두 왼쪽 이름(x=20)과 값(처음 x=150, 아래 AlignHeaderValues가 당긴다)을 같은 글자 크기로 맞춘다
-- 하루 평균 줄은 흰 글자, 달성 예상 줄 이름은 노란 글자
hdr.avg = {
    CreateText(f, 20, -62, "GameFontHighlightSmall"),
    CreateText(f, 150, -62),
}
hdr.avg[1]:SetText(L["하루 평균 (최근 %d일)"]:format(AVG_DAYS))

hdr.etaWQ = {
    CreateText(f, 20, -82, "GameFontNormalSmall"),
    CreateText(f, 150, -82),
}
hdr.etaWQ[1]:SetText(L["달성 예상 (획득 추세)"])

hdr.etaHold = {
    CreateText(f, 20, -98, "GameFontNormalSmall"),
    CreateText(f, 150, -98),
}
hdr.etaHold[1]:SetText(L["달성 예상 (순증 추세)"])

-- 값 칸은 두 "달성 예상 (... 추세)" 이름 중 긴 쪽 바로 뒤(5픽셀)에 붙인다 (세 줄 모두 같은 x로 맞춤)
-- 불러오는 순간에는 글꼴 폭이 정확하지 않을 수 있어 머리 영역을 갱신할 때 맞춘다
function QTR.AlignHeaderValues()
    -- 하루 평균 이름도 함께 잰다 (영어 "Daily avg (7 days)"가 값과 겹치지 않게, 2026-10-31)
    local w = math.max(hdr.etaWQ[1]:GetStringWidth() or 0, hdr.etaHold[1]:GetStringWidth() or 0,
        hdr.avg[1]:GetStringWidth() or 0)
    if w <= 0 then
        return -- 폭을 못 읽으면 처음 위치(150) 그대로 둔다
    end
    local x = math.min(150, math.ceil(20 + w + 5))
    if hdr.valueX == x then
        return
    end
    hdr.valueX = x
    for _, row in ipairs({ { hdr.avg, -62 }, { hdr.etaWQ, -82 }, { hdr.etaHold, -98 } }) do
        row[1][2]:ClearAllPoints()
        row[1][2]:SetPoint("TOPLEFT", f, "TOPLEFT", x, row[2])
    end
end

-- 달성률에 따른 막대 색: 0% 빨강 -> 50% 노랑 -> 100% 초록 (사이는 부드럽게 섞는다)
-- 흰 글자가 잘 보이도록 밝기를 조금 낮춘다
local BAR_BRIGHTNESS = 0.85

local function SetBar(bar, totalGold, goal)
    local ratio = math.max(0, math.min(totalGold / goal, 1))
    bar:SetValue(ratio)
    local r, g
    if ratio < 0.5 then
        r, g = 1, ratio * 2
    else
        r, g = (1 - ratio) * 2, 1
    end
    bar:SetStatusBarColor(r * BAR_BRIGHTNESS, g * BAR_BRIGHTNESS, 0)
    bar.text:SetText(string.format("%s / %s (%.2f%%)", BreakUpLargeNumbers(totalGold), BreakUpLargeNumbers(goal), ratio * 100))
end

-- 머리 영역 갱신: 보유 골드, 목표 진행률, 하루 평균, 달성 예상일
function QTR:UpdateHeader()
    UpdateWarbandMoney()
    QTR.AlignHeaderValues()

    local total = GetAccountTotals()
    local totalGold = CopperToGold(total)
    local goalGold = GetGoalGold()
    SetBar(hdr.goalBar, totalGold, goalGold)

    local avg = GetRecentAverage(AVG_DAYS)
    local trend = GetHoldingTrend()
    local avgLabel = L["골드퀘 획득 "] .. FormatGold(avg)
    if trend then
        -- 늘면 흰색 "+", 줄면 빨간 "-", 변화가 없으면 회색 "+0" (보유량 탭과 같은 기호)
        local trendText = FormatSignedGold(trend)
        if CopperToGold(math.abs(trend)) == 0 then
            trendText = "|cff808080" .. FormatSignedGold(0) .. "|r"
        elseif trend < 0 then
            trendText = "|cffff4444" .. trendText .. "|r"
        end
        avgLabel = avgLabel .. L[" / 보유량 순증 "] .. trendText
    else
        avgLabel = avgLabel .. L[" / 보유량 순증 |cff808080기록 2일 이상 필요|r"]
    end
    hdr.avg[2]:SetText(avgLabel)

    -- 오늘 번 골드퀘 수익으로 달성 예상이 얼마나 앞당겨졌는지 옆에 붙인다
    local etaText = FormatEta(goalGold, total, avg)
    local _, todayMoney = GetDayTotal(GetDayKey())
    local savedToday = GetTimeSaved(todayMoney, avg, total)
    if savedToday then
        etaText = etaText .. L["  |cff00ff00오늘 %s 단축|r"]:format(FormatDurationDHM(savedToday))
    end
    hdr.etaWQ[2]:SetText(etaText)
    hdr.etaHold[2]:SetText(FormatEta(goalGold, total, trend, true))
end

-------------------------------------------------------------------------------
-- 획득량 탭 (이전 이름: 통계)
-------------------------------------------------------------------------------

local stats = {}

local MODE_ORDER = { "day", "week", "month", "all" }
local MODE_NAMES = { day = L["일별"], week = L["주별"], month = L["월별"], all = L["전체"] }
-- 보기 버튼 단축키는 왼쪽부터 Q W E R (자리 순서. 창 위에 마우스가 있을 때만 받으므로 이동 키와 겹쳐도 된다)
stats.modeKeys = { day = "Q", week = "W", month = "E", all = "R" }

stats.modeButtons = {}
stats.periodByMode = {} -- [모드] = 그 모드에서 마지막으로 보던 기간 키 (이번 접속 동안)
for i, mode in ipairs(MODE_ORDER) do
    local btn = CreateButton(statsPanel, MODE_NAMES[mode], 70, stats.modeKeys[mode])
    if i == 1 then
        btn:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 20, -6)
    else
        btn:SetPoint("LEFT", stats.modeButtons[MODE_ORDER[i - 1]], "RIGHT", 6, 0)
    end
    -- 일별, 주별, 월별은 각자 마지막으로 보던 날짜(기간)를 기억한다.
    -- 지금 보던 기간을 지금 모드 몫으로 남기고, 바꿀 모드가 마지막으로 보던 기간을 꺼낸다 (처음이면 현재 기간)
    btn:SetScript("OnClick", function()
        stats.periodByMode[statsMode] = statsPeriodKey
        statsMode = mode
        statsPeriodKey = stats.periodByMode[mode]
        QTR:Refresh()
    end)
    stats.modeButtons[mode] = btn
end

-- 이전/다음은 "<" ">" 글자가 있는 쉼표, 마침표 키 (글자 표기 대신 툴팁으로 알린다)
local statsPrevBtn = CreateButton(statsPanel, "<", 30, ",", L["이전 기간"])
statsPrevBtn:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 20, -38)

stats.periodText = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
stats.periodText:SetPoint("LEFT", statsPrevBtn, "RIGHT", 8, 0)
stats.periodText:SetWidth(200)
stats.periodText:SetWordWrap(false) -- 줄바꿈하지 않는다 (전체 보기 "전체 (26/10/16 ~ 26/10/30, 15일)"이 두 줄로 나뉘었다, 2026-10-30)

local statsNextBtn = CreateButton(statsPanel, ">", 30, ".", L["다음 기간"])
statsNextBtn:SetPoint("LEFT", stats.periodText, "RIGHT", 8, 0)

local statsNowBtn = CreateButton(statsPanel, L["현재"], 50, "T", L["현재 기간"])
statsNowBtn:SetPoint("LEFT", statsNextBtn, "RIGHT", 8, 0)

stats.summary1 = CreateText(statsPanel, 20, -70, "GameFontNormal")
stats.summary2 = CreateText(statsPanel, 20, -90, "GameFontHighlightSmall")

stats.list = CreateList(statsPanel, -112)

-- 순위 매기기: 골드가 많은 순으로 차례대로 넣으면 순위를 돌려준다.
-- 골드가 같으면 같은 순위이고, 다음 순위는 그만큼 건너뛴다. (예: 1, 2, 2, 4)
local function NewRanker()
    local index, rank, lastMoney = 0, 0, nil
    return function(money)
        index = index + 1
        if money ~= lastMoney then
            rank = index
            lastMoney = money
        end
        return rank
    end
end

-- 1~3위는 금, 은, 동 색, 나머지는 회색
local RANK_COLORS = { "|cffffd100", "|cffc0c0c0", "|cffcd7f32" }

local function FormatRank(rank)
    return (RANK_COLORS[rank] or "|cff808080") .. rank .. "|r"
end

local function SortCharsByMoney(chars)
    local keys = {}
    for key in pairs(chars) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        local ma = chars[a].money or 0
        local mb = chars[b].money or 0
        if ma ~= mb then
            return ma > mb
        end
        return a < b
    end)
    return keys
end

-- 획득량 탭 "보관함 대박" 묶음 (2026-10-27, 인벤 봉구c 피드백 "보관함 대박을 획득량에 보여 주면 동기부여")
--   요약 줄 "보관함 대박 n회 (별)"에 대응하는 대박 기록만 보여 준다 (2026-10-29 사용자 결정: 연 개수는 지금 중요하지 않고,
--   캐릭터 줄 툴팁에도 보관함이 나온다). 그 기간에 대박이 없으면 묶음을 그리지 않는다
--   등급마다 한 줄 (2026-10-29 사용자 결정: 어떤 보관함이었는지보다 골드가 중요하다): 초대박(금별), 대박(은별) 순
--   줄: + | 초대박(별) | 대박 횟수 | 대박 골드 합계. 그 등급의 대박이 없으면 줄이 없다
--   (보관함 아이템 ID는 기록에 그대로 쌓고 이 묶음에서는 보여 주지 않는다. 대박이 없어 보이는 특별 과제 보관함 2종은 자연스럽게 안 나온다)
--   +를 눌러 대박 줄(언제, 캐릭터, 골드)을 펼친다. 처음에는 접혀 있다 (모든 보기, 최근 추이에는 별 없음)
--   펼친 대박 줄: 최근 것부터 10개까지 (사용자 결정, 처음에는 큰 금액 순이었다). 넘으면 "그 밖의 대박 n회" 한 줄
QTR.statsJackpotOpen = {} -- 펼친 등급 { [배수] = true } (이번 접속 동안만)

function QTR.StatsCacheRows(agg, mode, entries)
    local byTier, any = {}, false
    for _, c in ipairs(agg.caches) do
        local tier = QTR.JackpotTier(c.money)
        if tier then
            byTier[tier] = byTier[tier] or { money = 0, jackpots = {} }
            byTier[tier].money = byTier[tier].money + c.money
            table.insert(byTier[tier].jackpots, c)
            any = true
        end
    end
    if not any then
        return
    end
    table.insert(entries, "")
    table.insert(entries, L["|cffffd100보관함 대박|r"])
    for _, j in ipairs(QTR.JACKPOT) do -- 초대박, 대박 순
        local tier = j[2]
        local b = byTier[tier]
        if b then
            local _, star = QTR.JackpotTier(j[1])
            local jackpots = b.jackpots
            local open = QTR.statsJackpotOpen[tier]
            -- "초대박(별)", "대박(별)": + 다음에 한글이 오도록 이름을 앞에, 별은 괄호 안에 (2026-10-29 사용자 요청). 이름도 별과 같은 색
            local label = "|cff" .. j[3] .. QTR.JACKPOT_NAMES[tier] .. "(|r" .. star .. "|cff" .. j[3] .. ")|r"
            table.insert(entries, {
                Cell(open and "|cffffd100-|r" or "|cffffd100+|r", { x = 6, w = 14 }), -- 부자되기 탭과 같은 +, -
                Cell(label, { x = 20, w = 194 }),
                Cell(L["%d회"]:format(#jackpots), COL.periodCount, "RIGHT"),
                Cell(FormatGold(b.money), COL.gold, "RIGHT"),
                onClick = function()
                    QTR.statsJackpotOpen[tier] = not QTR.statsJackpotOpen[tier]
                    QTR:Refresh()
                end,
            })
            if open then
                -- 최근 것이 위 (2026-10-29 사용자 결정: 같은 등급 안에서 금액 순은 어색하다)
                table.sort(jackpots, function(x, y) return (x.t or 0) > (y.t or 0) end)
                local shown = math.min(#jackpots, 10)
                for i = 1, shown do
                    local c = jackpots[i]
                    -- 일별 "07:34", 주별 "17(토) 07:34", 월별 "10/17(토)", 전체 "26/10/17(토)" (2026-10-29 사용자 요청)
                    local when = "?"
                    if c.t then
                        if mode == "day" then
                            when = date("%H:%M", c.t)
                        elseif mode == "week" then
                            when = tonumber(date("%d", c.t)) .. FormatWeekday(c.t, "|cffffffff") .. " " .. date("%H:%M", c.t)
                        elseif mode == "month" then
                            when = tonumber(date("%m", c.t)) .. "/" .. tonumber(date("%d", c.t)) .. FormatWeekday(c.t, "|cffffffff")
                        else
                            when = date("%y/%m/%d", c.t) .. FormatWeekday(c.t, "|cffffffff")
                        end
                    end
                    table.insert(entries, {
                        Cell("|cffffffff" .. when .. "|r", { x = 36, w = 92 }),
                        Cell(ColorName(c.key), { x = 130, w = 146 }),
                        Cell(FormatGold(c.money), COL.gold, "RIGHT"),
                    })
                end
                if #jackpots > shown then
                    table.insert(entries, { Cell(L["|cff808080그 밖의 대박 %d회|r"]:format(#jackpots - shown), { x = 36, w = 240 }) })
                end
            end
        end
    end
end

function QTR:UpdateStats()
    -- 모드 버튼 강조
    for mode, btn in pairs(stats.modeButtons) do
        if mode == statsMode then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    -- 기간 선택
    local isAll = (statsMode == "all")
    if isAll then
        statsPeriodKey = "all"
    else
        local keys = GetSortedPeriodKeys(statsMode)
        local found = false
        for _, k in ipairs(keys) do
            if k == statsPeriodKey then
                found = true
                break
            end
        end
        if not found then
            statsPeriodKey = GetPeriodKey(GetDayKey(), statsMode)
        end
    end
    statsPrevBtn:SetShown(not isAll)
    statsNextBtn:SetShown(not isAll)
    statsNowBtn:SetShown(not isAll)
    -- 전체 보기는 기간 이동 버튼이 숨으므로 기간 글자를 넓게 쓴다 (수집 기간이 붙어 200폭에 안 들어간다)
    stats.periodText:SetWidth(isAll and 320 or 200)
    stats.periodText:SetText(GetPeriodLabel(statsMode, statsPeriodKey))
    -- 영어 요일 "(Thu)"가 길어 주별 기간이 200폭을 넘으면 글자만큼 넓힌다 (다음, 현재 버튼이 그만큼 밀린다, 2026-10-31)
    if not isAll then
        local fs = stats.periodText
        local w = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
        if w > 200 then
            fs:SetWidth(math.min(250, math.ceil(w) + 2))
        end
    end

    -- 요약
    local agg = Aggregate(statsMode, statsPeriodKey)
    local summary = string.format(L["골드 전역퀘 %d개"], agg.count)
    if agg.cacheCount > 0 then
        summary = summary .. string.format(L[", 정점 보관함 %d개"], agg.cacheCount)
    end
    stats.summary1:SetText(summary .. " / " .. FormatGold(agg.money))
    local line2
    if statsMode == "day" then
        local active = 0
        for _, c in pairs(agg.chars) do
            if c.money > 0 then
                active = active + 1
            end
        end
        line2 = L["참여 캐릭터 %d개"]:format(active)
    else
        local perDay = 0
        if agg.days > 0 then
            perDay = agg.money / agg.days
        end
        line2 = L["수행한 날 %d일 / 하루 평균 %s"]:format(agg.days, FormatGold(perDay)) -- 수행한 날 기준 (대박 문구가 붙어 줄였다)
    end
    -- 대박이 있으면 뒤에 " / 보관함 대박 n회 (금별2, 은별5)". 모든 보기 (대박이 없으면 붙이지 않는다)
    local jackpot = QTR.JackpotSummary(agg.caches)
    if jackpot then
        line2 = line2 .. " / " .. jackpot
    end
    stats.summary2:SetText(line2)

    local entries = {}

    -- 캐릭터 기여도 (골드퀘 수익: 전역퀘 + 정점 보관함)
    local charKeys = SortCharsByMoney(agg.chars)
    local hasAny = false
    local ranker = NewRanker()
    for _, key in ipairs(charKeys) do
        local c = agg.chars[key]
        if c.money > 0 then
            hasAny = true
            -- 일별, 주별에서만 캐릭터 줄에 획득 내역 툴팁 (월별, 전체는 너무 길어 붙이지 않는다)
            local tip
            if statsMode == "day" or statsMode == "week" then
                tip = { title = ColorName(key), lines = {} }
                table.sort(c.items, function(a, b) return (a.t or 0) < (b.t or 0) end)
                for _, it in ipairs(c.items) do
                    local when = "?"
                    if it.t then
                        -- 일별은 그날 기록만 나오므로 시각만, 주별은 "5(토) 06:43"
                        if statsMode == "day" then
                            when = date("%H:%M", it.t)
                        else
                            when = tonumber(date("%d", it.t)) .. FormatWeekday(it.t, "|cffffffff") .. " " .. date("%H:%M", it.t)
                        end
                    end
                    -- 골드퀘는 "퀘스트명 (지역명)" (애드온의 다른 목록과 같은 형식)
                    -- 보관함이 대박이면 이름 뒤에 별 (2026-10-27)
                    local _, star = QTR.JackpotTier(it.money)
                    local what = it.cacheID and ("|cffa335ee" .. GetItemNameSafe(it.cacheID) .. "|r" .. (star and (" " .. star) or ""))
                        or ((it.name or "?") .. ((it.zone and it.zone ~= "") and (" (" .. it.zone .. ")") or ""))
                    table.insert(tip.lines, { left = when .. "  " .. what, right = FormatGold(it.money) })
                end
            end
            table.insert(entries, {
                Cell(FormatRank(ranker(c.money)), COL.rank, "RIGHT"),
                Cell(ColorName(key), COL.rankName),
                -- 전역퀘 + 정점 보관함. 아래 최근 추이의 "n개" 칸과 같은 자리, 오른쪽 정렬 ("개"가 한 줄로 맞는다)
                Cell(L["%d개"]:format(c.count + c.cacheCount), COL.periodCount, "RIGHT"),
                Cell(FormatGold(c.money), COL.gold, "RIGHT"),
                Cell("|cff00ff00" .. FormatPercent(c.money, agg.money) .. "|r", COL.pct, "RIGHT"),
                tipLines = tip,
                highlight = (key == charKey), -- 지금 접속한 캐릭터 줄 강조
            })
        end
    end
    if not hasAny then
        table.insert(entries, { Cell(L["|cff808080이 기간에는 기록이 없습니다.|r"], { x = COL.sub.x, w = LIST_WIDTH - COL.sub.x }) })
    end

    -- 보관함 대박 (그 기간에 대박이 있을 때만)
    QTR.StatsCacheRows(agg, statsMode, entries)

    -- 최근 추이
    local trendMode = statsMode
    if isAll then
        trendMode = "month"
    end
    local trendKeys = GetSortedPeriodKeys(trendMode)
    local trendCount = TREND_COUNT[statsMode] or 8
    table.insert(entries, "")
    table.insert(entries, L["|cffffd100최근 추이 (%s)|r"]:format(MODE_NAMES[trendMode]))
    local shown = 0
    for i = #trendKeys, 1, -1 do
        if shown >= trendCount then
            break
        end
        local k = trendKeys[i]
        local a = Aggregate(trendMode, k)
        -- 지금 보고 있는 기간은 노란색으로 강조
        local color = "|cffffffff"
        if k == statsPeriodKey then
            color = "|cffffd100"
        end
        table.insert(entries, {
            Cell(color .. GetPeriodLabel(trendMode, k, true, color) .. "|r", COL.period),
            Cell(color .. L["%d개"]:format(a.count + a.cacheCount) .. "|r", COL.periodCount, "RIGHT"), -- 전역퀘 + 정점 보관함
            Cell(FormatGold(a.money), COL.gold, "RIGHT"),
        })
        shown = shown + 1
    end

    RenderList(stats.list, entries)
end

local function ShiftStatsPeriod(delta)
    local keys = GetSortedPeriodKeys(statsMode)
    local idx
    for i, k in ipairs(keys) do
        if k == statsPeriodKey then
            idx = i
            break
        end
    end
    if not idx then
        idx = #keys
    end
    idx = math.max(1, math.min(#keys, idx + delta))
    statsPeriodKey = keys[idx]
    QTR:Refresh()
end

statsPrevBtn:SetScript("OnClick", function()
    ShiftStatsPeriod(-1)
end)

statsNextBtn:SetScript("OnClick", function()
    ShiftStatsPeriod(1)
end)

statsNowBtn:SetScript("OnClick", function()
    statsPeriodKey = nil
    QTR:Refresh()
end)

-------------------------------------------------------------------------------
-- 보유량 탭 (획득량 탭처럼 위쪽에 보기 버튼 2개)
--   요약: 날짜별 계정 보유 골드 합계 (최근 날짜부터). 날짜 선택 없음.
--         합계는 snapshots(그날 마지막으로 확인한 계정 총 보유, 전투부대 은행 포함)를 쓴다.
--         은행을 넣지 않는 설정이면 QTR.SnapshotAt이 은행을 뺀 값을 준다 (상세도 은행 줄과 합계에서 뺀다).
--   상세: 고른 날짜의 캐릭터별 보유 골드와 비중.
--         골드는 그날까지 마지막으로 확인한 값(holdDays), 그날 접속한 캐릭터에만 녹색불을 켠다.
-------------------------------------------------------------------------------

-- 메인 청크의 local 개수 제한(200) 때문에 이 탭의 local은 do 블록 안에 둔다
do
local hold = {}
local holdDayKey -- 상세 보기에서 고른 날짜, nil이면 오늘

local HOLD_MODE_ORDER = { "sum", "detail" }
local HOLD_MODE_NAMES = { sum = L["요약"], detail = L["상세"] }
local HOLD_MODE_KEYS = { sum = "Q", detail = "W" } -- 획득량 탭 보기 버튼처럼 왼쪽부터 Q W
local ONLINE_ICON = "|TInterface\\COMMON\\Indicator-Green:12:12:0:0|t"

-- 요약 목록의 칸: 날짜 / 합계 / 전날 대비
local HOLD_SUM_COL = {
    day = { x = 4, w = 150 },
    total = { x = 150, w = 128 },
    diff = { x = 280, w = 124 },
}

hold.modeButtons = {}
for i, mode in ipairs(HOLD_MODE_ORDER) do
    local btn = CreateButton(holdPanel, HOLD_MODE_NAMES[mode], 70, HOLD_MODE_KEYS[mode])
    if i == 1 then
        btn:SetPoint("TOPLEFT", holdPanel, "TOPLEFT", 20, -6)
    else
        btn:SetPoint("LEFT", hold.modeButtons[HOLD_MODE_ORDER[i - 1]], "RIGHT", 6, 0)
    end
    btn:SetScript("OnClick", function()
        DB.settings.holdMode = mode
        QTR:Refresh()
    end)
    hold.modeButtons[mode] = btn
end

-- 요약 보기
hold.sumSummary = CreateText(holdPanel, 20, -38, "GameFontNormal")
hold.sumSub = CreateText(holdPanel, 20, -58, "GameFontHighlightSmall")
hold.sumList = CreateList(holdPanel, -80)

-- 상세 보기
local holdPrevBtn = CreateButton(holdPanel, "<", 30, ",", L["이전 날짜"])
holdPrevBtn:SetPoint("TOPLEFT", holdPanel, "TOPLEFT", 20, -38)

hold.dayText = holdPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hold.dayText:SetPoint("LEFT", holdPrevBtn, "RIGHT", 8, 0)
hold.dayText:SetWidth(200)

local holdNextBtn = CreateButton(holdPanel, ">", 30, ".", L["다음 날짜"])
holdNextBtn:SetPoint("LEFT", hold.dayText, "RIGHT", 8, 0)

local holdNowBtn = CreateButton(holdPanel, L["오늘"], 50, "T")
holdNowBtn:SetPoint("LEFT", holdNextBtn, "RIGHT", 8, 0)

-- 요약 한 줄이 길어 작은 글꼴을 쓴다
hold.summary = CreateText(holdPanel, 20, -72, "GameFontNormalSmall")
hold.list = CreateList(holdPanel, -92)

local HOLD_SUM_WIDGETS = { hold.sumSummary, hold.sumSub, hold.sumList.scroll }
local HOLD_DETAIL_WIDGETS = { holdPrevBtn, hold.dayText, holdNextBtn, holdNowBtn, hold.summary, hold.list.scroll }

-- 상세 보기에서 이동할 수 있는 날짜 키 (오래된 순, 오늘 포함)
local function GetHoldDayKeys()
    local keys, hasToday = {}, false
    local today = GetDayKey()
    for k in pairs(DB.holdDays) do
        table.insert(keys, k)
        if k == today then
            hasToday = true
        end
    end
    if not hasToday then
        table.insert(keys, today)
    end
    table.sort(keys)
    return keys
end

-- dayKey 시점의 보유량: 캐릭터마다 dayKey 이전(포함) 마지막 기록
-- 반환: holdings[캐릭터키] = { money, day }, warband = { money, day } 또는 nil
local function GetHoldingsAt(dayKey)
    local keys = {}
    for k in pairs(DB.holdDays) do
        if k <= dayKey then
            table.insert(keys, k)
        end
    end
    table.sort(keys, function(a, b) return a > b end) -- 최근 날짜부터
    local holdings, warband = {}, nil
    for _, k in ipairs(keys) do
        local h = DB.holdDays[k]
        for key, money in pairs(h.chars or {}) do
            if DB.chars[key] and not holdings[key] then
                holdings[key] = { money = money, day = k }
            end
        end
        if not warband and h.warband then
            warband = { money = h.warband, day = k }
        end
    end
    return holdings, warband
end

local function SumHoldings(holdings, warband)
    local charSum = 0
    for _, v in pairs(holdings) do
        charSum = charSum + v.money
    end
    local wb = warband and warband.money or 0
    return charSum + wb, charSum, wb
end

-- noIcon: 골드 아이콘을 뺀다 (보유량 상세의 캐릭터별 전일비)
local function FormatDiff(copper, noIcon)
    local text = FormatSignedGold(copper)
    if noIcon and text:sub(-#GOLD_ICON) == GOLD_ICON then
        text = text:sub(1, -#GOLD_ICON - 1) -- 아이콘은 늘 끝에 붙는다 (패턴 문자 "-"가 있어 gsub 대신 잘라 낸다)
        -- 아이콘 없는 칸은 좁아 "+99,999"까지만 들어간다: 10만 골드부터 "+204k"로 줄인다 (버림, 실제보다 크게 보이지 않게)
        -- 1천만 골드부터는 "+12,345k"(8글자)도 넘칠 수 있어 "+12.3M"으로 (2026-11-03 사용자 결정, 7천만 골드 넘게 가진 사용자 대비)
        local gold = CopperToGold(math.abs(copper))
        if gold >= 10000000 then
            text = text:sub(1, 1) .. string.format("%.1f", math.floor(gold / 100000) / 10) .. "M"
        elseif gold >= 100000 then
            text = text:sub(1, 1) .. BreakUpLargeNumbers(math.floor(gold / 1000)) .. "k"
        end
    end
    if copper > 0 then
        return "|cff00ff00" .. text .. "|r"
    elseif copper < 0 then
        return "|cffff4444" .. text .. "|r"
    end
    return "|cff808080" .. text .. "|r"
end

-- 상세의 보유 골드 칸(폭 82)은 "1,369,190"까지는 넉넉하나 1천만 골드부터 한 자리가 늘어 넘칠 수 있다:
-- "12,345k"로 줄인다 (버림, 2026-11-03 사용자 결정). 1천만 골드 미만은 그대로
function hold.FormatGold(copper)
    local gold = CopperToGold(copper)
    if gold >= 10000000 then
        return BreakUpLargeNumbers(math.floor(gold / 1000)) .. "k" .. GOLD_ICON
    end
    return FormatGold(copper)
end

function QTR:UpdateHoldingsSummary()
    local today = GetDayKey()
    local keys = {}
    for k in pairs(DB.snapshots) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b) return a > b end) -- 최근 날짜부터

    hold.sumSummary:SetText(L["기록 %d일"]:format(#keys))
    hold.sumSub:SetText(QTR.WarbandCounted() and L["|cffaaaaaa그날 마지막으로 확인한 계정 보유 골드 합계 (전투부대 은행 포함)|r"]
        or L["|cffaaaaaa그날 마지막으로 확인한 계정 보유 골드 합계 (전투부대 은행 뺌)|r"])

    local entries = {}
    for i, k in ipairs(keys) do
        local total = QTR.SnapshotAt(k)
        local prev = keys[i + 1] and QTR.SnapshotAt(keys[i + 1])
        local dayLabel = FormatDayKey(k)
        if k == today then
            dayLabel = dayLabel .. L[" |cffffd100오늘|r"]
        end
        local row = {
            Cell(dayLabel, HOLD_SUM_COL.day),
            Cell(FormatGold(total), HOLD_SUM_COL.total, "RIGHT"),
        }
        if prev then
            table.insert(row, Cell(FormatDiff(total - prev), HOLD_SUM_COL.diff, "RIGHT"))
        end
        table.insert(entries, row)
    end
    if #entries == 0 then
        table.insert(entries, { Cell(L["|cff808080보유량 기록이 없습니다.|r"], HOLD_SUM_COL.day) })
    end
    RenderList(hold.sumList, entries)
end

function QTR:UpdateHoldingsDetail()
    local today = GetDayKey()
    local dayKey = holdDayKey or today
    hold.dayText:SetText(FormatDayKey(dayKey) .. ((dayKey == today) and L[" 오늘"] or ""))

    local keys = GetHoldDayKeys()
    if keys[1] and dayKey <= keys[1] then
        holdPrevBtn:Disable()
    else
        holdPrevBtn:Enable()
    end
    if dayKey >= today then
        holdNextBtn:Disable()
    else
        holdNextBtn:Enable()
    end

    local holdings, warband = GetHoldingsAt(dayKey)
    if not QTR.WarbandCounted() then
        warband = nil -- 은행을 넣지 않는 계정: 은행 줄을 빼고 합계, 비중에서도 뺀다
    end
    local total = SumHoldings(holdings, warband)

    -- 요약: 만렙 캐릭터 수, 그날 접속한 만렙 캐릭터 수, 계정 합계(전투부대 은행 포함), 전일비
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    local charCount, onlineCount = 0, 0
    for key, v in pairs(holdings) do
        local c = DB.chars[key]
        if not maxLevel or maxLevel <= 0 or not c or not c.level or c.level >= maxLevel then
            charCount = charCount + 1
            if v.day == dayKey then
                onlineCount = onlineCount + 1
            end
        end
    end
    local prevKey
    for _, k in ipairs(keys) do
        if k < dayKey then
            prevKey = k
        end
    end
    -- 이 줄은 1백만 골드대에서도 창 끝까지 차므로 합계도 1천만 골드부터 k로 줄인다 (hold.FormatGold)
    local summary = L["만렙 캐릭터 %d개 중 접속 %d개 / 합계 %s"]:format(charCount, onlineCount, hold.FormatGold(total))
    -- 전날 기록 (캐릭터별 전일비에도 쓴다)
    local prevHoldings, prevWarband
    if prevKey then
        prevHoldings, prevWarband = GetHoldingsAt(prevKey)
        if not QTR.WarbandCounted() then
            prevWarband = nil
        end
        local prevTotal = SumHoldings(prevHoldings, prevWarband)
        summary = summary .. L[" (전일비 %s)"]:format(FormatDiff(total - prevTotal))
    end
    -- 줄마다 전일비: 전날 기록이 있으면 증가 녹색, 감소 빨강, 같으면 회색 (전날 기록이 없으면 비운다). 골드 아이콘은 뺀다
    local function DiffCell(money, prev)
        return Cell(prev and FormatDiff(money - prev.money, true) or "", COL.holdDiff, "RIGHT")
    end
    hold.summary:SetText(summary)

    -- 전날 순위 (같은 방식으로 매긴다): 순위 등락 칸에 쓴다
    local prevRank = {}
    if prevHoldings then
        local prevList = {}
        for key, v in pairs(prevHoldings) do
            prevList[key] = { money = v.money }
        end
        local prevRanker = NewRanker()
        for _, key in ipairs(SortCharsByMoney(prevList)) do
            prevRank[key] = prevRanker(prevList[key].money)
        end
    end
    -- 순위 등락: 오르면 빨강 "위 세모 n", 내리면 파랑 "아래 세모 n" (칸이 좁아 괄호 없이)
    -- 순위가 그대로이거나 전날 순위가 없으면 비운다
    -- 세모 문자는 소스에 그대로 쓰지 않고 UTF-8 바이트로 넣는다 (U+25B2, U+25BC)
    local function RankMoveCell(key, rank)
        local before = prevRank[key]
        local text = ""
        if before then
            local up = before - rank
            if up > 0 then
                text = "|cffff3333\226\150\178" .. up .. "|r"
            elseif up < 0 then
                text = "|cff3399ff\226\150\188" .. -up .. "|r"
            end
        end
        return Cell(text, COL.holdRank)
    end

    local list = {}
    for key, v in pairs(holdings) do
        list[key] = { money = v.money, day = v.day }
    end
    local entries = {}
    local ranker = NewRanker()
    for _, key in ipairs(SortCharsByMoney(list)) do
        local v = list[key]
        local rank = ranker(v.money)
        table.insert(entries, {
            Cell(FormatRank(rank), COL.rank, "RIGHT"),
            Cell(ColorName(key), COL.rankName),
            Cell((v.day == dayKey) and ONLINE_ICON or "", COL.holdDot),
            Cell(hold.FormatGold(v.money), COL.holdGold, "RIGHT"),
            DiffCell(v.money, prevHoldings and prevHoldings[key]),
            RankMoveCell(key, rank),
            Cell("|cffaaaaaa" .. FormatPercent(v.money, total) .. "|r", COL.holdPct, "RIGHT"),
            highlight = (key == charKey), -- 지금 접속한 캐릭터 줄 강조
        })
    end
    if #entries == 0 then
        table.insert(entries, { Cell(L["|cff808080이 날짜까지의 보유량 기록이 없습니다.|r"], COL.rankName) })
    end
    -- 전투부대 은행은 캐릭터가 아니므로 순위 없이 이름 칸만 맞춘다
    if warband then
        table.insert(entries, {
            Cell(L["전투부대 은행"], COL.rankName),
            Cell((warband.day == dayKey) and ONLINE_ICON or "", COL.holdDot),
            Cell(hold.FormatGold(warband.money), COL.holdGold, "RIGHT"),
            DiffCell(warband.money, prevWarband),
            Cell("|cffaaaaaa" .. FormatPercent(warband.money, total) .. "|r", COL.holdPct, "RIGHT"),
        })
    end
    RenderList(hold.list, entries)
end

function QTR:UpdateHoldings()
    local mode = DB.settings.holdMode
    for m, btn in pairs(hold.modeButtons) do
        if m == mode then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
    local isSum = (mode == "sum")
    for _, w in ipairs(HOLD_SUM_WIDGETS) do
        w:SetShown(isSum)
    end
    for _, w in ipairs(HOLD_DETAIL_WIDGETS) do
        w:SetShown(not isSum)
    end
    if isSum then
        QTR:UpdateHoldingsSummary()
    else
        QTR:UpdateHoldingsDetail()
    end
end

local function ShiftHoldDay(delta)
    local keys = GetHoldDayKeys()
    local dayKey = holdDayKey or GetDayKey()
    local target
    if delta < 0 then
        for _, k in ipairs(keys) do
            if k < dayKey then
                target = k
            end
        end
    else
        for i = #keys, 1, -1 do
            if keys[i] > dayKey then
                target = keys[i]
            end
        end
    end
    if not target then
        return
    end
    if target >= GetDayKey() then
        holdDayKey = nil
    else
        holdDayKey = target
    end
    QTR:Refresh()
end

holdPrevBtn:SetScript("OnClick", function()
    ShiftHoldDay(-1)
end)

holdNextBtn:SetScript("OnClick", function()
    ShiftHoldDay(1)
end)

holdNowBtn:SetScript("OnClick", function()
    holdDayKey = nil
    QTR:Refresh()
end)
end

-------------------------------------------------------------------------------
-- 골드퀘 탭: 지금 수행할 수 있는 골드 전역퀘 목록 (현재 캐릭터 기준)
-- 지역 목록과 특별 과제 판정은 HoneyDelveToday(HDT)의 DB.lua, Core.lua와 같은 방식이다.
--   mapID      : 지역 대표 지도
--   allowedMaps: 그 지역 퀘스트로 인정하는 지도 (대표 지도 조회 시 이웃 지역 퀘스트가 섞여 나오므로 걸러낸다)
--   metaWidgets: 특별 과제 잠김 상태에서 남은 전역퀘 수를 읽는 위젯
-------------------------------------------------------------------------------

-- 메인 청크의 local 개수 제한(200) 때문에 골드퀘 탭과 부자되기 탭의 local은 함수 안에 두고 바로 실행한다
-- (함수마다 local 제한이 따로 있다)
QTR.SetupGQTab = function()
local GQ_ZONES = {
    { mapID = 2395, allowedMaps = { [2393] = true, [2395] = true, [2424] = true }, metaWidgets = { 7710, 7876 } }, -- 영원노래 숲
    -- 줄아만: 2536 아탈아만 (특별 과제 "다시 우리의 것으로!" 91796이 이 지도에 속한다. 2026-11-08 사용자 게임 확인,
    --   빠져 있어서 해금돼도 내비게이션이 몰랐고 위치도 배우지 못했다)
    { mapID = 2437, allowedMaps = { [2437] = true, [2536] = true }, metaWidgets = { 7672, 7675 } },
    { mapID = 2405, allowedMaps = { [2405] = true, [2444] = true }, metaWidgets = { 7659, 7668 } },                -- 공허폭풍
    { mapID = 2413, allowedMaps = { [2413] = true }, metaWidgets = { 7618, 7621 } },                               -- 하란다르
    -- 똬리의 섬: 2642 방황하는 사제의 무덤 (골드퀘 "사술과 거짓" 96329가 이 지도에 속한다. 2026-11-08 사용자 게임 확인, 동선에서 빠졌다)
    { mapID = 2512, allowedMaps = { [2512] = true, [2642] = true }, metaWidgets = { 8259, 8263, 8264 } },
}

-- 지도가 그 지역 것인가: allowedMaps에 있거나, 상위 지도를 따라 올라가 그 지역 대표 지도가 나오면 (하위 지도)
--   2026-11-08: 아탈아만(2536), 방황하는 사제의 무덤(2642)처럼 지역 안의 하위 지도에 속한 퀘스트가 빠지는 일이 되풀이되어
--   목록에 없는 하위 지도도 받는다. 대표 지도 조회에 섞여 나오는 이웃 지역은 대표 지도의 자식이 아니라서 걸러진다.
--   한 번 찾은 결과는 allowedMaps(인정)와 notMaps(아님)에 남긴다
QTR.ZoneHasMap = function(zone, mapID)
    if not mapID then
        return false
    end
    if zone.allowedMaps[mapID] then
        return true
    end
    if zone.notMaps and zone.notMaps[mapID] then
        return false
    end
    local id = mapID
    for _ = 1, 6 do
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        id = info and info.parentMapID
        if not id or id == 0 then
            break
        end
        if id == zone.mapID then
            zone.allowedMaps[mapID] = true
            return true
        end
    end
    zone.notMaps = zone.notMaps or {}
    zone.notMaps[mapID] = true
    return false
end

local META_TOTAL = 3
local META_ICON = 1542860
local SPECIAL_TITLE_PREFIX = QTR.GameText("SPECIAL_PREFIX") or "특별 과제:"

local GQ_REFRESH_SECONDS = 30 -- 탭이 열려 있는 동안 남은 시간 갱신 주기
local GQ_RETRY_SECONDS = 2    -- 퀘스트 정보를 아직 못 받았을 때 다시 읽는 간격
local GQ_RETRY_MAX = 10

local gqRetryCount = 0
local gqRetryPending = false

local function GetZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or tostring(mapID)
end

-- 지도 ID가 속한 골드퀘 지역 이름 (대표 지도나 allowedMaps, 아니면 상위 지도를 따라 올라가며 찾는다). 아니면 nil
-- 예: 학살자의 오름길(2444)은 공허폭풍. 완료 기록의 지역명을 골드퀘 지역 이름으로 맞추는 데 쓴다
function QTR.GQZoneNameOfMap(mapID)
    for _ = 1, 6 do
        if not mapID or mapID == 0 then
            return nil
        end
        for _, zone in ipairs(GQ_ZONES) do
            if zone.mapID == mapID or zone.allowedMaps[mapID] then
                return GetZoneName(zone.mapID)
            end
        end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
    end
    return nil
end

-- 이미 남은 완료 기록의 지역명 바로잡기 (2026-10-24): 예전에는 하위 지도 이름(학살자의 오름길 등)으로 남은 기록이 있었다
-- 골드퀘 지역의 allowedMaps와 하위 지도(게임이 알려 주는 모든 자식 지도) 이름을 그 지역 이름으로 바꾼다.
-- 날짜별 골드퀘 완료 기록(days)만 고친다 (보관함 출처 등은 그대로)
function QTR.FixRecordedZones()
    local rename = {}
    for _, zone in ipairs(GQ_ZONES) do
        local zoneName = GetZoneName(zone.mapID)
        local function Add(name)
            if name and name ~= zoneName and not rename[name] then
                rename[name] = zoneName
            end
        end
        for mapID in pairs(zone.allowedMaps) do
            local info = C_Map.GetMapInfo(mapID)
            Add(info and info.name)
        end
        if C_Map.GetMapChildrenInfo then
            local ok, children = pcall(C_Map.GetMapChildrenInfo, zone.mapID, nil, true)
            if ok and type(children) == "table" then
                for _, child in ipairs(children) do
                    Add(child.name)
                end
            end
        end
    end
    local fixed = 0
    for _, day in pairs(DB.days) do
        for _, rec in pairs(day) do
            for _, q in ipairs(rec.quests or {}) do
                local to = q.zone and rename[q.zone]
                if to then
                    q.zone = to
                    fixed = fixed + 1
                end
            end
        end
    end
    return fixed
end

-- 남은 시간 표시: 45분, 3시간 12분, 2일 5시간
local function FormatTimeLeft(seconds)
    if not seconds or seconds <= 0 then
        return "|cff808080?|r"
    end
    -- 칸이 좁아 짧게 쓴다: "1d 23h 48m", "7h 5m", "42m" (앞자리 단위가 0이면 생략)
    local minutes = math.max(math.floor(seconds / 60), 1)
    local days = math.floor(minutes / 1440)
    local hours = math.floor((minutes % 1440) / 60)
    local mins = minutes % 60
    local text
    if days > 0 then
        text = days .. "d " .. hours .. "h " .. mins .. "m"
    elseif hours > 0 then
        text = hours .. "h " .. mins .. "m"
    else
        text = mins .. "m"
    end
    -- 1시간 미만 빨강, 6시간 미만 주황, 그 외 회색
    if seconds < 3600 then
        return "|cffff4444" .. text .. "|r"
    elseif seconds < 6 * 3600 then
        return "|cffff8000" .. text .. "|r"
    end
    return "|cffaaaaaa" .. text .. "|r"
end
QTR.FormatTimeLeft = FormatTimeLeft -- 목록 툴팁에서도 쓴다

local function GetQuestTimeLeft(questID)
    if C_TaskQuest.GetQuestTimeLeftSeconds then
        local s = C_TaskQuest.GetQuestTimeLeftSeconds(questID)
        if s and s > 0 then
            return s
        end
    end
    if C_TaskQuest.GetQuestTimeLeftMinutes then
        local m = C_TaskQuest.GetQuestTimeLeftMinutes(questID)
        if m and m > 0 then
            return m * 60
        end
    end
    return nil
end

-- 특별 과제 판정 (HDT Core.lua와 같은 방식)
local function IsSpecialAssignmentQuest(questID)
    local capstoneType = Enum and Enum.QuestTagType and Enum.QuestTagType.Capstone
    if capstoneType and C_QuestLog.GetQuestTagInfo then
        local ok, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if ok and tagInfo and tagInfo.worldQuestType == capstoneType then
            return true
        end
    end
    local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
    if type(title) == "string" and title:find(SPECIAL_TITLE_PREFIX, 1, true) == 1 then
        return true
    end
    return false
end

local function ReadMetaWidgetNumber(widgetID)
    local ok, text = pcall(function()
        local w = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgetID)
        return w and w.text
    end)
    if not ok or type(text) ~= "string" or text == "" then
        return nil
    end
    return tonumber(text:match("%d+"))
end

local function GetPOIWidgetIDs(info)
    local ids = {}
    if not (C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID) then
        return ids
    end
    for _, setID in ipairs({ info.tooltipWidgetSet, info.widgetSetID }) do
        if type(setID) == "number" and setID > 0 then
            local ok, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
            if ok and type(widgets) == "table" then
                for _, w in ipairs(widgets) do
                    if w.widgetID then
                        table.insert(ids, w.widgetID)
                    end
                end
            end
        end
    end
    return ids
end

local function GetZoneMapIDs(zone)
    local ids = { zone.mapID }
    local others = {}
    for mapID in pairs(zone.allowedMaps) do
        if mapID ~= zone.mapID then
            table.insert(others, mapID)
        end
    end
    table.sort(others)
    for _, mapID in ipairs(others) do
        table.insert(ids, mapID)
    end
    return ids
end

local function IsPrimaryInOtherZone(zone, poiID)
    for _, other in ipairs(GQ_ZONES) do
        if other ~= zone then
            for _, mapID in ipairs(GetZoneMapIDs(other)) do
                for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(mapID) or {}) do
                    if id == poiID then
                        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
                        if info and info.isPrimaryMapForPOI ~= false then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function HasPendingMetaWidget(zone)
    for _, wID in ipairs(zone.metaWidgets) do
        local n = ReadMetaWidgetNumber(wID)
        if n and n > 0 then
            return true
        end
    end
    return false
end

local function GetCapstonePOIs(zone)
    local result, seen = {}, {}
    for _, mapID in ipairs(GetZoneMapIDs(zone)) do
        for _, poiID in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(mapID) or {}) do
            if not seen[poiID] then
                local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
                if info and info.atlasName and info.atlasName:find("Capstone") then
                    if info.isPrimaryMapForPOI ~= false
                        or (not IsPrimaryInOtherZone(zone, poiID) and HasPendingMetaWidget(zone)) then
                        seen[poiID] = true
                        info.qtrMapID = mapID -- 좌표(position)가 이 지도 기준이다 (내비게이션의 해금 예정 목적지용)
                        table.insert(result, info)
                    end
                end
            end
        end
    end
    return result
end

local function GetMetaRemaining(zone, poiInfo)
    local listed = {}
    for _, wID in ipairs(zone.metaWidgets) do
        listed[wID] = true
    end
    for _, wID in ipairs(GetPOIWidgetIDs(poiInfo)) do
        if listed[wID] then
            local n = ReadMetaWidgetNumber(wID)
            if n then
                return n
            end
        end
    end
    local found
    for _, wID in ipairs(zone.metaWidgets) do
        local n = ReadMetaWidgetNumber(wID)
        if n then
            if n > 0 then
                return n
            end
            found = found or n
        end
    end
    return found
end

-- 반환값: true = 수행 가능, false = 잠김(진행도), nil = 없음
-- 세 번째 값: 수행 가능이면 특별 과제 퀘스트 ID, 잠김이면 지도의 특별 과제 표시(POI) 정보 (지역 줄 툴팁용)
local function GetZoneMetaState(zone, quests)
    for _, v in ipairs(quests) do
        if QTR.ZoneHasMap(zone, v.mapID) and C_QuestLog.IsWorldQuest(v.questID) and IsSpecialAssignmentQuest(v.questID) then
            return true, META_TOTAL, v.questID
        end
    end
    local capstones = GetCapstonePOIs(zone)
    if #capstones > 0 then
        local remaining = GetMetaRemaining(zone, capstones[1])
        if remaining then
            return false, math.max(0, META_TOTAL - remaining), capstones[1]
        end
        return false, 0, capstones[1]
    end
    return nil, 0
end

-- 계정 공용 골드 전역퀘 목록 (activeGQ)
-- 같은 퀘스트가 다음 회차에 같은 ID로 다시 나오므로, 회차가 바뀌면 직전 회차 만료 시각을 남긴다.
local GQ_MAX_DURATION = 4 * 86400 -- 직전 회차를 모를 때 이번 회차 시작을 만료 시각에서 거꾸로 잡는 길이

-- cacheItem: 보상이 정점 보관함인 퀘스트(특별 과제)면 그 아이템 ID (골드 대신 보관함 아이콘으로 보여준다)
local GQ_EXPIRE_GRACE = 600 -- 만료 뒤 이 시간(초) 안에 남은 시간 없이 다시 읽히면 사라지기 직전의 지난 회차로 본다

local function RememberGoldQuest(questID, title, zoneName, mapID, money, timeLeft, cacheItem)
    local e = DB.activeGQ[questID]
    local now = time()
    -- 만료 순간에 지도에서 사라지기 직전의 퀘스트를 한 번 더 읽으면 남은 시간이 없다. 이것을 새 회차로 보면
    -- 만료 시각 없는 유령 항목이 남는다 (2026-10-24 수수께끼의 존재). 남은 시간 없이 다시 읽힌 지난 회차는 무시한다
    local prev = DB.gqPrevExpire[questID]
    if not timeLeft and ((e and e.expire and e.expire <= now) or (not e and prev and now - prev < GQ_EXPIRE_GRACE)) then
        return false
    end
    if e and e.expire and e.expire <= now then
        DB.gqPrevExpire[questID] = e.expire
        e = nil
    end
    e = e or {}
    e.name = title
    e.zone = zoneName
    e.mapID = mapID
    e.money = money
    e.cacheItem = cacheItem
    if timeLeft then
        e.expire = time() + timeLeft
    end
    e.seen = time()
    -- 이 퀘스트를 지도에서 본 캐릭터 (캐릭터마다 보이는 퀘스트가 다를 수 있다)
    if charKey then
        -- 만렙이 본 골드퀘인가 (부자되기 탭과 다음 추천은 이것만, QTR.SeenByTarget). 만렙이 한 번 보면 true로 남는다.
        --   만렙 아닌 캐릭터가 처음 본 것만 false. 다른 캐릭터가 본 기록이 있는 예전 항목(seenMax 없음)은 SeenByTarget이 정하게 둔다
        if QTR.IsMaxChar() then
            e.seenMax = true
        elseif e.seenMax == nil and not (e.seenBy and next(e.seenBy)) then
            e.seenMax = false
        end
        e.seenBy = e.seenBy or {}
        e.seenBy[charKey] = time()
        if e.hiddenFor then
            e.hiddenFor[charKey] = nil
        end
        if e.notGoldFor then
            e.notGoldFor[charKey] = nil -- 이 캐릭터에게도 골드 보상이 되었다
        end
    end
    DB.activeGQ[questID] = e
    return true
end

-- 만료 시각을 모르는 항목: 그 퀘스트를 지도에서 봤던 캐릭터가 모두 이제는 "안 보임"이면 이미 사라진 것이다
local function GoneForAllWhoSaw(e)
    if not (e.seenBy and next(e.seenBy)) then
        return false
    end
    for key in pairs(e.seenBy) do
        if not (e.hiddenFor and e.hiddenFor[key]) then
            return false
        end
    end
    return true
end

local function CleanupActiveGQ()
    local now = time()
    for questID, e in pairs(DB.activeGQ) do
        if e.cacheItem then
            -- 예전 버전이 골드퀘 목록에 넣어 둔 보관함 퀘스트(특별 과제)는 정점 보관함 묶음으로 옮겼으니 지운다
            DB.activeGQ[questID] = nil
        elseif e.expire and e.expire <= now then
            DB.gqPrevExpire[questID] = e.expire
            DB.activeGQ[questID] = nil
        elseif not e.expire and ((e.seen or 0) < now - 86400 or GoneForAllWhoSaw(e)) then
            DB.activeGQ[questID] = nil
        end
    end
end

-- 이번 회차의 시작 시각 (이 시각 이후의 완료만 이번 회차 완료로 본다)
local function GetGQInstanceStart(questID, e)
    local prev = DB.gqPrevExpire[questID]
    if prev and e.expire and prev < e.expire then
        return prev
    end
    -- 주간 퀘스트(필드 보스 등)는 주간 초기화 때 끝나고 일주일 동안 열려 있다:
    -- 만료 시각이 이번 주 초기화 시각과 맞으면(만료 시각은 남은 시간으로 계산해 몇 분 어긋날 수 있다) 이번 주 시작부터 센다
    local weekStart, weekEnd = GetWeekBounds()
    if e.expire and math.abs(e.expire - weekEnd) <= 30 * 60 then
        return weekStart
    end
    return (e.expire or time()) - GQ_MAX_DURATION
end

-- 캐릭터가 이번 회차에 완료했는지 (현재 캐릭터는 게임의 완료 표시도 함께 본다)
-- 반환: 완료 시각, 완료 표시만 있고 시각을 모르면 math.huge, 미완료면 nil
local function GetQuestDoneTime(key, questID, since)
    local t = DB.turnIns[key] and DB.turnIns[key][questID]
    if t and t >= since then
        return t
    end
    -- 리에드린 주간(QTR.SILVERMOON_NOFLAG_IDS)은 게임의 완료 표시를 믿지 않는다 (직접 본 완료 기록만)
    if QTR.SILVERMOON_NOFLAG_IDS[questID] then
        return nil
    end
    if key == charKey and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        return math.huge
    end
    -- 그 캐릭터로 접속했을 때 게임이 완료로 본 퀘스트 (QTR 완료 기록은 없음, 시각 모름): DB.flagDone[캐릭터][퀘스트] = 그렇게 본 시각
    local f = DB.flagDone and DB.flagDone[key] and DB.flagDone[key][questID]
    if f and f >= since then
        return math.huge
    end
    return nil
end

local function IsQuestDoneSince(key, questID, since)
    return GetQuestDoneTime(key, questID, since) ~= nil
end

-- 실버문 주간 퀘스트: 지금 캐릭터가 게임에서 완료로 보이는데 QTR 완료 기록이 없으면 완료(시각 모름)로 남긴다
--   (애드온을 넣기 전에 했거나, 다른 애드온 창에서 완료한 경우. 주간 퀘스트 완료 표시는 주간 초기화 때 풀린다)
function QTR.ScanWeeklyFlags()
    if not DB or not charKey or not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then
        return
    end
    local weekStart = GetWeekBounds()
    local now = time()
    for questID in pairs(QTR.SILVERMOON_WEEKLY_IDS) do
        local ok, done = false, false
        if not QTR.SILVERMOON_NOFLAG_IDS[questID] then -- 리에드린 주간은 완료 표시를 믿지 않는다 (SILVERMOON_WEEKLY noFlag)
            ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        end
        if ok and done then
            local t = DB.turnIns[charKey] and DB.turnIns[charKey][questID]
            local f = DB.flagDone[charKey] and DB.flagDone[charKey][questID]
            if not (t and t >= weekStart) and not (f and f >= weekStart) then
                DB.flagDone[charKey] = DB.flagDone[charKey] or {}
                DB.flagDone[charKey][questID] = now
            end
        end
    end
    -- 퀘스트 목록에 받아 둔 실버문 주간 퀘스트 (부자되기 탭 "수행중", 2026-11-01 사용자 요청)
    --   퀘스트 목록이 비어 있으면(접속 종료 중이거나 아직 못 읽음) 기록을 새로 쓰지 않는다
    --   (같은 날 접속 종료 때 썼더니 받아 둔 퀘스트가 없는 것으로 덮여 "미완료"로 보였다, 사용자 제보)
    local emptyLog = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() == 0
    if C_QuestLog.IsOnQuest and not emptyLog then
        local ids, prog = {}, {}
        for questID in pairs(QTR.SILVERMOON_WEEKLY_IDS) do
            local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
            if ok and on then
                ids[questID] = true
                prog[questID] = QTR.QuestProgress(questID) -- 진행도 (2026-11-01 사용자 요청: "수행중" 대신 "0/100")
            end
        end
        DB.weeklyOn[charKey] = { t = now, ids = ids, prog = prog }
    end
end

-- 받아 둔 퀘스트의 진행도: 아직 못 끝낸 첫 목표 (모두 끝냈으면 마지막 목표)
--   반환: { f = 채운 수, r = 필요 수 }, 진행 막대 목표면 { p = 퍼센트 }, 모르면 nil
function QTR.QuestProgress(questID)
    if not C_QuestLog.GetQuestObjectives then
        return nil
    end
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objs) ~= "table" or #objs == 0 then
        return nil
    end
    local o = objs[#objs]
    for _, v in ipairs(objs) do
        if not v.finished then
            o = v
            break
        end
    end
    if o.type == "progressbar" and GetQuestProgressBarPercent then
        local ok2, pct = pcall(GetQuestProgressBarPercent, questID)
        if ok2 and type(pct) == "number" then
            return { p = math.floor(pct) }
        end
    end
    if type(o.numFulfilled) == "number" and type(o.numRequired) == "number" and o.numRequired > 0 then
        return { f = o.numFulfilled, r = o.numRequired }
    end
    return nil
end

-- 실버문 주간 한 칸을 그 캐릭터가 이번 주에 받아 두었나 (그 캐릭터로 이번 주에 접속했을 때 퀘스트 목록에 있었으면 true)
--   다른 캐릭터는 마지막 접속 때 모습이다. 지난주에 본 것은 모른다고 본다
--   반환 둘째: 그때 본 진행도 (QTR.QuestProgress, 모르면 nil)
function QTR.WeeklyOnQuest(key, w, weekStart)
    local s = DB.weeklyOn and DB.weeklyOn[key]
    if not (s and s.ids and (s.t or 0) >= weekStart) then
        return false
    end
    for _, questID in ipairs(w.ids) do
        if s.ids[questID] then
            return true, s.prog and s.prog[questID]
        end
    end
    return false
end

-- 부자되기 탭 실버문 주간 줄의 캐릭터 상태 (미완료일 때): 받아 두었으면 노란 진행도 "0/100" (모르면 "수행중"), 정렬 순서 0
--   받지 않았으면 nil ("미완료")
function QTR.WeeklyState(key, w, weekStart)
    local on, prog = QTR.WeeklyOnQuest(key, w, weekStart)
    if not on then
        if QTR.WeeklyLastWeek(key, w, weekStart) then
            return L["|cff808080지난주 완료|r"], 2
        end
        return nil
    end
    if prog and prog.p then
        return "|cffffd100" .. prog.p .. "%|r", 0
    elseif prog and prog.f then
        return "|cffffd100" .. prog.f .. "/" .. prog.r .. "|r", 0
    end
    return L["|cffffd100수행중|r"], 0
end

-- 실버문 주간 한 칸(잘아타스 추적, 리에드린 주간)의 이번 주 완료 시각: 칸의 퀘스트 중 하나라도 완료했으면 그 시각
--   (시각을 모르면 math.huge), 미완료면 nil. 반환 둘째: 완료한 퀘스트 ID
function QTR.WeeklyDoneTime(key, w, weekStart)
    local best, bestID
    for _, questID in ipairs(w.ids) do
        local t = GetQuestDoneTime(key, questID, weekStart)
        if t and (not best or t < best) then
            best, bestID = t, questID
        end
    end
    return best, bestID
end

-- 한 번 하면 다음 주에는 받을 수 없는 칸(w.skipNext, 리에드린 주간)을 그 캐릭터가 지난주에 했나: 했으면 그 시각, 아니면 nil
--   이번 주에 했거나 받아 둔 캐릭터는 부르는 쪽이 먼저 거른다 (받아 두었으면 받을 수 있는 것이므로 그쪽이 우선)
--   기록: QTR 완료 기록(turnIns), 또는 최정상 보관함을 그 퀘스트 보상으로 받은 기록(cacheGets의 q.
--   실버문 주간 ID를 넣기(10-30) 전에 한 것은 이것만 남아 있다)
function QTR.WeeklyLastWeek(key, w, weekStart)
    if not w.skipNext then
        return nil
    end
    local from = weekStart - 7 * 86400
    local function inWeek(t)
        return t and t >= from and t < weekStart
    end
    local done = DB.turnIns[key]
    for _, questID in ipairs(w.ids) do
        if done and inWeek(done[questID]) then
            return done[questID]
        end
    end
    for _, g in ipairs(DB.cacheGets[key] or {}) do
        if g.id == QTR.SILVERMOON_CACHE and g.q and inWeek(g.t) then
            for _, questID in ipairs(w.ids) do
                if g.q == questID then
                    return g.t
                end
            end
        end
    end
    return nil
end

-- 지역별 골드 전역퀘 수집. 반환값: 지역 목록, 아직 불러오는 중인지
local function CollectGoldQuests()
    local zones = {}
    local loading = false
    local seen = {}
    local zoneLoaded = {}
    -- 지금 캐릭터의 지도에 뜬 보관함 퀘스트 (잠금 해제된 특별 과제). 골드퀘 탭은 이것만 보관함 묶음에 넣는다.
    local mapCaches = {}
    for _, zone in ipairs(GQ_ZONES) do
        local quests = C_TaskQuest.GetQuestsOnMap(zone.mapID) or {}
        local entry = { mapID = zone.mapID, name = GetZoneName(zone.mapID), quests = {}, money = 0 }
        if #quests > 0 then
            zoneLoaded[zone.mapID] = true
        end
        for _, v in ipairs(quests) do
            local questID = v.questID
            if questID and not seen[questID] and QTR.ZoneHasMap(zone, v.mapID) and C_QuestLog.IsWorldQuest(questID) then
                local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
                local hasReward = true
                if HaveQuestRewardData and not HaveQuestRewardData(questID) then
                    hasReward = false
                    if C_TaskQuest.RequestPreloadRewardData then
                        C_TaskQuest.RequestPreloadRewardData(questID)
                    end
                end
                if title == nil or not hasReward then
                    loading = true
                else
                    seen[questID] = true
                    local money = GetQuestLogRewardMoney(questID) or 0
                    local timeLeft = GetQuestTimeLeft(questID)
                    RememberQuestTitle(questID, title)
                    -- 보상이 정점 보관함이면 (해제된 특별 과제 등) 출처로 학습만 하고 골드퀘 목록에는 넣지 않는다
                    -- (1, 2번 탭 아래쪽 정점 보관함 묶음에서 보여준다)
                    local cacheItem = GetQuestLogCacheReward(questID)
                    -- 보관함을 주는 퀘스트(스토마리온 공격 등)의 남은 시간을 못 읽으면 주간 초기화까지로 본다
                    -- 이 어림값은 출처의 만료 시각(expireSeen, "퀘스트에서 직접 읽은 시각")으로 남기지 않는다 (2026-11-05 사용자 제보:
                    -- 주간 초기화를 넘겨 남는 대마법학자의 음료가 초기화 시각으로 저장되어, 초기화 뒤 끝난 특별 과제로 보고 숨겨졌다)
                    local readLeft = timeLeft
                    if cacheItem and not timeLeft then
                        local _, nextReset = GetWeekBounds()
                        timeLeft = nextReset - time()
                    end
                    -- 웨이포인트용 위치: 조회한 지역 지도(zone.mapID) 기준 좌표
                    local wp = (v.x and v.y and v.x > 0) and { zone.mapID, v.x, v.y } or nil
                    if cacheItem then
                        LearnQuestSource(questID, cacheItem, title, entry.name, "map", readLeft and (time() + readLeft))
                        mapCaches[questID] = true
                        if wp and DB.cacheSources["q" .. questID] then
                            DB.cacheSources["q" .. questID].wp = wp
                        end
                    end
                    local listed = money >= GOLD_THRESHOLD and cacheItem == nil
                    local name = title
                    if name:find(SPECIAL_TITLE_PREFIX, 1, true) == 1 then
                        name = strtrim(name:sub(#SPECIAL_TITLE_PREFIX + 1))
                    end
                    -- 계정 공용 목록 (부자되기 탭): 이 캐릭터가 이미 완료했어도 남긴다
                    if listed then
                        if RememberGoldQuest(questID, name, entry.name, zone.mapID, money, timeLeft, cacheItem) then
                            DB.activeGQ[questID].wp = wp or DB.activeGQ[questID].wp
                        end
                    elseif charKey and not cacheItem and DB.activeGQ[questID] then
                        -- 보상은 캐릭터마다 다를 수 있다 (장비가 약한 캐릭터는 같은 퀘스트가 장비, 금고 열쇠 등으로 나온다, 2026-10-25 확인).
                        -- 다른 캐릭터에게는 골드퀘인데 이 캐릭터에게는 골드가 아니면 "골드 아님"으로 기억한다 (골드로 보이면 RememberGoldQuest가 푼다)
                        local e = DB.activeGQ[questID]
                        e.notGoldFor = e.notGoldFor or {}
                        e.notGoldFor[charKey] = true
                    end
                    if listed and not C_QuestLog.IsQuestFlaggedCompleted(questID)
                        and not QTR.IsHiddenQuest(questID) then
                        -- 골드퀘 탭에 보이는 금액: 지금 캐릭터가 받을 금액 (전쟁 모드 보너스 포함)
                        local shownMoney = QTR.WithWarBonus(questID, money)
                        table.insert(entry.quests, {
                            id = questID,
                            name = name .. QTR.BanMark(questID),
                            title = name,
                            money = shownMoney,
                            cacheItem = cacheItem,
                            timeLeft = timeLeft,
                            wp = wp,
                        })
                        if not cacheItem then
                            entry.money = entry.money + shownMoney
                        end
                    end
                end
            end
        end
        -- 남은 시간이 적은 순 (모르는 시간은 맨 뒤)
        table.sort(entry.quests, function(a, b)
            local ta, tb = a.timeLeft or math.huge, b.timeLeft or math.huge
            if ta ~= tb then
                return ta < tb
            end
            return a.name < b.name
        end)
        entry.minTime = entry.quests[1] and entry.quests[1].timeLeft or math.huge
        local metaInfo
        entry.metaDone, entry.metaProgress, metaInfo = GetZoneMetaState(zone, quests)
        if entry.metaDone == true then
            entry.metaQuest = metaInfo
        elseif entry.metaDone == false then
            entry.metaPOI = metaInfo
        end
        -- 이 캐릭터의 특별 과제 잠김 상태를 남긴다 (부자되기 탭 캐릭터별 "잠김(n/3)", 2026-11-01 사용자 요청)
        --   그 지역 퀘스트 목록을 받았을 때만 (덜 받은 목록에서는 해금한 특별 과제가 안 보여 잠김으로 잘못 읽을 수 있다)
        if entry.metaDone ~= nil and charKey and zoneLoaded[zone.mapID] then
            DB.saLock[charKey] = DB.saLock[charKey] or {}
            DB.saLock[charKey][zone.mapID] = { t = time(), open = entry.metaDone, p = entry.metaProgress,
                q = entry.metaDone and metaInfo or QTR.ZoneSpecialID(zone.mapID) }
        end
        table.insert(zones, entry)
    end
    -- 다른 캐릭터로 본 퀘스트인데 이 캐릭터의 지도에는 없고 완료하지도 않았다면, 이 캐릭터에게는 안 보이는 퀘스트다
    -- (퀘스트 정보를 다 받았고 그 지역 목록이 비어 있지 않을 때만 판단한다)
    if not loading and charKey then
        local now = time()
        for questID, e in pairs(DB.activeGQ) do
            if zoneLoaded[e.mapID] and not seen[questID] and (not e.expire or e.expire > now)
                and not C_QuestLog.IsQuestFlaggedCompleted(questID) then
                e.hiddenFor = e.hiddenFor or {}
                e.hiddenFor[charKey] = true
            end
        end
    end
    -- 지역 정렬: 가장 빨리 끝나는 퀘스트가 있는 지역부터, 골드퀘가 없는 지역은 맨 뒤
    table.sort(zones, function(a, b)
        local ha, hb = #a.quests > 0, #b.quests > 0
        if ha ~= hb then
            return ha
        end
        if a.minTime ~= b.minTime then
            return a.minTime < b.minTime
        end
        return a.mapID < b.mapID
    end)
    -- 다른 캐릭터 추천을 이 캐릭터가 실제로 할 수 있는 것과 맞추기 위해 기억한다 (2026-10-25 격냥패딩 사례)
    if not loading and charKey then
        local now = time()
        -- 1) 게임이 완료로 보는데 QTR 완료 기록이 없는 퀘스트: 완료(시각 모름)로 남긴다
        for questID, e in pairs(DB.activeGQ) do
            if (not e.expire or e.expire > now) and C_QuestLog.IsQuestFlaggedCompleted(questID) then
                local since = GetGQInstanceStart(questID, e)
                local t = DB.turnIns[charKey] and DB.turnIns[charKey][questID]
                local f = DB.flagDone[charKey] and DB.flagDone[charKey][questID]
                if not (t and t >= since) and not (f and f >= since) then
                    DB.flagDone[charKey] = DB.flagDone[charKey] or {}
                    DB.flagDone[charKey][questID] = now
                end
            end
        end
    end
    -- 아직 불러오는 중이면 이번에 못 읽은 것도 있으니 직전 결과를 함께 남긴다
    if loading and QTR.mapCaches then
        for id in pairs(QTR.mapCaches) do
            mapCaches[id] = true
        end
    end
    QTR.mapCaches = mapCaches
    return zones, loading
end

-- 화면과 상관없이 지도를 훑어 계정 공용 목록과 보관함 출처를 갱신한다
-- 지도 읽기는 몇 초에 한 번만 한다 (퀘스트 로그 이벤트가 자주 와서 화면 갱신이 잦기 때문)
-- QTR.forceScan을 켜면 다음 갱신 때 바로 다시 읽는다 (퀘스트 완료, 탭 전환, 제외 목록 변경)
local SCAN_INTERVAL = 5
local lastScanAt, lastZones, lastLoading

local function CollectGoldQuestsCached()
    local now = GetTime()
    if QTR.forceScan or not lastZones or lastLoading or now - lastScanAt >= SCAN_INTERVAL then
        QTR.forceScan = false
        lastZones, lastLoading = CollectGoldQuests()
        lastScanAt = now
    end
    return lastZones, lastLoading
end

local function ScanQuestBoard()
    if not DB or not charKey then
        return
    end
    CollectGoldQuestsCached()
    CleanupActiveGQ()
end

-- 특별 과제 표시 (HDT와 같은 방식): 수행가능 주황, 잠김(진행도) 회색
local function FormatMeta(done, progress)
    local icon = "|T" .. META_ICON .. ":0:0:0:0|t "
    if done == true then
        return icon .. L["|cffff8000수행가능|r"]
    elseif done == false then
        return icon .. L["|cffaaaaaa잠김(%d/%d)|r"]:format(progress, META_TOTAL)
    end
    return ""
end

local gq = {}

gq.summary = CreateText(gqPanel, 20, -6, "GameFontNormal")
gq.sub = CreateText(gqPanel, 20, -26, "GameFontHighlightSmall")
gq.list = CreateList(gqPanel, -48)

function QTR:UpdateGoldQuests()
    local zones, loading = CollectGoldQuestsCached()

    local total, totalMoney = 0, 0
    local entries = {}
    for _, z in ipairs(zones) do
        local count = #z.quests
        total = total + count
        totalMoney = totalMoney + z.money
        -- 골드퀘도 특별 과제도 없는 지역은 보여주지 않는다
        if count > 0 or z.metaDone ~= nil then
            -- 골드퀘 개수는 따로 쓰지 않는다 (지역 아래 줄 수로 보인다)
            local header = {
                Cell("|cff00ccff" .. z.name .. "|r", COL.name),
                Cell(FormatMeta(z.metaDone, z.metaProgress), COL.mid),
                -- 특별 과제가 있으면 지역 줄에 마우스를 올렸을 때 그 툴팁을 보여준다
                --   수행 가능: 퀘스트 툴팁 / 잠김: 지도의 특별 과제 표시 툴팁 (보상도 게임 툴팁에 들어 있다)
                tipQuest = z.metaQuest,
            }
            if z.metaPOI then
                header.tipPOI = { info = z.metaPOI, mapID = z.mapID, progress = z.metaProgress, total = META_TOTAL }
            end
            -- 지역 줄 오른쪽(골드 합계)은 읽기 쉽도록 비워 둔다
            table.insert(entries, header)
        end
        for _, q in ipairs(z.quests) do
            table.insert(entries, {
                Cell("|cffffffff" .. q.name .. "|r", COL.gqQuest),
                Cell(FormatTimeLeft(q.timeLeft), COL.gqTime, "RIGHT"),
                Cell(q.cacheItem and ("|T" .. GetItemIconSafe(q.cacheItem) .. ":0|t") or FormatSubGold(q.money), COL.gold, "RIGHT"),
                tipQuest = q.id,
                -- 클릭: 그 퀘스트 위치에 웨이포인트 (내비게이션 중에는 찍지 않는다)
                onClick = function() QTR.TabWaypoint(q.id, q.title, q.wp, z.name) end,
            })
        end
    end
    -- 이번 주 정점 보관함(특별 과제 포함): 현재 캐릭터가 받았는지
    -- 보여줄 출처도, 가방에 안 연 보관함도 없으면 묶음 자체를 그리지 않는다
    local now = time()
    local weekStart, nextReset = GetWeekBounds()
    -- 이미 받고 열기까지 한 출처는 할 일이 없으니 뺀다. 받았지만 안 연 것은 "미개봉"으로 남긴다.
    local cacheRows = {}
    local shownUnopened, countedItems = 0, {}
    for _, item in ipairs(QTR.GetSortedSources(weekStart)) do
        local done = QTR.IsSourceDoneBy(charKey, item.src, weekStart)
        local inBag = GetItemCountSafe(item.src.itemID)
        -- 특별 과제는 이 캐릭터가 잠금 해제해서 지도에 떠 있을 때만 보여준다 (다른 캐릭터가 해제한 것은 빼고)
        local locked = QTR.IsMapSource(item.src) and not done
            and not (QTR.mapCaches and QTR.mapCaches[item.src.questID])
        if (item.thisWeek or done) and not (done and inBag == 0) and not locked then
            local status = L["|cffff4444미완료|r"]
            if done then
                status = L["|cffffd100미개봉 %d|r"]:format(inBag)
                if not countedItems[item.src.itemID] then
                    countedItems[item.src.itemID] = true
                    shownUnopened = shownUnopened + inBag
                end
            end
            table.insert(cacheRows, {
                Cell("|cffffffff" .. QTR.SourceLabel(item.src) .. "|r", COL.cacheName),
                Cell(QTR.SourceTimeText(item.src, nextReset), COL.cacheTime, "RIGHT"),
                Cell(status, COL.gold, "RIGHT"),
                tipQuest = item.src.kind == "quest" and item.src.questID or nil,
                tipItem = item.src.kind == "item" and item.src.itemID or nil,
                -- 지도에서 위치를 본 출처(특별 과제 등)만 클릭으로 웨이포인트
                onClick = item.src.wp and function()
                    QTR.TabWaypoint(item.src.questID, QTR.GetSourceName(item.src), item.src.wp, item.src.zone)
                end or nil,
            })
        end
    end
    -- 위 줄에서 "미개봉"으로 이미 보인 것 말고 남은 보관함 (특별 과제 보상 등)
    local unopened = GetCacheInBags() - shownUnopened
    if unopened > 0 then
        -- 다른 칸이 없는 줄이라 목록 끝까지 넓게 쓴다 (글자가 잘리지 않게)
        table.insert(cacheRows, { Cell(L["|cffffd100가방에 열지 않은 보관함 %d개|r"]:format(unopened), { x = COL.gqQuest.x, w = LIST_WIDTH - COL.gqQuest.x }) })
    end
    if #cacheRows > 0 then
        -- 남은 시간은 줄마다 따로 보여주므로 묶음 제목에는 이름만 둔다
        table.insert(entries, "")
        table.insert(entries, { Cell(CACHE_LABEL, COL.name) })
        for _, row in ipairs(cacheRows) do
            table.insert(entries, row)
        end
    end

    if loading then
        table.insert(entries, "")
        table.insert(entries, L["|cff808080퀘스트 정보를 불러오는 중...|r"])
    end
    RenderList(gq.list, entries)

    gq.summary:SetText(string.format(L["수행 가능한 골드퀘 %d개 / %s"], total, FormatGold(totalMoney)))
    -- 전쟁 모드를 켰으면 금액에 보너스가 들어갔다는 것을 알린다
    local war = QTR.WarBonusPct()
    gq.sub:SetText(L["|cffaaaaaa%s 기준, 남은 시간이 적은 순|r"]:format(UnitName("player") or "")
        .. (war > 0 and L[" |cffff8000전쟁 모드 +%d%% 반영|r"]:format(war) or ""))

    -- 아직 못 받은 퀘스트 정보가 있으면 잠시 뒤 다시 읽는다
    if loading and not gqRetryPending and gqRetryCount < GQ_RETRY_MAX then
        gqRetryPending = true
        gqRetryCount = gqRetryCount + 1
        C_Timer.After(GQ_RETRY_SECONDS, function()
            gqRetryPending = false
            if currentTab == "gq" then
                QTR:Refresh()
            end
        end)
    elseif not loading then
        gqRetryCount = 0
    end
end

-- 탭이 열려 있는 동안 남은 시간을 주기적으로 갱신
gqPanel:SetScript("OnShow", function(self)
    self.elapsed = 0
    gqRetryCount = 0
end)
gqPanel:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= GQ_REFRESH_SECONDS then
        self.elapsed = 0
        QTR:Refresh()
    end
end)

-- 지역 퀘스트 정보를 미리 요청해 둔다 (처음 탭을 열 때 빈 목록 방지)
local function PreloadGoldQuests()
    for _, zone in ipairs(GQ_ZONES) do
        C_TaskQuest.GetQuestsOnMap(zone.mapID)
    end
end

-------------------------------------------------------------------------------
-- 내비게이션: 지금 캐릭터가 할 수 있는 골드퀘와 (잠금 해제된) 보관함 특별 과제를
-- 가까운 순서로 이어 TomTom 웨이포인트로 등록한다. 퀘스트를 완료하면 다음 목적지로 넘어간다.
-- TomTom이 없으면 게임 기본 웨이포인트로 한 곳씩 안내한다 (완료할 때마다 다음 곳으로 옮긴다).
-- 이동 비용: 같은 대륙은 직선 거리(야드), 포탈은 "포탈까지 거리 + 포탈 비용 + 도착점에서 거리".
--   포탈을 여러 번 갈아타는 길도 계산한다(최단 경로). 공허폭풍, 하란다르는 포탈로만 갈 수 있다.
-- 순서: 지금 위치에서 가장 비용이 적은 곳부터 고른 뒤(최근접 이웃), 구간을 뒤집어 보며 줄인다(2-opt).
-- 포탈을 거쳐야 하는 구간은 그 앞에 포탈 위치 웨이포인트를 넣는다. 포탈을 타서 도착점에 서면 다음으로 넘어간다.
-- 경로에 없는 순간이동(귀환석, 다른 포탈 등)을 하면 지금 위치에서 남은 경로를 다시 짠다.
-------------------------------------------------------------------------------
QTR.SetupRoute = function()
    local FAR = 1e9
    local JUMP = 400        -- 1초 사이에 이보다 멀리(또는 다른 대륙으로) 옮겨졌으면 순간이동으로 본다
    -- 이동 시간 어림 (2026-10-23 내비게이션 기록 33구간으로 맞춘 값)
    --   평균 비행 속도 약 56야드/초, 퀘스트 처리 시간은 퀘스트마다 26~217초 (평균 약 110초),
    --   포탈은 출발점에 도착한 뒤 반대편에 서기까지 약 25초 (로딩 화면 포함)
    local NAV_SPEED = 56     -- 평균 이동 속도 (야드/초)
    local NAV_HANDLE = 110   -- 목적지 하나에서 퀘스트를 하는 데 드는 시간 (초)
    local PORTAL_COST = 25 * NAV_SPEED -- 포탈 한 번 타는 비용 (약 25초를 야드로 환산, 1400야드)
    local NAV_MARGIN = 60    -- 만료 이 시간(초) 전에는 도착해야 한다
    local NAV_URGENT = 1800  -- 남은 시간이 이보다 적으면 내비게이션 창에 주황색으로 표시 (30분)

    -- 포탈 좌표 (2026-10-21 /qtr pos로 직접 측정)
    --   from: 포탈 위치 { 지도 ID, x, y }, to: 포탈을 타면 서게 되는 곳
    --   하란다르 포탈은 하위 지도 "소굴"(2576) 기준 좌표다
    local PORTALS = {
        { name = L["공허폭풍행"], zone = L["실버문"], from = { 2393, 0.353185, 0.661854 }, to = { 2405, 0.516377, 0.701999 } },
        { name = L["실버문행"], zone = L["공허폭풍"], from = { 2405, 0.515616, 0.702862 }, to = { 2393, 0.35296, 0.652279 } },
        { name = L["하란다르행"], zone = L["실버문"], from = { 2393, 0.369315, 0.680974 }, to = { 2576, 0.628871, 0.704452 } },
        { name = L["실버문행"], zone = L["하란다르"], from = { 2576, 0.645832, 0.709694 }, to = { 2393, 0.365707, 0.688007 } },
        { name = L["하란다르행"], zone = L["공허폭풍"], from = { 2405, 0.51709, 0.703845 }, to = { 2576, 0.628871, 0.704452 } },
        { name = L["공허폭풍행"], zone = L["하란다르"], from = { 2576, 0.617129, 0.734153 }, to = { 2405, 0.516377, 0.701999 } },
        -- 실버문 야외 포탈로 아스탈로르의 성소에 들어간 뒤, 성소 안 포탈로 똬리의 섬에 간다 (돌아오면 성소 안에 선다)
        --   표시는 "똬리의 섬행 포탈 (아스탈로르의 성소)" (실버문은 붙이지 않는다)
        { name = L["똬리의 섬행"], zone = L["아스탈로르의 성소"],
            from = { 2393, 0.557871, 0.651887 }, to = { 2512, 0.582207, 0.484791 } },
        { name = L["실버문행"], zone = L["똬리의 섬"], from = { 2512, 0.58172, 0.484622 }, to = { 2393, 0.567691, 0.671426 } },
    }

    -- 경로 안내 이름 "하란다르행 포탈 (실버문)". 쌍점을 쓰지 않는다 (채팅 "다음 목적지: ..." 뒤에 붙어 겹치지 않게)
    local function PortalLabel(i)
        local pt = PORTALS[i]
        return L["%s 포탈 (%s)"]:format(pt.name, pt.zone .. (pt.note and (", " .. pt.note) or ""))
    end

    local function WorldPos(mapID, x, y)
        if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then
            return nil
        end
        local ok, continentID, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
        if not (ok and continentID and pos) then
            return nil
        end
        return { c = continentID, x = pos.x, y = pos.y }
    end

    local function Dist(a, b)
        if not (a and b) then
            return FAR / 10 -- 위치를 모르면 멀리 있는 것으로 본다
        end
        if a.c ~= b.c then
            return FAR
        end
        local dx, dy = a.x - b.x, a.y - b.y
        return math.sqrt(dx * dx + dy * dy)
    end

    -- 포탈의 월드 좌표 (한 번 계산해 두고 쓴다. 아직 못 읽으면 다음에 다시 계산)
    local portalPos
    local function PortalPositions()
        if portalPos then
            return portalPos
        end
        local list, any = {}, false
        for i, pt in ipairs(PORTALS) do
            local f = WorldPos(pt.from[1], pt.from[2], pt.from[3])
            local t = WorldPos(pt.to[1], pt.to[2], pt.to[3])
            if f and t then
                list[i] = { from = f, to = t }
                any = true
            end
        end
        if any then
            portalPos = list
        end
        return list
    end

    -- 마법사 실버문 순간이동 (2단계): 대기시간이 없어 "어디서든 탈 수 있는 포탈"로 본다. 쓸 수 있으면 RouteStart가 채운다
    --   { spell = 주문 ID, pos = 내리는 곳 월드 좌표 }. 경로의 포탈 목록에는 "mage"로 들어간다
    local mageTele
    local TELE_COST = 20 * NAV_SPEED -- 순간이동 한 번 비용 (시전 10초 + 로딩 어림 10초, 귀환석과 같은 어림)
    -- 귀환형 이동(귀환석 등)은 이만큼(15초) 이상 줄어들 때만 경로에 넣는다. 귀환석 비용 어림값의 오차(5~10초)를 넘는 확실한 이득만 넣는다
    -- (처음 1분이었으나 하란다르에서 약 30초 빠른 경우도 빠져서 2026-10-24 사용자 결정으로 낮춤)
    local HEARTH_MIN_SAVE = 15 * NAV_SPEED

    -- a에서 b까지 이동 비용과 거쳐 갈 포탈 번호 목록 (포탈을 0번 이상 갈아타는 최단 경로, 다익스트라)
    -- 지점 1 = 출발점(a), 그 밖의 지점 = 각 포탈의 도착점. 어느 지점에서든 b로 날아가거나 다른 포탈을 탄다.
    -- 마법사 순간이동을 쓸 수 있으면 그 도착점도 지점으로 넣는다 (어디서든 TELE_COST, 목록에는 "mage")
    local function TravelCost(a, b)
        if not (a and b) then
            return FAR / 10, {}
        end
        local pp = PortalPositions()
        local nodes, portalOf = { a }, {}
        for i in pairs(pp) do
            table.insert(nodes, pp[i].to)
            portalOf[#nodes] = i
        end
        local teleNodes = {}
        if mageTele and mageTele.pos then
            table.insert(nodes, mageTele.pos)
            teleNodes[#nodes] = true
            portalOf[#nodes] = "mage"
        end
        -- 하라니르 뿌리걸음 (2026-11-08): 쿨타임이 없어 마법사 순간이동처럼 넣는다 (QTR.rootTele, TV.RefreshRoot가 채운다).
        --   하란다르 안 세계수 뿌리 가까이에서 쓰면 그 세계수(다른 대륙)로 가 버리므로 출발점이 뿌리 가까이면 넣지 않는다
        local root = QTR.rootTele
        if root and root.pos then
            local nearRoot = false
            for _, r in ipairs(root.roots) do
                if a.c == r.c and Dist(a, r) < root.near then
                    nearRoot = true
                end
            end
            if not nearRoot then
                table.insert(nodes, root.pos)
                teleNodes[#nodes] = true
                portalOf[#nodes] = "root"
            end
        end
        local dist, prev, done = {}, {}, {}
        for k = 1, #nodes do
            dist[k] = math.huge
        end
        dist[1] = 0
        for k in pairs(teleNodes) do
            -- 순간이동은 어디서 쓰든 비용이 같으니 출발점에서 바로 쓰는 것이 가장 싸다
            -- 뿌리걸음이 "귀환" 상태면 먼저 귀환하고 다시 써야 요람으로 가므로 두 번 값 (TV.RefreshRoot의 twice)
            dist[k], prev[k] = TELE_COST * ((portalOf[k] == "root" and root.twice) and 2 or 1), 1
        end
        for _ = 1, #nodes do
            local u, best = nil, math.huge
            for k = 1, #nodes do
                if not done[k] and dist[k] < best then
                    u, best = k, dist[k]
                end
            end
            if not u then
                break
            end
            done[u] = true
            for k = 2, #nodes do
                if not done[k] and not teleNodes[k] then
                    local d = dist[u] + Dist(nodes[u], pp[portalOf[k]].from) + PORTAL_COST
                    if d < dist[k] then
                        dist[k], prev[k] = d, u
                    end
                end
            end
        end
        local bestCost, bestNode = Dist(a, b), 1
        for k = 2, #nodes do
            local c = dist[k] + Dist(nodes[k], b)
            if c < bestCost then
                bestCost, bestNode = c, k
            end
        end
        local path, k = {}, bestNode
        while k and k ~= 1 do
            table.insert(path, 1, portalOf[k])
            k = prev[k]
        end
        return bestCost, path
    end

    -- 지금 캐릭터 기준 경로에 넣을 곳: { questID, title, wp, zone, pos }
    -- 이번 내비게이션에서 이미 완료한 퀘스트(routeDone)는 게임의 완료 표시가 늦게 바뀌어도 빼 둔다
    local function CollectRoutePoints()
        local points = {}
        local done = QTR.routeDone or {}
        local skip = QTR.routeSkip or {} -- "이번만은 하고 싶지 않습니다"로 뺀 퀘스트 (이번 내비게이션 동안)
        local zones = CollectGoldQuestsCached()
        for _, z in ipairs(zones) do
            for _, q in ipairs(z.quests) do
                if q.wp and not done[q.id] and not DB.settings.bannedQuests[q.id] and not skip[q.id] then
                    -- expire: 만료 시각 (계정 공용 목록에 남긴 시각, 없으면 남은 시간으로 계산). 모르면 nil
                    local a = DB.activeGQ[q.id]
                    local expire = (a and a.expire) or (q.timeLeft and (time() + q.timeLeft)) or nil
                    table.insert(points, { questID = q.id, title = q.title, wp = q.wp, zone = z.name, money = q.money,
                        expire = expire, zoneMap = z.mapID })
                end
            end
        end
        -- 이 캐릭터 지도에 떠 있는(잠금 해제된) 보관함 퀘스트 중 아직 안 한 것
        local weekStart = GetWeekBounds()
        for _, src in pairs(DB.cacheSources) do
            if src.kind == "quest" and src.wp and QTR.mapCaches and QTR.mapCaches[src.questID]
                and not done[src.questID] and not DB.settings.bannedQuests[src.questID] and not skip[src.questID]
                and not QTR.IsSourceDoneBy(charKey, src, weekStart) then
                local left = QTR.GetSpecialTimeLeft(src.questID)
                table.insert(points, { questID = src.questID, title = QTR.GetSourceName(src), wp = src.wp, zone = src.zone,
                    cache = true, cacheItem = src.itemID, expire = left and (time() + left) or src.expire })
            end
        end
        -- 퀘스트 목록에 받아 둔 특별 과제도 열린 것으로 본다 (2026-11-08 사용자 제보, 압구정: 해금돼서 퀘스트 목록에 있는데
        --   내비게이션은 계속 "해금 예정". 지도 목록에는 보상 정보를 불러오기 전까지 안 나올 수 있다)
        --   위치: 배운 위치, 없으면 지금 경로의 해금 예정 목적지 위치 (잠긴 아이콘 위치). 둘 다 없으면 넣지 못한다
        local added = {}
        for _, p in ipairs(points) do
            added[p.questID] = true
        end
        for qid, sa in pairs(QTR.SPECIAL_ASSIGNMENTS) do
            if not added[qid] and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(qid)
                and not done[qid] and not skip[qid] and not DB.settings.bannedQuests[qid] then
                local src = DB.cacheSources["q" .. qid]
                local wp = src and src.wp
                if not wp then
                    for _, r in ipairs(QTR.route or {}) do
                        if r.questID == qid and r.wp then
                            wp = r.wp
                        end
                    end
                end
                if wp and not (src and QTR.IsSourceDoneBy(charKey, src, weekStart)) then
                    local left = QTR.GetSpecialTimeLeft(qid)
                    table.insert(points, { questID = qid, title = (src and QTR.GetSourceName(src)) or QTR.LiveQuestTitle(qid) or L["특별 과제"],
                        wp = wp, zone = GetZoneName(sa.mapID), cache = true, cacheItem = src and src.itemID,
                        expire = left and (time() + left) or (src and src.expire) })
                    added[qid] = true
                end
            end
        end
        -- 아직 잠긴 특별 과제: 그 지역 전역퀘를 남은 수(need)만큼 하면 열리므로 "해금 예정" 목적지로 넣는다
        --   경로 계산 조건: 같은 지역 골드퀘를 need개 한 뒤에만 갈 수 있다 (그래서 그 지역 퀘스트를 특별 과제 쪽에서 끝내게 된다)
        --   경로의 그 지역 골드퀘가 need개보다 적으면 넣지 않는다 (골드퀘만으로는 열 수 없다)
        --   위치: 같은 특별 과제를 전에 본 실제 위치가 있으면 그것, 없으면 지도의 잠긴 특별 과제 아이콘 위치
        for _, z in ipairs(zones) do
            local info = (z.metaDone == false) and z.metaPOI or nil
            local need = info and (META_TOTAL - (z.metaProgress or 0))
            if info and need and need > 0 then
                local count = 0
                for _, p in ipairs(points) do
                    if p.zoneMap == z.mapID then
                        count = count + 1
                    end
                end
                if count >= need then
                    -- 이번 주 이 지역 특별 과제 (특별 과제 ID 표에서 남은 시간이 있는 것)
                    local qid, left
                    for id, sa in pairs(QTR.SPECIAL_ASSIGNMENTS) do
                        local l = (sa.mapID == z.mapID) and QTR.GetSpecialTimeLeft(id)
                        if l then
                            qid, left = id, l
                            break
                        end
                    end
                    local src = qid and DB.cacheSources["q" .. qid]
                    local blocked = qid and (done[qid] or skip[qid] or DB.settings.bannedQuests[qid] or added[qid] -- 이미 열린 것으로 넣음
                        or (src and QTR.IsSourceDoneBy(charKey, src, weekStart)))
                    if not blocked then
                        local wp = src and src.wp
                        if not wp then
                            local ok, x, y = pcall(function() return info.position.x, info.position.y end)
                            if ok and type(x) == "number" and type(y) == "number" and info.qtrMapID then
                                wp = { info.qtrMapID, x, y }
                            end
                        end
                        local title = src and QTR.GetSourceName(src)
                        if not title then
                            local ok, name = pcall(function() return tostring(info.name or L["특별 과제"]) end)
                            title = ok and name or L["특별 과제"]
                            if title:find(SPECIAL_TITLE_PREFIX, 1, true) == 1 then
                                title = strtrim(title:sub(#SPECIAL_TITLE_PREFIX + 1))
                            end
                        end
                        if wp then
                            table.insert(points, { questID = qid or ("poi" .. tostring(info.areaPoiID)), locked = true,
                                need = need, zoneMap = z.mapID, title = title, wp = wp, zone = z.name,
                                cache = true, cacheItem = src and src.itemID, expire = left and (time() + left) })
                        end
                    end
                end
            end
        end
        for _, p in ipairs(points) do
            p.pos = WorldPos(p.wp[1], p.wp[2], p.wp[3])
        end
        return points
    end

    local function PlayerPos()
        local mapID = C_Map.GetBestMapForUnit("player")
        local p = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
        if not p then
            return nil
        end
        local x, y = p.x, p.y
        if p.GetXY then
            x, y = p:GetXY()
        end
        return x and WorldPos(mapID, x, y)
    end

    -- 시작점(start)에서 출발하는 열린 경로의 순서를 정한다. 각 지점에 그 앞에서 거칠 포탈 목록(portals)을 붙인다.
    -- firstIdx: 사용자가 "이 퀘스트 먼저"로 고른 지점 번호 (있으면 항상 첫 번째)
    -- lastSet: 사용자가 "마지막에"로 고른 지점 번호들 { [번호] = true } (나머지를 다 돈 뒤 그 지점들끼리 가까운 순서로)
    -- recalls: 귀환형 이동 목록 { { key, dest, cost, tokens }, ... } (귀환석, 영혼의 귀환, 아르칸티나 열쇠. 없으면 nil)
    --   있으면 순서의 비용을 "구간 몇 개를 귀환형 이동으로 바꿨을 때"로 잰다. 그래서 귀환석을 타기 좋은 자리가 생기도록
    --   순서 자체를 바꿀 수 있다 (2026-10-25 Blured: "줄아만 > 귀환석 > 똬리의 섬"이 더 빠를 것 같다)
    -- 반환: 순서대로 놓은 지점 목록, 만료 때문에 앞으로 당긴 지점 목록, 그 순서에서 쓴다고 본 귀환형 이동 횟수 { [key] = n }
    local function OrderPoints(points, start, firstIdx, lastSet, recalls)
        lastSet = lastSet or {}
        local n = #points
        local function posOf(i)
            if i == 0 then
                return start
            end
            return points[i].pos
        end
        -- 비용표 (포탈은 방향마다 비용이 다를 수 있다): cost[i][j], via[i][j] (0 = 출발점)
        local cost, via = {}, {}
        for i = 0, n do
            cost[i], via[i] = {}, {}
            for j = 1, n do
                if i ~= j then
                    cost[i][j], via[i][j] = TravelCost(posOf(i), posOf(j))
                end
            end
        end
        local minPos = firstIdx and 2 or 1 -- 순서를 바꿔도 되는 첫 자리
        -- 해금 예정 특별 과제(locked): 같은 지역 골드퀘(zoneMap)를 need개 한 뒤에만 갈 수 있다
        local function Valid(o)
            local cnt = {}
            for _, j in ipairs(o) do
                local p = points[j]
                if p.locked then
                    if (cnt[p.zoneMap] or 0) < p.need then
                        return false
                    end
                elseif p.zoneMap then
                    cnt[p.zoneMap] = (cnt[p.zoneMap] or 0) + 1
                end
            end
            return true
        end
        -- 최근접 이웃 (고른 지점이 있으면 거기서 시작). "마지막에" 지점은 맨 뒤에 따로 붙인다
        local order, used, cur = {}, {}, 0
        local lastCount = 0
        for j in pairs(lastSet) do
            used[j] = true
            lastCount = lastCount + 1
        end
        local zoneDone = {} -- 지금까지 순서에 넣은 지역별 골드퀘 수 (해금 예정 특별 과제 조건)
        local function Take(j)
            used[j] = true
            table.insert(order, j)
            cur = j
            local p = points[j]
            if p.zoneMap and not p.locked then
                zoneDone[p.zoneMap] = (zoneDone[p.zoneMap] or 0) + 1
            end
        end
        if firstIdx then
            Take(firstIdx)
        end
        for _ = #order + 1, n - lastCount do
            local best, bestC
            for j = 1, n do
                local p = points[j]
                local open = not p.locked or (zoneDone[p.zoneMap] or 0) >= p.need
                if not used[j] and open and (not bestC or cost[cur][j] < bestC) then
                    best, bestC = j, cost[cur][j]
                end
            end
            if not best then
                -- 조건을 만족하는 곳이 없으면 (예상 밖) 남은 곳 아무 데나
                for j = 1, n do
                    if not used[j] then
                        best = j
                        break
                    end
                end
            end
            Take(best)
        end
        -- 귀환형 이동으로 j에 가는 비용: rc[r][j] = 귀환 도착점에서 j까지 + 귀환 비용
        local rc = {}
        for r, m in ipairs(recalls or {}) do
            rc[r] = {}
            for j = 1, n do
                rc[r][j] = TravelCost(m.dest, posOf(j)) + m.cost
            end
        end
        -- 순서 o의 비용. 귀환형 이동을 볼 때(rcOn)는 HEARTH_MIN_SAVE 이상 줄어드는 구간을 줄어드는 양이 큰 것부터
        -- 이동마다 tokens 번까지 바꾼다 (한 구간에는 하나만). used가 있으면 바꾼 횟수를 [key]별로 적어 준다
        -- 먼저 귀환형 이동 없이 다듬고, 그 순서에서 시작해 귀환형 이동을 넣은 비용으로 한 번 더 다듬는다
        -- (나아질 때만 바꾸므로 1단계처럼 순서를 먼저 정하고 귀환석을 끼우는 것보다 나빠지지 않는다)
        local rcOn = false
        local function Total(o, used)
            local sum, prev = 0, 0
            local legs = {}
            for idx, j in ipairs(o) do
                legs[idx] = cost[prev][j]
                sum = sum + legs[idx]
                prev = j
            end
            if not rcOn or #rc == 0 then
                return sum
            end
            local left, taken = {}, {}
            for r, m in ipairs(recalls) do
                left[r] = m.tokens or 1
            end
            while true do
                local bestSave, bestIdx, bestR = HEARTH_MIN_SAVE, nil, nil
                for idx, j in ipairs(o) do
                    if not taken[idx] then
                        for r = 1, #rc do
                            if left[r] > 0 then
                                local save = legs[idx] - rc[r][j]
                                -- 수단마다 넣는 기준 (minSave, 없으면 15초): 쐐기 포탈은 45초
                                if save >= (recalls[r].minSave or HEARTH_MIN_SAVE) and (not bestIdx or save >= bestSave) then
                                    bestSave, bestIdx, bestR = save, idx, r
                                end
                            end
                        end
                    end
                end
                if not bestIdx then
                    break
                end
                taken[bestIdx] = true
                left[bestR] = left[bestR] - 1
                sum = sum - bestSave
                if used then
                    local key = recalls[bestR].key
                    used[key] = (used[key] or 0) + 1
                end
            end
            return sum
        end
        local m = #order -- "마지막에" 지점을 뺀 개수 (2-opt, 구간 옮기기, 만료 고려는 이 안에서만)
        local bestTotal = Total(order)
        local function TwoOpt()
            for _ = 1, 30 do
                local improved = false
                for i = minPos, m - 1 do
                    for k = i + 1, m do
                        local cand = {}
                        for t = 1, m do
                            if t >= i and t <= k then
                                cand[t] = order[k - (t - i)]
                            else
                                cand[t] = order[t]
                            end
                        end
                        local total = Total(cand)
                        if total < bestTotal - 0.01 and Valid(cand) then
                            order, bestTotal, improved = cand, total, true
                        end
                    end
                end
                if not improved then
                    break
                end
            end
        end
        -- 구간 옮기기 (or-opt): 1~3곳을 순서 그대로 떼어 다른 자리에 끼워 본다. 뒤집기(2-opt)로는 만들 수 없는
        -- "덩어리가 엉뚱한 곳에 붙은" 경우를 고친다 (2026-10-26 램값: 공허폭풍 북쪽 두 곳과 특별 과제가 맨 뒤로 밀려
        -- 귀환석과 포탈로 되돌아오던 동선). 해금 조건(Valid)은 그대로 지킨다. 줄어드는 첫 후보를 받아들이고 처음부터 다시 본다
        local function OrOpt()
            for len = 1, 3 do
                for i = minPos, m - len + 1 do
                    local rest, seg = {}, {}
                    for t = 1, m do
                        if t >= i and t < i + len then
                            table.insert(seg, order[t])
                        else
                            table.insert(rest, order[t])
                        end
                    end
                    for pos = minPos, #rest + 1 do
                        if pos ~= i then
                            local cand = {}
                            for t = 1, pos - 1 do
                                table.insert(cand, rest[t])
                            end
                            for _, v in ipairs(seg) do
                                table.insert(cand, v)
                            end
                            for t = pos, #rest do
                                table.insert(cand, rest[t])
                            end
                            local total = Total(cand)
                            if total < bestTotal - 0.01 and Valid(cand) then
                                order, bestTotal = cand, total
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end
        local function Improve()
            TwoOpt()
            for _ = 1, 100 do
                if not OrOpt() then
                    break
                end
                TwoOpt()
            end
        end
        Improve()
        if #rc > 0 then
            rcOn = true
            bestTotal = Total(order)
            Improve()
        end

        -- 만료 고려: 거리로 짠 순서에서 도착 예상 시각을 어림해, 도착 전에 끝나는 퀘스트만 앞으로 당긴다
        --   도착 예상 = 지금 + 이동 거리(야드, 포탈은 환산값) / 비행 속도 + 앞 목적지마다 처리 시간
        --   시간 안에 닿는 자리 중 전체 동선이 가장 덜 늘어나는 곳으로 옮기고,
        --   옮겨서 놓치는 퀘스트 수가 줄어들 때만 바꾼다
        local now = time()
        local function Arrivals(o)
            local t, prev, arr = now, 0, {}
            for idx, j in ipairs(o) do
                if idx > 1 then
                    t = t + NAV_HANDLE
                end
                t = t + cost[prev][j] / NAV_SPEED
                arr[idx] = t
                prev = j
            end
            return arr
        end
        local function Misses(o)
            local arr, m = Arrivals(o), 0
            for idx, j in ipairs(o) do
                local e = points[j].expire
                if e and arr[idx] > e - NAV_MARGIN then
                    m = m + 1
                end
            end
            return m
        end
        local pulled, tried = {}, {}
        for _ = 1, m do
            local arr = Arrivals(order)
            local k
            for idx = minPos, m do
                local e = points[order[idx]].expire
                if e and arr[idx] > e - NAV_MARGIN and not tried[order[idx]] then
                    k = idx
                    break
                end
            end
            if not k then
                break
            end
            local j = order[k]
            tried[j] = true
            local base = Misses(order)
            local best, bestT
            for pos = minPos, k - 1 do
                local cand = {}
                for idx, v in ipairs(order) do
                    if idx ~= k then
                        table.insert(cand, v)
                    end
                end
                table.insert(cand, pos, j)
                local a = Arrivals(cand)
                if a[pos] <= points[j].expire - NAV_MARGIN and Misses(cand) < base and Valid(cand) then
                    local tot = Total(cand)
                    if not bestT or tot < bestT then
                        best, bestT = cand, tot
                    end
                end
            end
            if best then
                order = best
                table.insert(pulled, points[j])
            end
        end

        -- "마지막에" 지점: 나머지를 다 돈 자리에서 가까운 순서로 붙인다
        cur = order[#order] or 0
        local lastUsed = {}
        for _ = 1, lastCount do
            local best, bestC
            for j in pairs(lastSet) do
                if not lastUsed[j] and (not bestC or cost[cur][j] < bestC) then
                    best, bestC = j, cost[cur][j]
                end
            end
            lastUsed[best] = true
            table.insert(order, best)
            cur = best
        end

        local result, prev = {}, 0
        for _, j in ipairs(order) do
            local p = points[j]
            p.portals = via[prev][j] or {}
            table.insert(result, p)
            prev = j
        end
        local assumed = {}
        if rcOn then
            Total(order, assumed)
        end
        return result, pulled, assumed
    end

    -- 시뮬레이션 테스트용 (동작에는 영향 없음): 동선 순서와 이동 비용을 밖에서 불러 볼 수 있게 한다
    QTR.OrderPoints, QTR.TravelCost = OrderPoints, TravelCost

    ---------------------------------------------------------------------------
    -- 귀환석 (1단계: 귀환석과 귀환석 모양 장난감)
    --   귀환 지점: 게임은 이름(GetBindLocation)만 알려 주므로, 귀환석을 실제로 탔을 때 도착한 곳을 여관 이름별로 기억한다
    --     DB.hearthBinds[여관 이름] = { c, x, y, t } 계정 공용: 한 캐릭터가 한 번 타면 같은 여관을 쓰는 모든 캐릭터에 쓴다
    --     (예전 시험판은 DB.chars[캐릭터].hearth = { name, c, x, y, t } 에 캐릭터별로 남겼다. 읽을 때 계정 공용으로 옮긴다)
    --     DB.chars[캐릭터].hearthUses = { 사용 시각, ... } (최근 2시간), hearthCD, hearthCDGuild = 실제로 본 대기시간과 그때 길드 가입 여부
    --   재사용 대기시간: 기본 30분, 길드 혜택 "빠른 귀환" -15분, 인간 종족 특성(No Place Like Home) -5분과 충전 1회 추가
    --     실제로 본 대기시간이 있으면 그것을 쓴다 (길드 가입 여부가 그때와 같을 때만)
    --   귀환석 모양 장난감들은 귀환석과 대기시간을 같이 쓰므로 귀환석(6948)의 대기시간만 본다
    --   경로: 거리로 짠 순서에서 한 구간을 "귀환석 + 귀환 지점에서 그 목적지까지"로 바꿨을 때 가장 많이 줄어드는 곳에 한 번 넣는다
    --     그 시각에 귀환석을 쓸 수 있어야 하고, "1회 남기기"를 켰으면 다 마칠 시각에 다시 쓸 수 있어야 한다
    ---------------------------------------------------------------------------
    local HEARTH_ITEM = 6948
    local HEARTH_SPELL = 8690
    -- 귀환석과 대기시간을 같이 쓰는 귀환석 장난감 아이템 ID (RandomHearth r37, JamienAU 의 목록에서 ID만 가져왔다)
    -- 달라란, 주둔지 귀환석은 목적지와 대기시간이 따로라 넣지 않는다
    local HEARTH_TOYS = {
        184353, 183716, 180290, 182773, 54452, 64488, 93672, 142542, 162973, 163045,
        165669, 165670, 165802, 166746, 166747, 168907, 172179, 193588, 188952, 200630,
        190237, 190196, 209035, 208704, 206195, 212337, 210455, 228940, 235016, 236687,
        245970, 246565, 263489, 257736, 265100, 263933, 264367, 281136, 281615,
    }
    -- 장난감이 시전하는 주문 ID (게임에 물어서 채운다. 아이템 정보가 아직 없으면 다음에 다시 묻는다)
    local hearthSpells, hearthToyRead = { [HEARTH_SPELL] = true }, {}
    local function IsHearthSpell(spellID)
        if not spellID then
            return false
        end
        if hearthSpells[spellID] then
            return true
        end
        if C_Item and C_Item.GetItemSpell then
            for _, itemID in ipairs(HEARTH_TOYS) do
                if not hearthToyRead[itemID] then
                    local ok, _, toySpell = pcall(C_Item.GetItemSpell, itemID)
                    if ok and type(toySpell) == "number" then
                        hearthSpells[toySpell] = true
                        hearthToyRead[itemID] = true
                    elseif C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, itemID)
                    end
                end
            end
        end
        return hearthSpells[spellID] == true
    end
    local HEARTH_COST = 20 * NAV_SPEED     -- 귀환석 한 번 비용 (시전 10초 + 로딩 어림 10초를 야드로 환산)
    -- 넣는 기준 HEARTH_MIN_SAVE(15초)는 TravelCost 위에 있다 (동선 순서 계산에서도 쓴다)

    local function MyChar()
        return charKey and DB.chars[charKey]
    end

    local function BindName()
        local ok, name = pcall(GetBindLocation)
        return ok and type(name) == "string" and name ~= "" and name or nil
    end

    -- 지금 귀환 지점(여관 이름)의 기억한 위치: { name, c, x, y, t }. 모르면 nil
    -- 예전 시험판이 캐릭터별로 남긴 같은 이름의 위치가 있으면 계정 공용으로 옮겨 쓴다
    local function HearthBind()
        local name = BindName()
        if not name then
            return nil
        end
        DB.hearthBinds = DB.hearthBinds or {}
        local b = DB.hearthBinds[name]
        if not b then
            for _, c in pairs(DB.chars) do
                local h = c.hearth
                if h and h.name == name and h.c and h.x and h.y then
                    b = { c = h.c, x = h.x, y = h.y, t = h.t }
                    DB.hearthBinds[name] = b
                    break
                end
            end
        end
        if b and b.c and b.x and b.y then
            return { name = name, c = b.c, x = b.x, y = b.y, t = b.t }
        end
        return nil
    end

    -- 귀환석 아이템의 남은 대기시간(초, 0이면 쓸 수 있음)과 대기시간 전체 길이. 못 읽으면 nil
    local function HearthItemCooldown()
        if not (C_Container and C_Container.GetItemCooldown) then
            return nil
        end
        local ok, start, duration = pcall(C_Container.GetItemCooldown, HEARTH_ITEM)
        if not (ok and type(start) == "number" and type(duration) == "number") then
            return nil
        end
        if start > 0 and duration > 2 then
            return math.max(0, start + duration - GetTime()), duration, start
        end
        return 0, duration, start
    end

    -- 귀환석이 대기시간 중이면 그 대기시간 길이를 캐릭터에 기억한다 (길드 혜택, 종족 특성이 반영된 실제 값)
    -- 귀환석을 쓴 뒤 몇 번, 그리고 귀환석 상태를 볼 때마다(내비게이션 시작, /qtr hearth) 부른다. 아이템 대기시간 한 번 읽기라 가볍다
    -- (2026-10-24: 쓴 뒤 1초에 한 번만 읽었더니 캐릭터에 따라 기록이 빠졌다)
    local function LearnHearthCD()
        local me = MyChar()
        local remain, duration = HearthItemCooldown()
        if me and remain and remain > 0 and duration and duration > 60 then
            me.hearthCD = duration
            me.hearthCDGuild = (IsInGuild and IsInGuild()) and true or false
        end
    end

    -- 지금 귀환석 상태: cd(한 번 쓴 뒤 다시 차는 시간), maxCh(최대 충전), uses(최근 사용 시각), blocked(이 시각 전에는 못 씀)
    local function HearthState()
        LearnHearthCD()
        local me = MyChar() or {}
        local inGuild = (IsInGuild and IsInGuild()) and true or false
        local okRace, _, race = pcall(UnitRace, "player")
        local human = okRace and race == "Human"
        local cd = 1800 - (inGuild and 900 or 0) - (human and 300 or 0)
        if type(me.hearthCD) == "number" and me.hearthCDGuild == inGuild then
            cd = me.hearthCD
        end
        local now = time()
        local remain = HearthItemCooldown()
        return { cd = cd, maxCh = human and 2 or 1, uses = me.hearthUses or {},
            blocked = (remain and remain > 0) and (now + remain) or now }
    end

    -- t 시각의 남은 충전 수 (사용 시각 목록으로 따진다. 충전은 하나씩 차례로 찬다)
    local function HearthCharges(st, uses, t)
        local charges, rech = st.maxCh, nil
        local function Regen(upto)
            while rech and rech <= upto do
                charges = charges + 1
                rech = (charges < st.maxCh) and (rech + st.cd) or nil
            end
        end
        for _, u in ipairs(uses) do
            if u <= t then
                Regen(u)
                charges = math.max(0, charges - 1)
                rech = rech or (u + st.cd)
            end
        end
        Regen(t)
        return charges
    end

    ---------------------------------------------------------------------------
    -- 순간이동 기술과 장난감 (2단계, 2026-10-26)
    --   마법사 실버문 순간이동: 대기시간이 없어 포탈처럼 TravelCost에 넣는다 (mageTele). 주문 ID는 한밤 클라이언트에서
    --     확인하지 못해 주문책(순간이동 묶음)에서 이름에 "실버문"과 "순간이동"이 든 주문을 찾는다. 시전하면 그 주문 ID를 기억한다.
    --     내리는 곳: 2026-10-24 /qtr pos 실측 (실버문 시장). 시전 뒤 실제로 내린 곳을 보면 그것으로 바꾼다 (DB.travelDest.mage)
    --   귀환형 이동 (대기시간이 있어 경로에서 쓸 수 있는 횟수가 정해진 것): 귀환석(장난감 포함), 주술사 영혼의 귀환(귀환 지점으로),
    --     아르칸티나로 통하는 개인 열쇠(아르칸티나에 들어갔다가 나가는 차원문을 타면 실버문 여관 "나그네의 쉼터"로 나온다)
    --     동선 순서를 짤 때부터 이 이동들을 고려한다 (OrderPoints의 recalls). 실제로 넣는 자리는 PlanRecalls가
    --     그 시각에 쓸 수 있는지(대기시간, 귀환석 충전, 1회 남기기)를 보고 정한다
    --   각각 설정에서 끌 수 있다: travelMageOff, travelAstralOff, travelArcantinaOff (귀환석은 원래의 hearthOff).
    --   쐐기 포탈만 기본 끔이라 켜는 설정 travelMaisaraOn
    ---------------------------------------------------------------------------
    local MAGE_DEST = { 2393, 0.528187, 0.654835 }
    -- 한밤 실버문 순간이동 (2026-10-26 게임 툴팁 SpellID 확인). 이름이 같은 불타는 성전 주문
    -- "순간이동: 실버문 (불타는 성전)"은 옛 실버문으로 가므로 쓰면 안 된다 (같은 날 사용자 확인)
    local MAGE_SPELL = 1259190
    local ASTRAL_SPELL = 556                      -- 영혼의 귀환 (주술사)
    local ASTRAL_CD = 600                         -- 대기시간 기본값 10분 (한밤 값은 확인 불가. 실제로 본 대기시간을 기억해 쓴다)
    local ASTRAL_COST = 20 * NAV_SPEED            -- 귀환석과 같은 시전 10초 + 로딩
    local ARC_ITEM, ARC_SPELL = 253629, 1255801   -- 아르칸티나로 통하는 개인 열쇠 (장난감)
    local ARC_CD = 900                            -- 대기시간 15분 (귀환석과 따로)
    -- 시전, 로딩, 나가는 차원문까지 걷기, 로딩. 처음 45초로 어림했으나 2026-10-26 실측(격냥패딩, 내비게이션 시작부터
    -- 실버문 여관에 서기까지 26초, 버튼을 누르기까지의 시간 포함)으로 30초. 로딩이 두 번이라 귀환석(20초)보다는 크게 둔다
    local ARC_COST = 30 * NAV_SPEED
    local ARC_INN = QTR.GameText("ARC_INN") or "나그네의 쉼터" -- 아르칸티나에서 나오면 서는 실버문 여관 (여관 이름은 클라이언트 언어)
    local TV = {} -- 이 부분의 함수와 상태 (SetupRoute의 local 수를 아끼려고 한 표에 둔다)
    TV.NAMES = { hearth = L["귀환석"], astral = L["영혼의 귀환"], arcantina = L["아르칸티나 열쇠"], mage = L["순간이동"], root = L["뿌리걸음"] }
    TV.OBJ = { hearth = L["귀환석을"], astral = L["영혼의 귀환을"], arcantina = L["아르칸티나 열쇠를"] }
    TV.BY = { hearth = L["귀환석으로"], astral = L["영혼의 귀환으로"], arcantina = L["아르칸티나 열쇠로"], mage = L["순간이동으로"] }
    -- 마이사라 동굴 순간이동 (2026-11-01 사용자 요청): 쐐기돌 던전 마이사라 동굴을 10단계 이상으로 마치면 받는 주문
    --   "심연의 동굴의 길" (게임 툴팁 SpellID 1254559). 줄아만 마이사라 동굴 입구에 내린다 (같은 날 /qtr pos 실측)
    --   줄아만은 포탈이 없어 영원노래 숲이나 똬리의 섬에서 날아가야 해서 넣는다. 대기시간 8시간이고 다른 던전 순간이동과
    --   함께 돈다 (캐릭터마다 따로. 다른 쐐기 포탈을 쓰면 이 주문도 8시간 대기시간으로 보인다, 같은 날 사용자 게임 확인).
    --   시전 8.8초라 비용은 다른 순간이동처럼 어림한다 (TELE_COST). 설정 travelMaisaraOn으로 켠다
    --   기본 끔 (2026-11-02 사용자 결정: 쐐기를 즐기는 사람은 모르는 사이에 8시간 대기시간이 걸리면 싫어할 것. 1.6.0은 기본 켬이었다)
    --   이름은 "쐐기 포탈" (같은 날 사용자 요청: 주문 이름 "심연의 동굴의 길"보다 알아보기 쉽게)
    --   넣는 기준은 45초 이상 빨라질 때 (2026-11-08 사용자 결정. 다른 수단은 15초: 같은 줄아만 안에서 16초 줄이려고
    --   8시간 쿨타임을 쓰는 것이 부자연스러웠다. 16초는 순간이동 비용 어림의 오차 범위 안이기도 하다)
    TV.MAI = { spell = 1254559, map = 2437, x = 0.445193, y = 0.393821, cd = 8 * 3600, minSave = 45 * NAV_SPEED }
    TV.NAMES.maisara = L["쐐기 포탈"]
    TV.OBJ.maisara = L["쐐기 포탈을"]

    -- 둔둔의 풍요로운 이동 수단 (2026-11-07 사용자 결정, 인벤 엔젤스쿨님 제안): 장난감 266370, 사용 주문 1278093 (Wowhead 툴팁)
    --   "현재 풍요 지점으로 이동", 한밤 지역에서만 사용, 대기시간 30분. 업적 "풍요: 아제로스는 둔둔 없이 못 살아"가 있어야 산다
    --   지금 풍요 지점은 지역 POI가 아니라 이벤트 목록(C_AreaPoiInfo.GetEventsForMap)에 아이콘 UI-EventPoi-abundancebountiful로 나온다
    --   (2026-11-07 사용자 게임 확인: 공허폭풍 POI 8526 "풍요: 채광 공허굴", 지도 38.8, 53.3). 남은 시간은 POI 정보에 없고
    --   툴팁 위젯 묶음(tooltipWidgetSet)의 글자 위젯에 "남은 시간: 4시간 12분"으로만 나온다. 위젯 번호는 지점마다 다를 수 있어 박지 않는다
    --   내리는 곳: 처음에는 이벤트 아이콘 위치로 어림하고, 한 번 타면 실제로 내린 곳을 지점(POI)별로 기억한다 (DB.travelDest.dundun[POI])
    --   사용자가 장난감이 없어 게임에서 확인하지 못했다 (장난감이 이 지점으로 보내는지, 내리는 곳, 영어 클라이언트 시간 글자 모두 확인 불가)
    --   그래서 기본 끔, 설정 travelDundunOn으로 켠다. 풍요 지점이 끝나기 2분 전부터는 쓰지 않고 (남은 시간이 분 단위라 여유), 안내 중 지점이 바뀌면 경로를 다시 짠다
    TV.DUN = { item = 266370, spell = 1278093, cd = 1800, continent = 2537 }
    TV.NAMES.dundun = L["둔둔 장난감"]
    TV.OBJ.dundun = L["둔둔 장난감을"]

    -- 구렁로봇 7001 (2026-11-08 사용자 결정, 인벤 엔젤스쿨님 제안): 장난감 230850, 사용 주문 467470 "구렁로봇 7001 소환"
    --   로봇(NPC 232267)을 불러 말을 걸면 선택지로 목적지를 고른다 (사용자 게임 확인): 142847 "킨도잔의 미궁으로 데려다주십시오."
    --   (미궁 업데이트 칩, 계정 공통), 140193 카즈 알가르 구렁, 140192 한밤 구렁. 미궁 입구 실측 (/qtr pos #20): 영원노래 숲 62.89, 71.98
    --   부르고 말을 걸 수 있을 때까지 약 5초, 고른 뒤 순간이동 로딩 약 5초 (사용자 실측) -> 비용은 다른 순간이동처럼 TELE_COST. 대기시간 1시간
    --   칩은 미리 알 수 없어 로봇 선택지에 142847이 있는지로 배운다 (DB.delveBotLab = 본 시각, 없었으면 false. 계정 공통)
    --   2026-11-08 사용자 요청: 계정에서 한 번이라도 봤으면 다른 캐릭터도 칩이 있다고 본다. 한 번 본 뒤에는 false로 바꾸지 않고,
    --   미궁 입구에 내린 기록(DB.travelDest.delvebot)이 있어도 칩이 있는 것으로 본다 (TV.HasLabChip).
    --   (그날 게임: 격냥패딩이 미궁에 다녀온 뒤 다른 캐릭터에서 false로 덮였다. 다른 애드온이 먼저 선택지를 골라
    --   대화창이 닫힌 뒤 읽었을 수 있어, 선택지가 하나도 없으면 배우지 않는다. 덮인 까닭은 확인 불가)
    --   기본 끔 (설정 travelDelveBotOn): 1시간 대기시간을 구렁에 쓰려는 사람도 있어서 (마이사라와 같은 까닭)
    --   미궁 선택지 자동 선택: 내비게이션의 지금 단계가 구렁로봇이고 막 장난감을 썼을 때만, Shift를 누르고 있지 않을 때만 (TV.OnGossip)
    TV.DBOT = { item = 230850, spell = 467470, npc = 232267, option = 142847, cd = 3600, map = 2395, x = 0.6289, y = 0.7198 }
    TV.NAMES.delvebot = L["구렁로봇"]
    TV.OBJ.delvebot = L["구렁로봇을"]
    function TV.HasLabChip()
        return (DB.delveBotLab or (DB.travelDest and DB.travelDest.delvebot)) and true or false
    end

    -- 남은 시간 글자("남은 시간: 4시간 12분", 영어 "4 Hr 12 Min" 등)를 초로. 시간 단위가 하나도 없으면 nil
    --   숫자 바로 뒤의 단위 글자로 가린다 (보상 줄 "복원된 금고 열쇠: 11"처럼 단위가 없는 숫자는 세지 않는다)
    function TV.ParseLeft(text)
        if type(text) ~= "string" then
            return nil
        end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local sec, any = 0, false
        for num, unit in text:gmatch("(%d+)%s*([^%d%s%p]+)") do
            local u = unit:lower()
            local mult
            if u:find("^시간") or u == "h" or u:find("^hr") or u:find("^hour") then
                mult = 3600
            elseif u:find("^분") or u == "m" or u:find("^min") then
                mult = 60
            elseif u:find("^일") or u == "d" or u:find("^day") then
                mult = 86400
            elseif u:find("^초") or u == "s" or u:find("^sec") then
                mult = 1
            end
            if mult then
                sec = sec + tonumber(num) * mult
                any = true
            end
        end
        return any and sec or nil
    end
    QTR.TestParseLeft = TV.ParseLeft -- 테스트에서 글자 읽기만 확인할 때

    -- 툴팁 위젯 묶음에서 남은 시간을 읽어 끝나는 시각으로. 못 읽으면 nil
    function TV.AbundanceExpire(setID)
        local U = C_UIWidgetManager
        if not (setID and U and U.GetAllWidgetsBySetID and U.GetTextWithStateWidgetVisualizationInfo) then
            return nil
        end
        local ok, widgets = pcall(U.GetAllWidgetsBySetID, setID)
        for _, w in ipairs(ok and type(widgets) == "table" and widgets or {}) do
            local okT, info = pcall(U.GetTextWithStateWidgetVisualizationInfo, w.widgetID)
            local left = okT and info and TV.ParseLeft(info.text)
            if left then
                return time() + left
            end
        end
        return nil
    end

    -- 지금 풍요 지점: { poi, map, name, zone, dest(월드 좌표), expire(끝나는 시각, 모르면 nil) } 또는 nil
    --   골드퀘 지역 지도들의 이벤트 목록에서 찾는다. 내린 곳을 기억한 지점이면 그 위치를 도착지로 쓴다
    function TV.Abundance()
        if not (C_AreaPoiInfo and C_AreaPoiInfo.GetEventsForMap and C_AreaPoiInfo.GetAreaPOIInfo) then
            return nil
        end
        for _, z in ipairs(GQ_ZONES) do
            local m = z.mapID
            local ok, ids = pcall(C_AreaPoiInfo.GetEventsForMap, m)
            for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
                local okI, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, m, id)
                local atlas = okI and info and type(info.atlasName) == "string" and info.atlasName:lower() or ""
                if atlas:find("abundancebountiful", 1, true) and info.position then
                    local x, y = info.position.x, info.position.y
                    if info.position.GetXY then
                        x, y = info.position:GetXY()
                    end
                    local dest = x and y and WorldPos(m, x, y)
                    if dest then
                        local learned = DB.travelDest and DB.travelDest.dundun and DB.travelDest.dundun[id]
                        if learned and learned.c and learned.x and learned.y then
                            dest = { c = learned.c, x = learned.x, y = learned.y }
                        end
                        local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
                        TV.lastAb = { poi = id, map = m, name = info.name or L["풍요"], zone = mi and mi.name,
                            dest = dest, expire = TV.AbundanceExpire(info.tooltipWidgetSet) }
                        return TV.lastAb
                    end
                end
            end
        end
        return nil
    end

    -- 지금 한밤 지역에 있는가 (장난감은 한밤 지역에서만 쓸 수 있다): 골드퀘 지역 지도이거나 지도를 위로 올라가 한밤 대륙(2537)
    function TV.InMidnight()
        local id = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        for _ = 1, 10 do
            if not id then
                return false
            end
            if id == TV.DUN.continent then
                return true
            end
            for _, z in ipairs(GQ_ZONES) do
                if z.allowedMaps[id] then
                    return true
                end
            end
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
            id = info and info.parentMapID
        end
        return false
    end

    -- 둔둔 장난감의 사용 주문 ID (게임에 물어 본다. 못 읽으면 알려진 값)
    function TV.DunSpell()
        if C_Item and C_Item.GetItemSpell then
            local ok, _, id = pcall(C_Item.GetItemSpell, TV.DUN.item)
            if ok and type(id) == "number" then
                return id
            end
        end
        return TV.DUN.spell
    end

    -- 내비게이션 창과 사용 버튼 창의 이름 (2026-10-27 사용자 요청): "귀환석: 나그네의 쉼터 (실버문)", 마법사는 주문 이름대로 "순간이동: 실버문"
    --   돌려주는 값: 전체 이름, 지역을 뺀 이름(내비게이션 창은 지역을 포탈 줄처럼 따로 붙인다), 지역, 채팅용 이름
    --   채팅은 "다음 목적지: " 뒤에 붙으므로 쌍점 없이 "귀환석으로 나그네의 쉼터 (실버문)" (2026-10-26 쌍점 겹침 수정 유지)
    --   여관 지역은 그 여관에 내렸을 때 기억한다 (hearthBinds[여관].zone). 지역을 모르면 아르칸티나 여관만 실버문으로 안다
    --   아르칸티나 열쇠는 "장난감: 아르칸티나 열쇠" (2026-10-30 사용자 요청: 나오는 여관과 지역은 빼고 장난감인 것만)
    function TV.TravelLabel(key, inn)
        if key == "mage" then
            return L["순간이동: 실버문"], L["순간이동: 실버문"], nil, L["순간이동으로 실버문"]
        end
        if key == "root" then
            -- "뿌리걸음: 요람 (하란다르)", 채팅 "뿌리걸음으로 요람 (하란다르)" (지역 이름은 게임에서 읽는다)
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(TV.ROOT.map)
            local zone = (info and info.name) or L["하란다르"]
            return L["뿌리걸음: 요람"] .. " (" .. zone .. ")", L["뿌리걸음: 요람"], zone, L["뿌리걸음으로 요람"] .. " (" .. zone .. ")"
        end
        if key == "arcantina" then
            return L["장난감: 아르칸티나 열쇠"], L["장난감: 아르칸티나 열쇠"], nil, L["아르칸티나 열쇠 (장난감)"]
        end
        if key == "maisara" then
            -- "쐐기 포탈: 마이사라 동굴 (줄아만)", 채팅 "쐐기 포탈로 마이사라 동굴 (줄아만)" (지역 이름은 게임에서 읽는다)
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(TV.MAI.map)
            local zone = (info and info.name) or L["줄아만"]
            local text = L["쐐기 포탈: 마이사라 동굴"]
            return text .. " (" .. zone .. ")", text, zone, L["쐐기 포탈로 마이사라 동굴"] .. " (" .. zone .. ")"
        end
        if key == "delvebot" then
            -- "장난감: 구렁로봇 (킨도잔의 미궁) (영원노래 숲)", 채팅 "구렁로봇으로 킨도잔의 미궁 (영원노래 숲)"
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(TV.DBOT.map)
            local zone = (info and info.name) or L["영원노래 숲"]
            local text = L["장난감: 구렁로봇 (킨도잔의 미궁)"]
            return text .. " (" .. zone .. ")", text, zone, L["구렁로봇으로 킨도잔의 미궁"] .. " (" .. zone .. ")"
        end
        if key == "dundun" then
            -- "장난감: 둔둔 [풍요: 채광 공허굴] (공허폭풍)", 채팅 "둔둔 장난감으로 풍요: 채광 공허굴 (공허폭풍)"
            local ab = TV.lastAb
            local name = tostring(inn or (ab and ab.name) or L["풍요"])
            local zone = ab and ab.name == inn and ab.zone or nil
            local z = zone and (" (" .. zone .. ")") or ""
            local text = L["장난감: 둔둔"] .. " [" .. name .. "]"
            return text .. z, text, zone, L["둔둔 장난감으로 "] .. name .. z
        end
        local b = inn and DB.hearthBinds and DB.hearthBinds[inn]
        -- zoneV 2: 지도 기준으로 읽은 지역 (그전 GetRealZoneText 값은 내린 직후 바뀌기 전 지역이 남을 수 있어 쓰지 않는다)
        local zone = (b and b.zoneV == 2 and b.zone) or (inn == ARC_INN and L["실버문"]) or nil
        local where = tostring(inn or "?")
        local z = (zone and zone ~= "") and (" (" .. zone .. ")") or ""
        local text = TV.NAMES[key] .. ": " .. where
        return text .. z, text, zone, TV.BY[key] .. " " .. where .. z
    end
    QTR.TravelLabelForTest = TV.TravelLabel -- 테스트에서 이름만 확인할 때

    -- 지금 서 있는 곳의 지역 이름: 지금 지도에서 위로 올라가 지역(Zone) 지도의 이름 (여관, 던전 안 지도는 그 위 지역)
    --   (2026-10-30: GetRealZoneText는 귀환석으로 내린 직후 바뀌기 전 지역을 돌려줄 수 있다. 램값이 황혼의 납골당에서
    --    귀환석을 타자 나그네의 쉼터 지역이 "황혼의 납골당"으로 저장됐다. 위치를 읽는 지도와 같은 기준으로 바꿨다)
    function TV.ZoneNow()
        local id = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        for _ = 1, 8 do
            local info = id and C_Map.GetMapInfo(id)
            if not info then
                return nil
            end
            local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
            if info.mapType == nil or info.mapType == zoneType then
                return info.name
            end
            if info.mapType < zoneType then
                return nil -- 대륙보다 위: 지역을 모른다
            end
            id = info.parentMapID
        end
        return nil
    end

    -- 귀환 지점에 내렸을 때 여관 위치와 지역을 기억한다 (예전에 기억한 지역은 지금 읽지 못하면 남긴다)
    function TV.SaveBind(name, p)
        DB.hearthBinds = DB.hearthBinds or {}
        local old = DB.hearthBinds[name]
        local zone, zoneV = TV.ZoneNow(), 2
        if type(zone) ~= "string" or zone == "" then
            zone, zoneV = old and old.zone, old and old.zoneV
        end
        DB.hearthBinds[name] = { c = p.c, x = p.x, y = p.y, t = time(), zone = zone, zoneV = zoneV }
        return old
    end

    function TV.SpellKnown(id)
        if C_SpellBook and C_SpellBook.IsSpellKnown then
            local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
            if ok and r then
                return true
            end
        end
        if IsPlayerSpell then
            local ok, r = pcall(IsPlayerSpell, id)
            if ok and r then
                return true
            end
        end
        return false
    end

    function TV.SpellName(id)
        if C_Spell and C_Spell.GetSpellName then
            local ok, name = pcall(C_Spell.GetSpellName, id)
            if ok and type(name) == "string" then
                return name
            end
        end
        return nil
    end

    -- 주문의 남은 대기시간(초)과 대기시간 길이. 공용 대기시간(1.5초)은 대기시간으로 보지 않는다. 못 읽으면 nil
    function TV.SpellCD(id)
        if not (C_Spell and C_Spell.GetSpellCooldown) then
            return nil
        end
        local ok, remain, duration = pcall(function()
            local a, b = C_Spell.GetSpellCooldown(id)
            local start, dur = a, b
            if type(a) == "table" then
                start, dur = a.startTime, a.duration
            end
            if type(start) ~= "number" or type(dur) ~= "number" then
                return nil
            end
            if start > 0 and dur > 2 then
                return math.max(0, start + dur - GetTime()), dur
            end
            return 0, dur
        end)
        if ok then
            return remain, duration
        end
        return nil
    end

    -- 아이템(장난감 포함)의 남은 대기시간(초)과 대기시간 길이. 못 읽으면 nil
    function TV.ItemCD(itemID)
        if not (C_Container and C_Container.GetItemCooldown) then
            return nil
        end
        local ok, start, duration = pcall(C_Container.GetItemCooldown, itemID)
        if not (ok and type(start) == "number" and type(duration) == "number") then
            return nil
        end
        if start > 0 and duration > 2 then
            return math.max(0, start + duration - GetTime()), duration
        end
        return 0, duration
    end

    function TV.HasToy(itemID)
        local fn = PlayerHasToy or (C_ToyBox and C_ToyBox.PlayerHasToy)
        if not fn then
            return false
        end
        local ok, has = pcall(fn, itemID)
        return ok and has and true or false
    end

    -- 아르칸티나 열쇠의 주문 ID (게임에 물어 본다. 못 읽으면 알려진 값)
    function TV.ArcSpell()
        if C_Item and C_Item.GetItemSpell then
            local ok, _, id = pcall(C_Item.GetItemSpell, ARC_ITEM)
            if ok and type(id) == "number" then
                return id
            end
        end
        return ARC_SPELL
    end

    -- 한밤 실버문 순간이동 주문 이름인가: 정확히 "순간이동: 실버문"만 (뒤에 "(불타는 성전)"이 붙은 옛 주문은 아니다)
    function TV.IsMageTeleName(name)
        return name == (QTR.GameText("MAGE_TELE") or "순간이동: 실버문")
    end

    -- 주문책에서 마법사 실버문 순간이동을 찾는다 (순간이동 주문들은 주문책의 묶음(flyout) 안에 있다)
    function TV.ScanMageTele()
        if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
            and C_SpellBook.GetSpellBookItemInfo) then
            return nil
        end
        local ok, found = pcall(function()
            local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
            local flyType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
            for l = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
                local line = C_SpellBook.GetSpellBookSkillLineInfo(l)
                if line and line.itemIndexOffset and line.numSpellBookItems then
                    for s = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                        local info = C_SpellBook.GetSpellBookItemInfo(s, bank)
                        if info and flyType and info.itemType == flyType and info.actionID and GetFlyoutInfo and GetFlyoutSlotInfo then
                            local _, _, num = GetFlyoutInfo(info.actionID)
                            for k = 1, num or 0 do
                                local id, _, known, name = GetFlyoutSlotInfo(info.actionID, k)
                                if known and id and TV.IsMageTeleName(name or TV.SpellName(id)) then
                                    return id
                                end
                            end
                        elseif info and info.spellID and TV.IsMageTeleName(info.name) then
                            return info.spellID
                        end
                    end
                end
            end
            return nil
        end)
        return ok and found or nil
    end

    -- 한밤 실버문 순간이동의 도착점: 실측 위치. 시전해서 기억한 위치(DB.travelDest.mage)는 실측 위치 가까이(JUMP 안)일 때만 쓰고,
    -- 아니면 지운다 (2026-10-26 테스트 버전이 옛 실버문(불타는 성전) 주문의 도착점을 잘못 기억한 것을 정리)
    function TV.MageDest()
        local base = WorldPos(MAGE_DEST[1], MAGE_DEST[2], MAGE_DEST[3])
        local d = DB.travelDest and DB.travelDest.mage
        if d and base and (d.c ~= base.c or Dist(d, base) > JUMP) then
            DB.travelDest.mage = nil
            d = nil
        end
        return d and { c = d.c, x = d.x, y = d.y } or base
    end

    -- 지금 캐릭터가 쓸 수 있는 한밤 실버문 순간이동을 mageTele에 채운다 (경로를 짤 때마다)
    -- 주문 ID(MAGE_SPELL)로 배웠는지 보고, 못 읽으면 주문책에서 정확히 같은 이름을 찾는다
    function TV.RefreshMage()
        mageTele = nil
        local me = MyChar()
        if me then
            me.mageTele = nil -- 2026-10-26 테스트 버전이 기억하던 주문 ID (옛 주문일 수 있어 더 쓰지 않는다)
        end
        if DB.settings.travelMageOff then
            return
        end
        local okClass, _, class = pcall(UnitClass, "player")
        if not (okClass and class == "MAGE") then
            return
        end
        local id = TV.SpellKnown(MAGE_SPELL) and MAGE_SPELL or TV.ScanMageTele()
        if not id then
            return
        end
        local pos = TV.MageDest()
        if pos then
            mageTele = { spell = id, pos = pos }
        end
    end

    -- 하라니르 종족 기술 뿌리걸음 (2026-11-08 인벤 김다크님 제안, 사용자 "한번 테스트해보자"):
    --   주문 1238686 (게임 툴팁 확인), 시전 7.5초(툴팁), 쿨타임 없음(위키). 하란다르의 요람으로 순간이동한다.
    --   하란다르 안 세계수 뿌리 가까이에서 쓰면 그 세계수(다른 대륙)로 간다. 뿌리 좌표는 warcraft.wiki.gg (하란다르 지도 2413 기준으로 보았다),
    --   "가까이"의 거리는 확인 불가라 넉넉히 150야드로 둔다.
    --   요람에 내리는 곳: 한 번 써서 하란다르 대륙에 내린 곳을 기억한다 (DB.travelDest.root). 그전에는 어림 위치 den을 쓴다
    --   (2026-11-08 처음에는 기억한 뒤부터만 넣었으나, 볶음밥의로아 시험에서 써 보기 전이라 들어가지 않아 어림값을 넣었다.
    --    어림값: 요람은 소굴 위쪽이라 하라티 병참장교 나이나르(소굴, 하란다르 50.9, 50.7, 위키) 자리로 둔다. 확인 불가)
    --   한 번 쓰면 주문이 "뿌리걸음: 귀환"(1238695, 2026-11-08 사용자 게임 툴팁)으로 바뀌어, 쓰면 직전에 뿌리걸음을 쓴 곳으로 돌아간다.
    --   그 상태(back)에서는 귀환 -> 뿌리걸음 두 번을 써야 요람으로 가므로 비용을 두 배로 잡고, 사용 창에 그렇게 알린다.
    --   귀환하면 요람 근처가 아닌 곳으로 순간이동하므로 남은 경로를 다시 짜고, 그때는 뿌리걸음 상태라 다시 뿌리걸음 단계가 나온다
    TV.ROOT = { spell = 1238686, back = 1238695, map = 2413, near = 150, den = { 0.509, 0.507 },
        roots = { { 0.7645, 0.4740 }, { 0.6495, 0.1902 }, { 0.2854, 0.8684 }, { 0.3586, 0.2074 } } }
    function TV.RefreshRoot()
        QTR.rootTele = nil
        if DB.settings.travelRootOff or not TV.SpellKnown(TV.ROOT.spell) then
            return
        end
        local d = DB.travelDest and DB.travelDest.root
        local pos = d and { c = d.c, x = d.x, y = d.y } or WorldPos(TV.ROOT.map, TV.ROOT.den[1], TV.ROOT.den[2])
        if not pos then
            return
        end
        local roots = {}
        for _, r in ipairs(TV.ROOT.roots) do
            table.insert(roots, WorldPos(TV.ROOT.map, r[1], r[2]))
        end
        QTR.rootTele = { spell = TV.ROOT.spell, pos = pos, roots = roots, near = TV.ROOT.near, twice = TV.RootReturning() }
    end
    -- 뿌리걸음이 지금 "뿌리걸음: 귀환"으로 바뀌어 있는가 (주문 덮어쓰기로 읽는다)
    function TV.RootReturning()
        local f = (C_Spell and C_Spell.GetOverrideSpell) or FindSpellOverrideByID
        if not f then
            return false
        end
        local ok, id = pcall(f, TV.ROOT.spell)
        return (ok and id == TV.ROOT.back) and true or false
    end

    -- 대기시간만 있는 귀환형 이동: t에 쓸 수 있는가 (blocked 전에는 못 쓰고, 이번 경로에서 고른 사용과 cd만큼 떨어져야 한다)
    function TV.CDUsable(blocked, cd)
        return function(t, _, chosen)
            if t < blocked then
                return false, false
            end
            for _, u in ipairs(chosen) do
                if math.abs(t - u) < cd then
                    return false, false
                end
            end
            return true, true
        end
    end

    -- 지금 쓸 수 있는 귀환형 이동 목록: { key, label, dest, destName, cost, tokens, usable(t, endT, chosen), remain(남은 대기시간 초) }
    -- only: { [key] = true } 이면 그것만. 두 번째 반환값: 귀환석을 못 넣는 까닭 (귀환 지점 위치를 모를 때)
    -- 세 번째 반환값: 가지고 있고 설정도 켰는데 목록에 못 넣은 수단의 까닭 { [key] = 문구 } (넣지 않은 이유 알리기, 2026-11-08)
    function TV.RecallMethods(only)
        local list, why, missing = {}, nil, {}
        local function want(key)
            return not only or only[key]
        end
        local bind = HearthBind()
        local now = time()
        if want("hearth") and not DB.settings.hearthOff then
            if bind then
                local st = HearthState()
                table.insert(list, { key = "hearth", label = TV.NAMES.hearth, dest = bind, destName = bind.name,
                    cost = HEARTH_COST, tokens = st.maxCh, st = st, remain = st.blocked - now, cdLen = st.cd,
                    -- t에 쓸 수 있는가: 이번 경로에서 고른 사용(chosen)과 t를 합쳐 시각 순으로 놓고, 하나하나 그때 충전이 남아 있어야 한다
                    -- (t보다 뒤에 고른 사용도 t에 쓰면 충전이 모자랄 수 있다). 두 번째 값: 1회 남기기
                    usable = function(t, endT, chosen)
                        if t < st.blocked then
                            return false, false
                        end
                        local mine = { t }
                        for _, u in ipairs(chosen) do
                            table.insert(mine, u)
                        end
                        table.sort(mine)
                        local all = {}
                        for _, u in ipairs(st.uses) do
                            table.insert(all, u)
                        end
                        for _, u in ipairs(mine) do
                            if HearthCharges(st, all, u) < 1 then
                                return false, false
                            end
                            table.insert(all, u)
                            table.sort(all)
                        end
                        local keep = DB.settings.hearthKeepOff or HearthCharges(st, all, endT) >= 1
                        return true, keep
                    end })
            else
                local name = BindName()
                if name then
                    why = L["귀환 지점(%s) 위치를 아직 몰라서. 이 여관으로 귀환석을 한 번 타면 기억합니다."]:format(name)
                    missing.hearth = why
                end
            end
        end
        if want("astral") and bind and not DB.settings.travelAstralOff and TV.SpellKnown(ASTRAL_SPELL) then
            local me = MyChar() or {}
            local remain, duration = TV.SpellCD(ASTRAL_SPELL)
            if remain and remain > 0 and duration and duration > 60 then
                me.astralCD = duration
            end
            local cd = me.astralCD or ASTRAL_CD
            table.insert(list, { key = "astral", label = TV.NAMES.astral, dest = bind, destName = bind.name,
                cost = ASTRAL_COST, tokens = 1, remain = remain, cdLen = cd, usable = TV.CDUsable(now + (remain or 0), cd) })
        end
        if want("arcantina") and not DB.settings.travelArcantinaOff and TV.HasToy(ARC_ITEM) then
            local d = (DB.travelDest and DB.travelDest.arcantina) or (DB.hearthBinds and DB.hearthBinds[ARC_INN])
            if d and d.c and d.x and d.y then
                local remain = TV.ItemCD(ARC_ITEM)
                table.insert(list, { key = "arcantina", label = TV.NAMES.arcantina, dest = { c = d.c, x = d.x, y = d.y },
                    destName = ARC_INN, cost = ARC_COST, tokens = 1, remain = remain, cdLen = ARC_CD, usable = TV.CDUsable(now + (remain or 0), ARC_CD) })
            else
                missing.arcantina = L["나오는 곳(%s) 위치를 몰라서. 한 번 쓰거나 그 여관으로 귀환석을 타면 기억합니다."]:format(ARC_INN)
            end
        end
        if want("maisara") and DB.settings.travelMaisaraOn and TV.SpellKnown(TV.MAI.spell) then
            local d = WorldPos(TV.MAI.map, TV.MAI.x, TV.MAI.y)
            if d then
                local remain = TV.SpellCD(TV.MAI.spell)
                table.insert(list, { key = "maisara", label = TV.NAMES.maisara, dest = d, cost = TELE_COST, tokens = 1,
                    remain = remain, cdLen = TV.MAI.cd, minSave = TV.MAI.minSave, usable = TV.CDUsable(now + (remain or 0), TV.MAI.cd) })
            end
        end
        if want("dundun") and DB.settings.travelDundunOn and TV.HasToy(TV.DUN.item) then
            local ab = TV.Abundance()
            if ab then
                local remain = TV.ItemCD(TV.DUN.item)
                local cdOk = TV.CDUsable(now + (remain or 0), TV.DUN.cd)
                -- 풍요 지점이 끝나기 2분 전부터는 쓰지 않는다 (남은 시간 글자가 분 단위이고 시전과 로딩도 있어서. 그 뒤에는 다른 지점으로 가므로). 끝나는 시각을 모르면 따지지 않는다
                -- 대기시간이 30분이라 한 경로에서 두 번까지 본다. 출발점이 한밤 지역 밖이면 첫 구간에는 못 쓴다 (notFromStart)
                table.insert(list, { key = "dundun", label = TV.NAMES.dundun, dest = ab.dest, destName = ab.name, poi = ab.poi,
                    cost = TELE_COST, tokens = 2, notFromStart = not TV.InMidnight(), remain = remain, cdLen = TV.DUN.cd,
                    usable = function(t, endT, chosen)
                        if ab.expire and t > ab.expire - 120 then
                            return false, false
                        end
                        return cdOk(t, endT, chosen)
                    end })
            else
                missing.dundun = L["지금 풍요 지점을 몰라서."]
            end
        end
        if want("delvebot") and DB.settings.travelDelveBotOn and TV.HasToy(TV.DBOT.item) then
            local d = TV.HasLabChip() and ((DB.travelDest and DB.travelDest.delvebot) or WorldPos(TV.DBOT.map, TV.DBOT.x, TV.DBOT.y))
            if d and d.c and d.x and d.y then
                local remain = TV.ItemCD(TV.DBOT.item)
                table.insert(list, { key = "delvebot", label = TV.NAMES.delvebot, dest = { c = d.c, x = d.x, y = d.y },
                    cost = TELE_COST, tokens = 1, remain = remain, cdLen = TV.DBOT.cd, usable = TV.CDUsable(now + (remain or 0), TV.DBOT.cd) })
            elseif DB.delveBotLab == false then
                missing.delvebot = L["로봇 선택지에 킨도잔의 미궁이 없어서 (미궁 업데이트 칩이 필요합니다)."]
            elseif not DB.delveBotLab then
                missing.delvebot = L["미궁 칩이 있는지 아직 몰라서. 구렁로봇에게 한 번 말을 걸면 기억합니다."]
            end
        end
        return list, why, missing
    end

    -- 순서를 정한 경로(order)에 귀환형 이동을 넣을 자리들: { { k = 목적지 번호, m = 이동, path = 도착점에서 갈 포탈들, save }, ... } (k 순)
    -- 줄어드는 양이 큰 구간부터, 그 시각에 쓸 수 있으면 넣는다 (한 구간에는 하나만)
    -- 두 번째 반환값: 귀환석을 하나도 넣지 않았을 때 그 이유 (설정을 껐거나 내 위치를 모르면 nil)
    -- 세 번째 반환값: 목록(methods)에 있는데 넣지 않은 수단과 이유 { { key, text }, ... } (넣지 않은 이유 알리기, 2026-11-08)
    function TV.PlanRecalls(order, start, methods, why)
        if not start or #order == 0 then
            return {}, nil, {}
        end
        local legs, before, sum, prevPos = {}, {}, 0, start
        for k, p in ipairs(order) do
            legs[k] = TravelCost(prevPos, p.pos)
            before[k] = sum
            sum = sum + legs[k]
            prevPos = p.pos
        end
        local cands = {}
        for k, p in ipairs(order) do
            for mi, m in ipairs(methods) do
                local alt, path = TravelCost(m.dest, p.pos)
                local save = legs[k] - (alt + m.cost)
                if save >= (m.minSave or HEARTH_MIN_SAVE) and not (k == 1 and m.notFromStart) then
                    table.insert(cands, { k = k, m = m, mi = mi, path = path, save = save })
                end
            end
        end
        table.sort(cands, function(a, b)
            if a.save ~= b.save then
                return a.save > b.save
            end
            if a.k ~= b.k then
                return a.k < b.k
            end
            return a.mi < b.mi
        end)
        -- 대기시간이 짧은 수단 우선 (2026-11-08 사용자 결정): 같은 구간에서 가장 많이 줄어드는 수단(best)보다 30초 안으로 덜 줄어드는,
        -- 대기시간(m.cdLen)이 더 짧은 수단이 있으면 그것을 best 바로 앞에서 본다 (그중 가장 많이 줄어드는 것 하나).
        -- 그 수단을 그 시각에 쓸 수 없으면 원래 순서대로 best를 본다. 고른 것에는 c.pref = { over = best 키, sec = 차이 초 }
        -- best를 어차피 다른 구간에서 쓰게 되면 아낄 것이 없으니 그 구간은 우선하지 않고 다시 고른다 (noPref, 최대 구간 수만큼).
        -- 고른 결과들 중 줄어드는 양이 가장 큰 것을 쓴다 (다시 고른 것이 늘 빠르지는 않다: 한 번씩만 쓰는 수단의 자리가 바뀌므로)
        -- (2026-11-08 게임: 줄아만 퀘스트에 8시간짜리 쐐기 포탈이 1시간짜리 구렁로봇보다 약 15초 빨라 쐐기 포탈이 들어갔다)
        local PREF_SAVE = 30 * NAV_SPEED
        local now = time()
        local noPref = {}
        local chosen, legUsed, total, times, seen, best
        for _ = 1, #order + 1 do
            local bestOn, prefOn = {}, {}
            for _, c in ipairs(cands) do
                c.rank, c.prefOver, c.pref, c.t = c.save, nil, nil, nil
                local b = bestOn[c.k]
                if not b then
                    bestOn[c.k] = c
                elseif not noPref[c.k] and not prefOn[c.k] and c.m.cdLen and b.m.cdLen and c.m.cdLen < b.m.cdLen
                    and b.save - c.save <= PREF_SAVE then
                    prefOn[c.k] = c
                    c.rank = b.save + 0.001
                    c.prefOver = b
                end
            end
            table.sort(cands, function(a, b)
                if a.rank ~= b.rank then
                    return a.rank > b.rank
                end
                if a.k ~= b.k then
                    return a.k < b.k
                end
                if a.save ~= b.save then
                    return a.save > b.save
                end
                return a.mi < b.mi -- 똑같으면 수단 목록 순 (정렬이 매번 같게)
            end)
            chosen, legUsed, total = {}, {}, 0
            times = {} -- 이동별로 고른 사용 시각
            -- 수단별로 넣지 않은 이유를 가리려고 남기는 것 (2026-11-08):
            --   worth 15초 이상 줄어드는 구간이 있었나 / ready 그중 쓸 수 있는 시각인 곳이 있었나 /
            --   taken 쓸 수 있었으나 그 구간에 더 많이 줄어드는 다른 수단이 먼저 들어갔나 / keep 귀환석 1회 남기기 때문에 못 넣었나 /
            --   prefBy 대기시간이 짧은 수단에 그 구간을 내주었나
            seen = {}
            for _, c in ipairs(cands) do
                local key = c.m.key
                times[key] = times[key] or {}
                seen[key] = seen[key] or {}
                local s = seen[key]
                s.worth = true
                local t = now + before[c.k] / NAV_SPEED + (c.k - 1) * NAV_HANDLE
                local endT = now + (sum - total - c.save) / NAV_SPEED + #order * NAV_HANDLE
                local usable, keep = c.m.usable(t, endT, times[key]) -- 부작용 없는 판정이라 이미 쓴 구간에도 물어본다
                if usable then
                    s.ready = true
                end
                if legUsed[c.k] then
                    if usable then
                        s.taken = true
                        if legUsed[c.k].prefOver == c then
                            s.prefBy = legUsed[c.k]
                        end
                    end
                elseif usable and keep then
                    legUsed[c.k] = c
                    total = total + c.save
                    c.t = t
                    -- best도 그때 쓸 수 있었을 때만 "대기시간 때문에 골랐다"로 남긴다 (어차피 못 쓰는 것보다 우선한 것은 아니므로)
                    local b = c.prefOver
                    if b and b.m.usable(t, endT, times[b.m.key] or {}) then
                        c.pref = { over = b.m.key, sec = math.floor((b.save - c.save) / NAV_SPEED + 0.5) }
                    else
                        c.prefOver = nil
                    end
                    table.insert(times[key], t)
                    table.insert(chosen, c)
                elseif usable then
                    s.keep = true
                end
            end
            -- 이번 결과를 남긴다 (다시 고른 결과가 더 느리면 이쪽을 쓴다)
            local snap = { chosen = chosen, total = total, seen = seen, vals = {} }
            for i, c in ipairs(chosen) do
                snap.vals[i] = { t = c.t, pref = c.pref }
            end
            if not best or total >= best.total then
                best = snap
            end
            -- 우선해서 아낀 수단(best)을 다른 구간에서 썼으면 그 구간은 우선을 풀고 다시 고른다
            local usedKey, redo = {}, false
            for _, c in ipairs(chosen) do
                usedKey[c.m.key] = true
            end
            for _, c in ipairs(chosen) do
                if c.pref and usedKey[c.pref.over] and not noPref[c.k] then
                    noPref[c.k] = true
                    redo = true
                end
            end
            if not redo then
                break
            end
        end
        -- 줄어든 양이 가장 큰 결과 (같으면 나중 것). 아낀 수단을 결국 다른 구간에서 썼으면 "대기시간 때문에 골랐다" 표지는 지운다
        chosen, total, seen = best.chosen, best.total, best.seen
        local usedKey = {}
        for i, c in ipairs(chosen) do
            c.t, c.pref = best.vals[i].t, best.vals[i].pref
            usedKey[c.m.key] = true
        end
        for _, c in ipairs(chosen) do
            if c.pref and usedKey[c.pref.over] then
                c.pref = nil
            end
        end
        -- 귀환석 1회 남기기: 다 고른 뒤 끝나는 시각이 당겨졌으니 다시 확인하고, 안 되면 덜 줄어드는 귀환석부터 뺀다
        if not DB.settings.hearthKeepOff then
            for _ = 1, #chosen do
                local hs, st, weakest = {}, nil, nil
                for i, c in ipairs(chosen) do
                    if c.m.key == "hearth" then
                        st = c.m.st
                        table.insert(hs, c.t)
                        if not weakest or c.save < chosen[weakest].save then
                            weakest = i
                        end
                    end
                end
                if not st then
                    break
                end
                local all = {}
                for _, u in ipairs(st.uses) do
                    table.insert(all, u)
                end
                for _, u in ipairs(hs) do
                    table.insert(all, u)
                end
                table.sort(all)
                local endT = now + (sum - total) / NAV_SPEED + #order * NAV_HANDLE
                if HearthCharges(st, all, endT) >= 1 then
                    break
                end
                total = total - chosen[weakest].save
                table.remove(chosen, weakest)
                seen.hearth.keep = true
            end
        end
        table.sort(chosen, function(a, b) return a.k < b.k end)
        -- 넣지 않은 수단과 그 이유 (수단 목록 순): { { key, text }, ... }
        local used = {}
        for _, c in ipairs(chosen) do
            used[c.m.key] = true
        end
        local reasons, hearthWhy = {}, nil
        for _, m in ipairs(methods) do
            if not used[m.key] then
                local s = seen[m.key] or {}
                local text
                if not s.worth then
                    text = L["%d초 이상 빨라지는 구간이 없어서."]:format(math.floor((m.minSave or HEARTH_MIN_SAVE) / NAV_SPEED + 0.5))
                elseif s.keep then
                    text = L["마칠 때 1회 남기기 때문에. 지금 쓰면 다 마칠 때까지 쿨타임이 끝나지 않습니다. (설정에서 끌 수 있습니다)"]
                elseif s.prefBy and s.prefBy.pref then
                    -- 차이가 1초 미만이면 "약 0초" 대신 "거의 같아서" (2026-11-08 게임: 줄아만 91801은 두 도착점에서 거리가 약 10야드 차이)
                    local obj = TV.OBJ[s.prefBy.m.key] or s.prefBy.m.key
                    text = (s.prefBy.pref.sec < 1) and L["줄어드는 시간이 거의 같아서 쿨타임이 짧은 %s 대신 넣어서."]:format(obj)
                        or L["줄어드는 시간 차이가 약 %d초뿐이라 쿨타임이 짧은 %s 대신 넣어서."]:format(s.prefBy.pref.sec, obj)
                elseif s.taken then
                    text = L["그 구간에는 더 많이 줄어드는 다른 수단을 넣어서."]
                elseif m.remain and m.remain > 0 then
                    local left = math.ceil(m.remain / 60)
                    text = (left >= 60) and L["쿨타임 중이라서 (약 %d시간 %d분 남음)."]:format(math.floor(left / 60), left % 60)
                        or L["쿨타임 중이라서 (약 %d분 남음)."]:format(left)
                else
                    text = L["경로에서 쓸 차례에 쓸 수 없어서 (쿨타임이나 끝나는 시각)."]
                end
                table.insert(reasons, { key = m.key, text = text })
                if m.key == "hearth" then
                    hearthWhy = text
                end
            end
        end
        -- 두 번째 반환값(예전 형식): 아무것도 넣지 않았을 때 귀환석 이유. 귀환 지점을 몰라 목록에 없으면 받은 why
        if #chosen > 0 then
            hearthWhy = nil
        elseif not hearthWhy then
            hearthWhy = why
        end
        return chosen, hearthWhy, reasons
    end

    -- 귀환석만 넣는 자리 (예전 1단계 형식, 시뮬레이션 테스트용): { k, path, save, bind } 또는 nil과 이유
    local function PlanHearth(order, start)
        if DB.settings.hearthOff or not start or #order == 0 then
            return nil
        end
        local methods, why = TV.RecallMethods({ hearth = true })
        local uses, whyNot = TV.PlanRecalls(order, start, methods, why)
        local u
        for _, c in ipairs(uses) do
            if not u or c.save > u.save then
                u = c
            end
        end
        if u then
            return { k = u.k, path = u.path, save = u.save, bind = u.m.dest }
        end
        return nil, whyNot
    end
    QTR.PlanHearth = PlanHearth

    -- 귀환석 사용 감지: 귀환석이나 귀환석 장난감의 주문이거나, 귀환석 대기시간이 막 시작됐으면 귀환석으로 본다
    -- 시전 성공 이벤트 때는 아직 대기시간이 잡혀 있지 않다 (2026-10-24 게임 기록에서 대기시간 길이가 남지 않아 확인).
    -- 그래서 0.5초 뒤 대기시간을 다시 보고, 대기시간 길이는 1초 뒤에 읽는다. 장난감은 주문 ID가 달라 대기시간으로만 알 수 있다.
    -- 시전한 곳은 이벤트 때 읽어 둔다 (그 뒤 바로 순간이동하므로)
    local lastHearthUse = 0
    local function HearthJustStarted()
        local remain, _, start = HearthItemCooldown()
        return remain and remain > 0 and start and (GetTime() - start) < 3
    end

    -- 사용 시각과 대기시간을 기억하고, 순간이동해서 내린 곳을 귀환 지점으로 기억한다
    local function OnHearthUsed(from)
        local me = MyChar()
        local now = time()
        if not me or now - lastHearthUse < 10 then
            return -- 같은 시전을 두 번 세지 않는다
        end
        lastHearthUse = now
        local uses = {}
        for _, u in ipairs(me.hearthUses or {}) do
            if now - u < 7200 then
                table.insert(uses, u)
            end
        end
        table.insert(uses, now)
        me.hearthUses = uses
        -- 대기시간 길이: 쓴 직후에는 아직 안 잡혀 있을 수 있어 1초, 3초, 6초 뒤에 다시 읽는다
        C_Timer.After(1, LearnHearthCD)
        C_Timer.After(3, LearnHearthCD)
        C_Timer.After(6, LearnHearthCD)
        -- 내린 곳: 시전한 곳에서 JUMP 넘게 떨어졌거나 다른 대륙이면 그곳 (0.5초마다 최대 30초)
        local tries = 0
        local function Poll()
            tries = tries + 1
            local p = PlayerPos()
            if p and from and (p.c ~= from.c or Dist(p, from) > JUMP) then
                local name = BindName()
                if not name then
                    return
                end
                local old = TV.SaveBind(name, p)
                if not old then
                    Print(L["귀환 지점을 기억했습니다: %s. 이 여관을 귀환 지점으로 쓰는 모든 캐릭터의 내비게이션 동선에 귀환석을 넣을 수 있습니다."]:format(name))
                end
                return
            end
            if tries < 60 then
                C_Timer.After(0.5, Poll)
            end
        end
        C_Timer.After(0.5, Poll)
    end

    -- 순간이동해서 내린 곳을 본다: 시전한 곳(from)에서 JUMP 넘게 떨어졌거나 다른 대륙으로 옮겨질 때마다 한 번으로 세고,
    -- jumps번째 옮겨진 곳을 onLand(위치)로 알린다 (아르칸티나 열쇠는 들어갔다 나오므로 2번째). 0.5초마다 tries번까지 본다
    function TV.LearnLanding(from, jumps, tries, onLand)
        local n, last = 0, from
        local function Poll()
            tries = tries - 1
            local p = PlayerPos()
            if p and last and (p.c ~= last.c or Dist(p, last) > JUMP) then
                n = n + 1
                last = p
                if n >= jumps then
                    onLand(p)
                    return
                end
            elseif p and not last then
                last = p
            end
            if tries > 0 then
                C_Timer.After(0.5, Poll)
            end
        end
        C_Timer.After(0.5, Poll)
    end

    -- 영혼의 귀환, 아르칸티나 열쇠, 마법사 실버문 순간이동을 썼을 때: 대기시간 길이와 내린 곳을 기억한다
    function TV.OnTravelCast(spellID, from)
        local me = MyChar()
        if not me then
            return false
        end
        DB.travelDest = DB.travelDest or {}
        local function save(key)
            return function(p)
                DB.travelDest[key] = { c = p.c, x = p.x, y = p.y, t = time() }
            end
        end
        if spellID == ASTRAL_SPELL then
            -- 대기시간 길이는 쓴 직후에 아직 안 잡혀 있을 수 있어 몇 초 뒤에 읽는다. 내린 곳은 귀환 지점이라 귀환석과 같이 기억한다
            local function learn()
                local remain, duration = TV.SpellCD(ASTRAL_SPELL)
                if remain and remain > 0 and duration and duration > 60 then
                    me.astralCD = duration
                end
            end
            C_Timer.After(1, learn)
            C_Timer.After(3, learn)
            TV.LearnLanding(from, 1, 60, function(p)
                local name = BindName()
                if name then
                    TV.SaveBind(name, p)
                end
            end)
            return true
        end
        if spellID == TV.ArcSpell() or spellID == ARC_SPELL then
            -- 아르칸티나에 들어가는 것이 첫 번째, 나가는 차원문을 타고 실버문에 서는 것이 두 번째 순간이동 (3분까지 기다린다)
            TV.LearnLanding(from, 2, 360, save("arcantina"))
            return true
        end
        if spellID == MAGE_SPELL or (mageTele and spellID == mageTele.spell) then
            -- 내린 곳이 실측 위치 가까이일 때만 기억한다 (다른 곳이면 TV.MageDest가 지운다)
            TV.LearnLanding(from, 1, 60, save("mage"))
            return true
        end
        if spellID == TV.ROOT.spell then
            -- 뿌리걸음: 하란다르와 같은 대륙에 내렸을 때만 요람으로 기억한다 (세계수 뿌리 곁에서 써서 다른 대륙으로 갔으면 기억하지 않는다)
            TV.LearnLanding(from, 1, 60, function(p)
                local h = WorldPos(TV.ROOT.map, 0.5, 0.5)
                if h and p.c == h.c then
                    save("root")(p)
                end
            end)
            return true
        end
        if spellID == TV.MAI.spell then
            return true -- 마이사라 동굴 순간이동: 내리는 곳은 실측 위치로 정해 두어 기억할 것이 없다
        end
        if spellID == TV.DBOT.spell then
            -- 구렁로봇 소환: 대화창에서 미궁을 자동으로 고를지 판단할 때 쓴다 (TV.OnGossip). 말을 걸고 고르는 동안까지 1분 기다리며
            -- 미궁 입구 가까이(실측 위치에서 JUMP 안)에 내렸을 때만 그 자리를 기억한다 (다른 구렁을 고른 경우는 기억하지 않는다)
            TV.dbotAt = GetTime()
            local est = WorldPos(TV.DBOT.map, TV.DBOT.x, TV.DBOT.y)
            TV.LearnLanding(from, 1, 120, function(p)
                if est and p.c == est.c and Dist(p, est) < JUMP then
                    DB.travelDest.delvebot = { c = p.c, x = p.x, y = p.y, t = time() }
                end
            end)
            return true
        end
        if spellID == TV.DunSpell() or spellID == TV.DUN.spell then
            -- 둔둔 장난감: 쓴 때의 풍요 지점(POI)별로 실제로 내린 곳을 기억한다
            local ab = TV.Abundance()
            if ab then
                TV.LearnLanding(from, 1, 60, function(p)
                    DB.travelDest.dundun = DB.travelDest.dundun or {}
                    DB.travelDest.dundun[ab.poi] = { c = p.c, x = p.x, y = p.y, t = time() }
                end)
            end
            return true
        end
        return false
    end

    function QTR.OnPlayerSpellcast(spellID)
        if InCombatLockdown() then
            return -- 귀환석은 전투 중에 쓸 수 없다
        end
        local from = PlayerPos()
        local okId, isHearthId = pcall(IsHearthSpell, spellID)
        if (okId and isHearthId) or HearthJustStarted() then
            OnHearthUsed(from)
            TV.OnUsed()
            return
        end
        local okTravel, isTravel = pcall(TV.OnTravelCast, spellID, from)
        if okTravel and isTravel then
            TV.OnUsed()
            return
        end
        C_Timer.After(0.5, function()
            if HearthJustStarted() then
                OnHearthUsed(from)
                TV.OnUsed()
            end
        end)
    end

    local spellWatch = CreateFrame("Frame")
    if spellWatch.RegisterUnitEvent then
        spellWatch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    end
    spellWatch:SetScript("OnEvent", function(_, _, _, _, spellID)
        pcall(QTR.OnPlayerSpellcast, spellID)
    end)

    -- 다른 애드온(HDT 꿀구렁 등)이 구렁로봇 선택지를 자동으로 고르기 전에 물어볼 수 있는 신호 (2026-11-08 사용자 요청):
    --   QTR이 지금 미궁(142847)을 고르려 하면 true. 내비게이션의 지금 단계가 구렁로봇이고, 1분 안에 장난감을 썼고, 설정이 켜져 있을 때
    --   (Shift는 여기서 보지 않는다. Shift를 누르면 QTR도 고르지 않으니, 그때 다른 애드온이 고를지는 그 애드온이 정한다)
    function QuestsToRiches_WantsDelveBotLabyrinth()
        local r = QTR.route and QTR.route[1]
        return (DB and DB.settings.travelDelveBotOn and r and r.travel == "delvebot" and TV.dbotAt
            and (GetTime() - TV.dbotAt) < 60) and true or false
    end

    -- 구렁로봇 대화창: 미궁 칩을 배우고 (선택지 142847이 있는가), 위 신호가 켜져 있고 Shift를 누르지 않았으면 미궁을 고른다
    function TV.OnGossip()
        local guid = UnitGUID and UnitGUID("npc")
        local npc = type(guid) == "string" and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        if npc ~= TV.DBOT.npc or not (C_GossipInfo and C_GossipInfo.GetOptions) then
            return
        end
        local opts = C_GossipInfo.GetOptions() or {}
        if #opts == 0 then
            return -- 선택지를 읽지 못했으면 (다른 애드온이 먼저 골라 닫힌 대화창 등) 배우지 않는다
        end
        local has = false
        for _, o in ipairs(opts) do
            if o.gossipOptionID == TV.DBOT.option then
                has = true
            end
        end
        -- 계정에서 한 번 본 칩은 그대로 둔다 (없음으로 바꾸지 않는다). 본 적이 없을 때만 false
        if has then
            DB.delveBotLab = time()
        elseif not TV.HasLabChip() then
            DB.delveBotLab = false
        end
        -- 한 번 쓴 장난감에 한 번만 고른다 (dbotPicked). 신호(dbotAt)는 1분 동안 그대로 두어, 같은 대화창 이벤트를 QTR보다
        -- 늦게 받는 다른 애드온도 "QTR이 미궁을 골랐다"는 것을 알고 자기 선택을 건너뛸 수 있게 한다
        if has and QuestsToRiches_WantsDelveBotLabyrinth() and TV.dbotPicked ~= TV.dbotAt
            and not (IsShiftKeyDown and IsShiftKeyDown()) and C_GossipInfo.SelectOption then
            TV.dbotPicked = TV.dbotAt
            C_GossipInfo.SelectOption(TV.DBOT.option)
        end
    end
    QTR.TestOnGossip = TV.OnGossip -- 테스트에서 대화창 열림을 흉내 낼 때
    local gossipWatch = CreateFrame("Frame")
    gossipWatch:RegisterEvent("GOSSIP_SHOW")
    gossipWatch:SetScript("OnEvent", function()
        if DB then
            pcall(TV.OnGossip)
        end
    end)

    -- /qtr hearth: 귀환석 상태 (귀환 지점, 대기시간, 지금 충전 수)
    function QTR.HearthStatus()
        local h, name = HearthBind(), BindName()
        local st = HearthState()
        local now = time()
        Print(L["귀환 지점: "] .. tostring(name or L["확인 불가"])
            .. (h and L[" (위치 기억함)"] or L[" (위치 모름: 귀환석을 한 번 타면 기억합니다)"]))
        Print(L["쿨타임 %d분, 최대 충전 %d회, 지금 쓸 수 있는 충전 %d회"]:format(math.floor(st.cd / 60), st.maxCh,
            (now < st.blocked) and 0 or HearthCharges(st, st.uses, now))
            .. ((now < st.blocked) and L[" (%d분 뒤)"]:format(math.ceil((st.blocked - now) / 60)) or ""))
        Print(L["동선에 넣기: "] .. (DB.settings.hearthOff and L["끔"] or L["켬"])
            .. L[", 마지막에 1회 남기기: "] .. (DB.settings.hearthKeepOff and L["끔"] or L["켬"]))
        -- 2단계 이동 기술: 이 캐릭터가 쓸 수 있는지와 대기시간
        TV.RefreshMage()
        local okClass, _, class = pcall(UnitClass, "player")
        if okClass and class == "MAGE" then
            Print(L["마법사 실버문 순간이동: "] .. (DB.settings.travelMageOff and L["설정에서 끔"]
                or (mageTele and L["찾음 (%s)"]:format(tostring(TV.SpellName(mageTele.spell) or mageTele.spell))
                or L["아직 배우지 않음 (한밤 실버문 순간이동을 배우면 동선에 넣습니다)"])))
        end
        if TV.SpellKnown(TV.ROOT.spell) then
            Print(L["뿌리걸음: "] .. (DB.settings.travelRootOff and L["설정에서 끔"]
                or ((DB.travelDest and DB.travelDest.root) and L["켬 (요람 위치 기억함)"]
                or L["켬, 요람 위치는 어림 (하란다르의 세계수 뿌리에서 떨어진 곳에서 한 번 쓰면 실제로 내린 곳을 기억합니다)"]))
                .. (TV.RootReturning() and L[" / 지금 뿌리걸음: 귀환 상태 (요람까지 두 번 써야 해서 비용을 두 배로 봅니다)"] or ""))
        end
        if TV.SpellKnown(ASTRAL_SPELL) then
            local remain = TV.SpellCD(ASTRAL_SPELL)
            local me = MyChar() or {}
            Print(L["영혼의 귀환: "] .. (DB.settings.travelAstralOff and L["설정에서 끔"] or L["켬"])
                .. L[", 쿨타임 %d분"]:format(math.floor((me.astralCD or ASTRAL_CD) / 60))
                .. ((remain and remain > 0) and L[" (%d분 뒤 사용 가능)"]:format(math.ceil(remain / 60)) or ""))
        end
        if TV.HasToy(ARC_ITEM) then
            local remain = TV.ItemCD(ARC_ITEM)
            local known = (DB.travelDest and DB.travelDest.arcantina) or (DB.hearthBinds and DB.hearthBinds[ARC_INN])
            Print(L["아르칸티나 열쇠: "] .. (DB.settings.travelArcantinaOff and L["설정에서 끔"] or L["켬"])
                .. (known and "" or L[", 나오는 곳(%s) 위치 모름: 한 번 쓰거나 그 여관으로 귀환석을 타면 기억합니다"]:format(ARC_INN))
                .. ((remain and remain > 0) and L[", %d분 뒤 사용 가능"]:format(math.ceil(remain / 60)) or ""))
        end
        if TV.SpellKnown(TV.MAI.spell) then
            local remain = TV.SpellCD(TV.MAI.spell)
            local left = math.ceil((remain or 0) / 60) -- 대기시간이 8시간이라 1시간이 넘으면 시간과 분으로
            Print(L["마이사라 동굴 순간이동: "] .. (DB.settings.travelMaisaraOn and L["켬"] or L["설정에서 끔"])
                .. ((left >= 60) and L[", %d시간 %d분 뒤 사용 가능"]:format(math.floor(left / 60), left % 60)
                    or (left > 0) and L[", %d분 뒤 사용 가능"]:format(left) or ""))
        end
        if TV.HasToy(TV.DBOT.item) then
            local remain = TV.ItemCD(TV.DBOT.item)
            Print(L["구렁로봇 7001 (킨도잔의 미궁): "] .. (DB.settings.travelDelveBotOn and L["켬"] or L["설정에서 끔"])
                .. ((TV.HasLabChip() and "") or (DB.delveBotLab == false and L[", 미궁 칩 없음"])
                    or L[", 미궁 칩 모름 (로봇에게 한 번 말을 걸면 기억합니다)"])
                .. ((remain and remain > 0) and L[", %d분 뒤 사용 가능"]:format(math.ceil(remain / 60)) or ""))
        end
        -- 장난감이 없어도 설정을 켰으면 보인다 (풍요 지점과 남은 시간을 제대로 읽는지 확인할 수 있게. 2026-11-07 사용자 확인 요청)
        local hasDun = TV.HasToy(TV.DUN.item)
        if hasDun or DB.settings.travelDundunOn then
            local remain = hasDun and TV.ItemCD(TV.DUN.item)
            local ab = TV.Abundance()
            local where = L["지금 풍요 지점 확인 불가"]
            if ab then
                local leftMin = ab.expire and math.max(0, math.ceil((ab.expire - time()) / 60))
                where = L["지금 풍요 지점: "] .. tostring(ab.name) .. (ab.zone and (" (" .. ab.zone .. ")") or "")
                    .. (leftMin and L[", %d시간 %d분 남음"]:format(math.floor(leftMin / 60), leftMin % 60) or L[", 남은 시간 확인 불가"])
                    .. ((DB.travelDest and DB.travelDest.dundun and DB.travelDest.dundun[ab.poi]) and ""
                        or L[", 내리는 곳은 아이콘 위치로 어림 (한 번 쓰면 기억합니다)"])
            end
            Print(L["둔둔 장난감: "] .. (not hasDun and L["없음 (장난감이 있어야 동선에 넣습니다)"]
                or DB.settings.travelDundunOn and L["켬"] or L["설정에서 끔"])
                .. ((remain and remain > 0) and L[", %d분 뒤 사용 가능"]:format(math.ceil(remain / 60)) or "") .. ". " .. where)
        end
    end

    local function HasTomTom()
        return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
    end

    local function EntryKey(r)
        return r and (r.questID and ("q" .. r.questID) or (r.travel and ("t" .. r.travel)) or ("p" .. tostring(r.portal)))
    end

    -- 지금 경로의 첫 목적지를 안내한다 (TomTom 화살표 또는 게임 웨이포인트)
    local function PointFirst()
        local r = QTR.route and QTR.route[1]
        if not r or r.travel then
            return -- 귀환석, 순간이동 등은 어디서든 쓰므로 가리킬 곳이 없다 (내비게이션 문구와 사용 버튼 창으로 안내한다)
        end
        if r.uid and HasTomTom() and TomTom.SetCrazyArrow then
            pcall(TomTom.SetCrazyArrow, TomTom, r.uid, 15, r.label)
        elseif not r.uid then
            -- 목적지 안내는 내비게이션 문구가 대신한다
            QTR.SetWaypoint(r.questID or ("portal" .. r.portal), r.label, r.wp, nil, true)
        end
    end

    ---------------------------------------------------------------------------
    -- 이동 기술 사용 창 (정점 보관함 알림창과 같은 모양): 다음 목적지가 귀환석, 영혼의 귀환, 아르칸티나 열쇠,
    -- 마법사 순간이동이면 띄우고, 누르면 그것을 쓴다 (보안 버튼). 위쪽 띠로 옮기고, 닫으면 그 단계 동안은 다시 띄우지 않는다.
    -- 보안 버튼이라 전투 중에는 내용과 표시를 바꿀 수 없어 전투가 끝난 뒤 고친다. 설정 travelPopupOff로 끈다
    ---------------------------------------------------------------------------
    local ta = CreateFrame("Frame", "QuestsToRichesTravelAlert", UIParent)
    ta:SetSize(290, 66)
    ta:SetFrameStrata("HIGH")
    ta:SetMovable(true)
    ta:SetClampedToScreen(true)
    ta:Hide()
    local taBg = ta:CreateTexture(nil, "BACKGROUND")
    taBg:SetAllPoints(ta)
    taBg:SetColorTexture(0, 0, 0, 0.85)
    local taHandle = CreateFrame("Frame", nil, ta)
    taHandle:SetPoint("TOPLEFT", ta, "TOPLEFT", 0, 0)
    taHandle:SetPoint("TOPRIGHT", ta, "TOPRIGHT", 0, 0)
    taHandle:SetHeight(18)
    taHandle:EnableMouse(true)
    taHandle:RegisterForDrag("LeftButton")
    taHandle:SetScript("OnDragStart", function()
        ta:StartMoving()
    end)
    taHandle:SetScript("OnDragStop", function()
        ta:StopMovingOrSizing()
        local point, _, relativePoint, x, y = ta:GetPoint()
        DB.settings.travelAlertPos = { point, relativePoint, x, y }
    end)
    local taTitle = taHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    taTitle:SetPoint("LEFT", taHandle, "LEFT", 8, -2)
    taTitle:SetText(L["골드퀘 내비게이션 다음 이동"])
    local taClose = CreateFrame("Button", nil, ta, "UIPanelCloseButton")
    taClose:SetSize(22, 22)
    taClose:SetPoint("TOPRIGHT", ta, "TOPRIGHT", 2, 2)
    taClose:SetScript("OnClick", function()
        TV.closedKey = TV.shownKey -- 이 단계 동안은 다시 띄우지 않는다
        if not InCombatLockdown() then
            ta:Hide()
        end
    end)
    local tb = CreateFrame("Button", "QuestsToRichesTravelButton", ta, "SecureActionButtonTemplate")
    tb:SetPoint("TOPLEFT", ta, "TOPLEFT", 0, -18)
    tb:SetPoint("BOTTOMRIGHT", ta, "BOTTOMRIGHT", 0, 0)
    tb:RegisterForClicks("AnyUp", "AnyDown")
    local tbHi = tb:CreateTexture(nil, "HIGHLIGHT")
    tbHi:SetAllPoints(tb)
    tbHi:SetColorTexture(1, 1, 1, 0.08)
    tb.icon = tb:CreateTexture(nil, "ARTWORK")
    tb.icon:SetSize(36, 36)
    tb.icon:SetPoint("LEFT", tb, "LEFT", 10, 0)
    tb.text = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tb.text:SetPoint("LEFT", tb.icon, "RIGHT", 10, 0)
    tb.text:SetJustifyH("LEFT")
    tb.measure = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- 줄마다 너비를 재는 숨긴 글자
    tb.measure:Hide()

    function TV.PlaceAlert()
        ta:ClearAllPoints()
        local p = DB.settings.travelAlertPos
        if p then
            ta:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        else
            ta:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        end
    end
    QTR.ResetTravelAlertPos = function()
        DB.settings.travelAlertPos = nil
        TV.PlaceAlert()
    end

    -- 경로 항목 r을 쓰는 버튼 설정: 보안 버튼 속성(type과 주문/아이템/장난감), 아이콘. 쓸 것이 없으면 nil
    function TV.SpellIcon(id)
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, icon = pcall(C_Spell.GetSpellTexture, id)
            if ok then
                return icon
            end
        end
        return nil
    end
    function TV.ButtonAction(r)
        local key = r.travel
        if (key == "mage" or key == "root") and r.spell then
            return { type = "spell", spell = r.spell }, TV.SpellIcon(r.spell)
        elseif key == "astral" then
            return { type = "spell", spell = ASTRAL_SPELL }, TV.SpellIcon(ASTRAL_SPELL)
        elseif key == "arcantina" then
            return { type = "toy", toy = ARC_ITEM }, GetItemIconSafe(ARC_ITEM)
        elseif key == "maisara" then
            return { type = "spell", spell = TV.MAI.spell }, TV.SpellIcon(TV.MAI.spell)
        elseif key == "dundun" then
            return { type = "toy", toy = TV.DUN.item }, GetItemIconSafe(TV.DUN.item)
        elseif key == "delvebot" then
            return { type = "toy", toy = TV.DBOT.item }, GetItemIconSafe(TV.DBOT.item)
        elseif key == "hearth" then
            -- 가방에 귀환석이 있으면 귀환석, 없으면 가진 귀환석 장난감 중 하나
            if GetItemCountSafe(HEARTH_ITEM) > 0 then
                return { type = "item", item = "item:" .. HEARTH_ITEM }, GetItemIconSafe(HEARTH_ITEM)
            end
            for _, id in ipairs(HEARTH_TOYS) do
                if TV.HasToy(id) then
                    return { type = "toy", toy = id }, GetItemIconSafe(id)
                end
            end
        end
        return nil
    end

    -- 지금 경로의 첫 단계에 맞춰 창을 띄우거나 숨긴다 (경로가 바뀔 때마다, 전투가 끝났을 때)
    function TV.UpdateButton()
        if InCombatLockdown() then
            TV.pending = true
            return
        end
        TV.pending = false
        local r = QTR.route and QTR.route[1]
        local key = r and r.travel and EntryKey(r) .. ":" .. tostring(r.arrival and r.arrival.x)
        local off = DB.settings.travelPopupOff
        if not QTR.route and TV.finish then
            -- 내비게이션을 모두 마친 뒤의 귀환 버튼 (TV.ShowFinish)
            r, key, off = TV.finish, "finish:" .. TV.finish.travel, DB.settings.finishPopupOff
        end
        local attrs, icon
        -- 이미 쓴 단계(시전 성공)와 아르칸티나 안에서 기다리는 중에는 띄우지 않는다 (2026-10-26: 아르칸티나에 들어간 뒤 또 떠서 눌러 보면 대기시간 중이었다)
        if r and r.travel and not r.inside and not off and key ~= TV.closedKey then
            attrs, icon = TV.ButtonAction(r)
        end
        if not attrs then
            TV.shownKey = nil
            ta:Hide()
            return
        end
        for _, a in ipairs({ "spell", "item", "toy" }) do
            tb:SetAttribute(a, attrs[a])
        end
        tb:SetAttribute("type", attrs.type)
        tb.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Rune_01")
        -- 구렁로봇은 쓴 뒤 로봇에게 말을 걸어야 한다 (말을 걸면 미궁을 자동으로 고른다)
        local hint = (r.travel == "delvebot") and L["\n|cffffffff클릭한 뒤 로봇에게 말을 걸면 미궁으로 갑니다"]
            or (r.travel == "root" and r.twice and L["\n|cffffffff지금은 뿌리걸음: 귀환 상태라 먼저 직전 위치로 돌아갑니다.\n돌아간 뒤 한 번 더 누르면 요람으로 갑니다"])
            or L["\n|cffffffff클릭해서 사용"]
        local shown = tostring(r.label) .. hint .. (r == TV.finish and L[" (내비게이션 완료)"] or "") .. "|r"
        tb.text:SetText(shown)
        -- 글이 길면 창을 넓힌다 (2026-11-08: 구렁로봇 안내가 창 밖으로 넘쳤다). 아이콘 왼쪽 10 + 36 + 간격 10 + 오른쪽 여백 14
        local textW = 0
        for line in shown:gmatch("[^\n]+") do
            tb.measure:SetText(line)
            textW = math.max(textW, tb.measure:GetStringWidth() or 0)
        end
        ta:SetWidth(math.max(290, math.ceil(textW) + 70))
        TV.shownKey = key
        if not ta:IsShown() then
            TV.PlaceAlert()
        end
        ta:Show()
    end
    QTR.UpdateTravelButton = function()
        TV.UpdateButton()
    end
    -- 귀환석이나 이동 기술을 시전했으면 (창으로든 행동 단축바로든) 그 단계 동안 창을 다시 띄우지 않는다
    function TV.OnUsed()
        local r = QTR.route and QTR.route[1]
        if r and r.travel then
            TV.closedKey = EntryKey(r) .. ":" .. tostring(r.arrival and r.arrival.x)
            TV.UpdateButton()
        elseif not QTR.route and TV.finish then
            TV.finish = nil -- 마친 뒤 귀환 버튼: 썼으면 치운다
            TV.UpdateButton()
        end
    end

    -- 내비게이션을 모두 마쳤을 때 귀환 버튼 (2026-10-27 사용자 아이디어, 설정 finishPopupOff로 끈다)
    -- 지금 쓸 수 있는 것 하나: 실버문 순간이동(대기시간 없음), 영혼의 귀환, 귀환석, 아르칸티나 열쇠 순
    -- (귀환석은 "1회 남기기"로 아껴 둔 충전, 아르칸티나 열쇠는 로딩이 두 번이라 뒤에 둔다)
    -- 수단마다 설정에서 뺄 수 있다: finishMageOff, finishAstralOff, finishHearthOff, finishArcantinaOff
    -- 동선용 켜고 끄기 설정과는 따로 본다. 이미 그 도착지 가까이(JUMP 안)에 있으면 그 수단은 띄우지 않는다
    -- 쓸 수 있는 것이 없으면 아무것도 띄우지 않는다 (채팅 안내도 없음)
    function TV.FinishAction()
        local s = DB.settings
        local here = PlayerPos()
        local function near(dest)
            return here and dest and here.c == dest.c and Dist(here, dest) < JUMP
        end
        if not s.finishMageOff then
            local okClass, _, class = pcall(UnitClass, "player")
            if okClass and class == "MAGE" then
                local id = TV.SpellKnown(MAGE_SPELL) and MAGE_SPELL or TV.ScanMageTele()
                if id and not near(TV.MageDest()) then
                    return { travel = "mage", spell = id, label = (TV.TravelLabel("mage")) }
                end
            end
        end
        local bind = HearthBind()
        local bindName = BindName() or ""
        local atBind = bind and near(bind)
        if not s.finishAstralOff and not atBind and TV.SpellKnown(ASTRAL_SPELL) then
            local remain = TV.SpellCD(ASTRAL_SPELL)
            if not remain or remain == 0 then
                return { travel = "astral", label = (TV.TravelLabel("astral", bindName)) }
            end
        end
        if not s.finishHearthOff and not atBind then
            local st = HearthState()
            local now = time()
            if now >= st.blocked and HearthCharges(st, st.uses, now) >= 1 then
                local r = { travel = "hearth", label = (TV.TravelLabel("hearth", bindName)) }
                if TV.ButtonAction(r) then
                    return r
                end
            end
        end
        if not s.finishArcantinaOff and TV.HasToy(ARC_ITEM) then
            local d = (DB.travelDest and DB.travelDest.arcantina) or (DB.hearthBinds and DB.hearthBinds[ARC_INN])
            local remain = TV.ItemCD(ARC_ITEM)
            if (not remain or remain == 0) and not (d and near(d)) then
                return { travel = "arcantina", label = (TV.TravelLabel("arcantina", ARC_INN)) }
            end
        end
        return nil
    end
    function TV.ShowFinish()
        TV.finish = nil
        if DB.settings.finishPopupOff then
            return
        end
        local ok, r = pcall(TV.FinishAction)
        TV.finish = ok and r or nil
        TV.UpdateButton()
    end
    QTR.TravelButtonPending = function()
        return TV.pending
    end

    -- 순간이동 감시: 내비게이션 중 1초마다 위치를 본다
    local ticker
    local function StopTicker()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end

    -- 내비게이션을 모두 마쳤을 때 소리 ("Master" 채널: 소리 효과를 꺼 두어도 들린다)
    --   DBM이 있으면 DBM의 승리 팡파레 "SMG: FF Fanfare" (사용자의 DBM 폴더에 있는 파일을 재생만 한다)
    --   DBM이 없거나 그 파일을 재생하지 못하면 블리자드 보스 처치 배너 소리 (SOUNDKIT.UI_RAID_BOSS_DEFEATED = 50111)
    --   설정창의 "모두 완료 시 소리 재생"을 끄면 재생하지 않는다 (DB.settings.navSoundOff)
    local DBM_FANFARE = "Interface\\AddOns\\DBM-Core\\sounds\\Victory\\SmoothMcGroove_Fanfare.ogg"
    local function HasDBM()
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "DBM-Core")
            if ok and loaded then
                return true
            end
        end
        return type(DBM) == "table"
    end
    function QTR.PlayNavSound()
        if DB.settings.navSoundOff then
            return
        end
        if HasDBM() then
            local ok, willPlay = pcall(PlaySoundFile, DBM_FANFARE, "Master")
            if ok and willPlay then
                return
            end
        end
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_RAID_BOSS_DEFEATED) or 50111, "Master")
    end

    -- 내비게이션을 모두 마쳤을 때 (이번 안내에서 완료한 곳이 있을 때만):
    -- 마친 시각을 남기고(창에 소요 시간 등 결과 표시), 완료 소리를 내고(QTR.PlayNavSound), 내비게이션 창을 연다.
    -- 마지막 완료로 특별 과제가 열려 경로가 다시 생기면 이어 가고(QTR.navFinish를 지운다), 그 뒤 다 마치면 다시 알린다.
    -- 내비게이션 기록: 도착 예상 시각 어림값(NAV_SPEED, NAV_HANDLE)을 실제 기록으로 맞추려고 남긴다 (최근 10번)
    --   설정 navLogAll이 켜져 있으면 지우지 않는다 (/qtr navlog all, 개발 PC용. 2026-11-01 사용자 요청: 10번으로는 주말 기록이 모자람)
    -- DB.navLog = { { start = { t, c, x, y }, stops = { { q 또는 portal, t, c, x, y }, ... }, afk = { { s, e }, ... } }, ... }
    --   c, x, y: 그 순간의 월드 좌표 (대륙 ID, 야드)
    --   pref = { { t, key, over, sec }, ... }: 대기시간이 짧아서 over 대신 key를 넣었을 때 (계산상 sec초 느림, 2026-11-08)
    function QTR.NavLogStart()
        DB.navLog = DB.navLog or {}
        local p = PlayerPos()
        local run = { start = { t = time(), c = p and p.c, x = p and p.x, y = p and p.y }, stops = {} }
        table.insert(DB.navLog, run)
        while not DB.settings.navLogAll and #DB.navLog > 10 do
            table.remove(DB.navLog, 1)
        end
        QTR.navRun = run
    end
    local function NavLogStop(questID, portal)
        local run = QTR.navRun
        if not run then
            return
        end
        local p = PlayerPos()
        table.insert(run.stops, { q = questID, portal = portal, t = time(), c = p and p.c, x = p and p.x, y = p and p.y })
    end
    -- 자리비움 구간 (2026-11-02 사용자 요청: 골드퀘 중 자리를 자주 비워, 분석 때 그 구간을 빼려고): run.afk = { { s, e }, ... }
    --   PLAYER_FLAGS_CHANGED 때 부른다. 켜질 때 s, 꺼질 때 마지막 구간에 e. 끝나지 않은 구간(e 없음)은 회차 끝까지로 본다
    --   자동 자리비움은 입력 없이 몇 분 지나야 켜지므로 그 앞의 빈 시간은 분석 도구가 구간째 빼는 것으로 메운다
    function QTR.NavLogAfk()
        local run = QTR.navRun
        if not run then
            return
        end
        local list = run.afk
        local last = list and list[#list]
        local open = last and not last.e
        if UnitIsAFK("player") then
            if not open then
                run.afk = list or {}
                table.insert(run.afk, { s = time() })
            end
        elseif open then
            last.e = time()
        end
    end

    -- 이번 내비게이션에서 실제로 완료한 곳 수 (만료로 빠진 곳은 세지 않는다)
    function QTR.NavDoneCount()
        local n = 0
        for _, d in ipairs(QTR.routeDoneList or {}) do
            if not d.expired and not d.skipped then
                n = n + 1
            end
        end
        return n
    end

    local function NavFinish()
        if QTR.route or QTR.NavDoneCount() == 0 or QTR.navFinish then
            return
        end
        QTR.navFinish = time()
        Print(L["내비게이션을 마쳤습니다."])
        QTR.PlayNavSound()
        QTR.RoutePopupUpdate(true)
        TV.ShowFinish()
    end

    -- 경로의 i번째 곳을 지운다 (TomTom 웨이포인트도). 경로가 비면 안내를 마친다.
    local function RemoveEntry(i)
        local r = QTR.route[i]
        if r.uid and HasTomTom() and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, r.uid)
        end
        table.remove(QTR.route, i)
        if #QTR.route == 0 then
            QTR.route = nil
            StopTicker()
            NavFinish()
        end
        QTR.RoutePopupUpdate()
        TV.UpdateButton()
    end

    function QTR.RouteClear(silent)
        if QTR.route then
            for _, r in ipairs(QTR.route) do
                if r.uid and HasTomTom() and TomTom.RemoveWaypoint then
                    pcall(TomTom.RemoveWaypoint, TomTom, r.uid)
                end
            end
            -- TomTom 없이 안내하던 중이면 우리가 찍은 게임 웨이포인트도 지운다
            if QTR.waypoint and QTR.route[1] and not QTR.route[1].uid then
                QTR.ClearWaypointFor(QTR.waypoint.questID)
            end
        end
        QTR.route = nil
        StopTicker()
        if not silent then
            TV.finish = nil -- 경로안내 중지: 마친 뒤 귀환 버튼도 치운다
        end
        TV.UpdateButton()
        if not silent then
            QTR.routeSeen = nil -- 직접 지우면 새로 열리는 퀘스트도 더 지켜보지 않는다
            QTR.routeDone = nil
            QTR.routeDoneList = nil
            QTR.navStart, QTR.navFinish = nil, nil
            QTR.routeForceFirst, QTR.navRun = nil, nil
            QTR.routeForceLast, QTR.routeSkip = nil, nil
            QTR.RoutePopupUpdate()
            Print(L["경로안내를 중지했습니다."])
        end
    end

    local OnTick -- 아래에 정의

    -- reason: 경로를 다시 짠 이유 (특별 과제 잠금 해제, 순간이동 등). 있으면 시작 안내 대신 이 문구와 다음 목적지를 알린다
    -- quiet: 다시 짰어도 다음 목적지가 그대로면 알리지 않는다
    -- 다시 짤 때 지금 경로의 퀘스트가 새 목록에서 빠졌는데 완료, 만료, 건너뜀, 제외 어느 것도 아니면 true
    -- (순간이동 로딩 화면 직후에는 지도의 퀘스트 정보를 아직 못 받아 목록이 비어 있을 수 있다. 2026-10-24 마법사 실버문 차원문으로 확인)
    local function RouteQuestsMissing(points)
        local have = {}
        for _, p in ipairs(points) do
            have[p.questID] = true
        end
        local now = time()
        for _, r in ipairs(QTR.route or {}) do
            local q = r.questID
            local a = q and DB.activeGQ[q]
            if q and not r.locked and not have[q] and not (QTR.routeDone and QTR.routeDone[q])
                and not (QTR.routeSkip and QTR.routeSkip[q]) and not DB.settings.bannedQuests[q]
                and not (r.expire and r.expire <= now)
                -- 지도에서 읽었는데 이 캐릭터에게는 보상이 골드가 아니게 된 퀘스트 (전쟁 모드 등): 정보가 덜 온 게 아니다
                and not (a and a.notGoldFor and charKey and a.notGoldFor[charKey])
                and not (C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q)) then
                return true
            end
        end
        return false
    end

    function QTR.RouteStart(reason, quiet)
        local oldKey = EntryKey(QTR.route and QTR.route[1])
        if not reason then
            QTR.routeDone = nil -- 새로 시작하는 안내
            QTR.routeDoneList = nil
            QTR.navStart, QTR.navFinish = time(), nil -- 소요 시간은 여기서부터 잰다
            QTR.routeForceFirst, QTR.routeForceLast, QTR.routeSkip = nil, nil, nil
            QTR.routeRetry = nil
            TV.closedKey = nil -- 새로 시작하면 닫았던 사용 버튼 창도 다시 띄운다
            TV.finish = nil
            QTR.NavLogStart()
        end
        local points = CollectRoutePoints()
        -- 다시 짤 때 지도 정보가 아직 없어 보이면 지금 경로를 그대로 두고 2초 뒤 다시 짠다 (최대 10번, 약 20초)
        if reason and QTR.route and (QTR.routeRetry or 0) < 10 and RouteQuestsMissing(points) then
            QTR.routeRetry = (QTR.routeRetry or 0) + 1
            C_Timer.After(2, function()
                if QTR.route then
                    QTR.forceScan = true
                    QTR.RouteStart(reason, quiet)
                end
            end)
            return
        end
        QTR.routeRetry = nil
        QTR.RouteClear(true)
        -- 경로를 짤 때 알고 있던 곳: 이 밖의 곳이 나중에 생기면 새로 열린 것이다 (특별 과제 잠금 해제 등)
        QTR.routeSeen = {}
        for _, p in ipairs(points) do
            if not p.locked then -- 해금 예정 특별 과제는 실제로 열리면 "새로 열린 곳"으로 감지해 다시 짠다
                QTR.routeSeen[p.questID] = true
            end
        end
        if #points == 0 then
            if not quiet then
                Print(L["내비게이션에 넣을 골드퀘가 없습니다. (위치를 아는, 아직 안 한 골드퀘만 넣습니다)"])
            end
            -- 다시 짜다가 남은 곳이 없어졌으면 (순서를 건너뛴 마지막 완료 등) 다 마친 것이다
            if reason then
                NavFinish()
            end
            QTR.RoutePopupUpdate()
            return
        end
        QTR.navFinish = nil -- 다 마친 뒤 새로 열린 곳이 생겨 이어 가는 경우
        -- "이 퀘스트 먼저"로 고른 곳이 아직 경로에 있으면 첫 번째로 둔다 (그 퀘스트를 완료하거나 경로를 지울 때까지)
        local firstIdx
        for i, p in ipairs(points) do
            if p.questID == QTR.routeForceFirst then
                firstIdx = i
            end
        end
        if not firstIdx then
            QTR.routeForceFirst = nil
        end
        -- "마지막에"로 고른 곳 (그 퀘스트를 완료하거나 경로를 지울 때까지 맨 뒤)
        local lastSet = {}
        for i, p in ipairs(points) do
            if QTR.routeForceLast and QTR.routeForceLast[p.questID] and i ~= firstIdx then
                lastSet[i] = true
            end
        end
        local startPos = PlayerPos()
        TV.RefreshMage() -- 마법사 실버문 순간이동 (포탈처럼 TravelCost에 들어간다)
        TV.RefreshRoot() -- 하라니르 뿌리걸음 (같은 방식)
        local methods, bindWhy, missing = TV.RecallMethods()
        -- 순서와 귀환형 이동 자리를 정하고 실제 비용(이동 합 - 귀환형 이동으로 줄어든 양)을 잰다
        -- 경로 항목을 만들 때 쓸 포탈 목록(p.portals)은 OrderPoints를 부를 때마다 바뀌므로 따로 남긴다
        local function Plan(recalls)
            local o, pl, assumed = OrderPoints(points, startPos, firstIdx, lastSet, recalls)
            local uses, why, reasons = TV.PlanRecalls(o, startPos, methods, bindWhy)
            -- 순서를 짤 때 쓴다고 본 횟수만큼 실제로는 못 쓰면 (대기시간, 1회 남기기) 그 횟수로 한 번 다시 짠다
            if recalls then
                local got, redo = {}, false
                for _, u in ipairs(uses) do
                    got[u.m.key] = (got[u.m.key] or 0) + 1
                end
                for _, m in ipairs(recalls) do
                    if (assumed[m.key] or 0) > (got[m.key] or 0) then
                        m.tokens = got[m.key] or 0
                        redo = true
                    end
                end
                if redo then
                    o, pl = OrderPoints(points, startPos, firstIdx, lastSet, recalls)
                    uses, why, reasons = TV.PlanRecalls(o, startPos, methods, bindWhy)
                end
            end
            local sum, prev, portalsOf = 0, startPos, {}
            for i, p in ipairs(o) do
                sum = sum + TravelCost(prev, p.pos)
                prev = p.pos
                portalsOf[i] = p.portals
            end
            for _, u in ipairs(uses) do
                sum = sum - u.save
            end
            return { order = o, pulled = pl, uses = uses, why = why, reasons = reasons, cost = sum, portals = portalsOf }
        end
        -- 귀환형 이동을 고려해 짠 순서와, 순서를 먼저 정하고 귀환형 이동을 끼운 순서(1단계 방식) 중 실제로 빠른 쪽
        -- (순서를 짤 때는 대기시간을 따지지 않아, 대기시간 때문에 원래 노린 자리에 못 쓰면 1단계 방식이 나을 수 있다)
        local plan = Plan(nil)
        if #methods > 0 then
            local plan2 = Plan(methods)
            if plan2.cost < plan.cost - 1 then
                plan = plan2
            end
        end
        local order, pulled = plan.order, plan.pulled
        local recallUses, whyNots = plan.uses, plan.reasons or {}
        local useAt = {}
        for _, u in ipairs(recallUses) do
            useAt[u.k] = u
            -- 대기시간이 짧아서 고른 수단은 기록에 표지를 남긴다 (나중에 분석용, 2026-11-08 사용자 요청)
            --   run.pref = { { t, key, over, sec }, ... }: key를 over 대신 넣었고, 계산상 sec초 느리다. 다시 짤 때 같은 것은 한 번만
            local run = QTR.navRun
            if u.pref and run then
                run.pref = run.pref or {}
                local dup = false
                for _, e in ipairs(run.pref) do
                    if e.key == u.m.key and e.over == u.pref.over then
                        dup = true
                    end
                end
                if not dup then
                    table.insert(run.pref, { t = time(), key = u.m.key, over = u.pref.over, sec = u.pref.sec })
                end
            end
        end
        local tomtom = HasTomTom()
        QTR.route = {}
        local function AddEntry(r)
            if tomtom and r.wp then
                local ok, uid = pcall(TomTom.AddWaypoint, TomTom, r.wp[1], r.wp[2], r.wp[3], {
                    title = r.label, persistent = false, minimap = true, world = true, from = "QuestsToRiches",
                })
                r.uid = ok and uid or nil
            end
            table.insert(QTR.route, r)
        end
        local portalCount = 0
        local travelCount = {} -- 이동 기술별 횟수 { [key] = n }
        -- 번호는 내비게이션 창처럼 이번 안내에서 완료, 건너뜀, 만료로 앞에 남은 곳 다음부터 매긴다
        -- (다시 짜도 채팅, TomTom 번호가 창과 같게. 2026-10-31 사용자 요청)
        local numBase = #(QTR.routeDoneList or {})
        local function CountTravel(key)
            travelCount[key] = (travelCount[key] or 0) + 1
        end
        for i, p in ipairs(order) do
            -- 이 퀘스트로 가는 길에 귀환형 이동을 쓰면: 귀환석 등, 그다음 도착점에서 탈 포탈들
            local portals = plan.portals[i] or {}
            local u = useAt[i]
            if u then
                CountTravel(u.m.key)
                -- 이름은 "귀환석: 나그네의 쉼터 (실버문)". 채팅에는 쌍점이 겹치지 않게 chatLabel을 쓴다 (TV.TravelLabel)
                local label, text, zone, chat = TV.TravelLabel(u.m.key, u.m.destName)
                AddEntry({ travel = u.m.key, hearth = (u.m.key == "hearth") or nil, arrival = u.m.dest, bindName = u.m.destName,
                    label = label, travelText = text, innZone = zone, chatLabel = chat, poi = u.m.poi })
                portals = u.path
            end
            -- 이 퀘스트로 가는 길에 탈 포탈들(마법사 순간이동 포함)을 먼저 넣는다
            for _, pi in ipairs(portals) do
                if pi == "mage" then
                    CountTravel("mage")
                    local label, text, _, chat = TV.TravelLabel("mage")
                    AddEntry({ travel = "mage", spell = mageTele and mageTele.spell, arrival = mageTele and mageTele.pos,
                        label = label, travelText = text, chatLabel = chat })
                elseif pi == "root" then
                    CountTravel("root")
                    local label, text, zone, chat = TV.TravelLabel("root")
                    AddEntry({ travel = "root", spell = QTR.rootTele and QTR.rootTele.spell, arrival = QTR.rootTele and QTR.rootTele.pos,
                        twice = QTR.rootTele and QTR.rootTele.twice or nil,
                        label = label, travelText = text, innZone = zone, chatLabel = chat })
                else
                    portalCount = portalCount + 1
                    local pp = PortalPositions()[pi]
                    AddEntry({ portal = pi, wp = PORTALS[pi].from, arrival = pp and pp.to, label = PortalLabel(pi) })
                end
            end
            -- 안내 문구: "4. 비행의 시험 (줄아만)"
            -- 팝업창에 쓰는 정보: 퀘스트명, 지역, 금액, 정점 보관함 여부
            AddEntry({ questID = p.questID, wp = p.wp, title = p.title, zone = p.zone, money = p.money, cache = p.cache, cacheItem = p.cacheItem,
                expire = p.expire, locked = p.locked, need = p.need,
                label = (numBase + i) .. ". " .. (p.locked and L["(해금 예정) "] or "") .. (p.title or p.questID)
                    .. ((p.zone and p.zone ~= "") and (" (" .. p.zone .. ")") or "") })
        end
        -- 예: "5곳 (포탈 4번 이용)"
        local uses = {}
        if portalCount > 0 then
            table.insert(uses, L["포탈 %d번"]:format(portalCount))
        end
        for _, key in ipairs({ "mage", "root", "hearth", "astral", "arcantina", "maisara", "dundun", "delvebot" }) do
            if travelCount[key] then
                table.insert(uses, L["%s %d번"]:format(TV.NAMES[key], travelCount[key]))
            end
        end
        local count = L["%d곳"]:format(#order) .. (#uses > 0 and L[" (%s 이용)"]:format(table.concat(uses, ", ")) or "")
        local first = QTR.route[1].chatLabel or QTR.route[1].label -- 채팅용 이름 (쌍점이 겹치지 않게)
        if reason then
            if not (quiet and EntryKey(QTR.route[1]) == oldKey) then
                Print(reason .. L[" 남은 경로를 다시 짰습니다: %s. 다음 목적지: %s"]:format(count, first))
            end
        elseif tomtom then
            Print(L["내비게이션: %s, TomTom에 등록했습니다. 첫 목적지: %s"]:format(count, first))
        else
            Print(L["내비게이션: %s. TomTom이 없어서 게임 웨이포인트로 한 곳씩 안내합니다. 첫 목적지: %s"]:format(count, first))
        end
        -- 해금 예정 특별 과제를 경로에 넣었으면 알린다 (처음 짤 때와 다시 짜서 바뀔 때)
        if not quiet then
            for _, p in ipairs(order) do
                if p.locked then
                    Print(L["특별 과제 해금까지 고려했습니다: %s (%s 퀘스트 %d개를 마치면 열립니다)"]:format(tostring(p.title), tostring(p.zone), p.need or 0))
                end
            end
        end
        -- 도착 전에 만료될 것 같아 앞으로 당긴 퀘스트
        if pulled and #pulled > 0 and not quiet then
            local names = {}
            for _, p in ipairs(pulled) do
                table.insert(names, (p.title or p.questID) .. ((p.zone and p.zone ~= "") and (" (" .. p.zone .. ")") or ""))
            end
            Print(L["곧 만료되는 퀘스트를 앞으로 당겼습니다: "] .. table.concat(names, ", "))
        end
        -- 귀환석 등을 넣었으면 어디서 쓰는지와 줄어드는 시간을 알린다
        --   2026-11-08 사용자 결정: 넣지 않은 이유와 함께 설정(travelWhyOn, 기본 끔)을 켰을 때만 (채팅창 글자가 많아지지 않게)
        if #recallUses > 0 and not quiet and DB.settings.travelWhyOn then
            for _, u in ipairs(recallUses) do
                local p = order[u.k]
                -- 줄어드는 시간: 1분 미만이면 초 단위 ("약 34초"), 그 이상은 분 단위 ("약 2분")
                local saveSec = math.floor(u.save / NAV_SPEED + 0.5)
                local saveText = (saveSec < 60) and L["%d초"]:format(saveSec) or L["%d분"]:format(math.floor(saveSec / 60 + 0.5))
                Print(L["%s 동선에 넣었습니다: %s 가기 전 (약 %s 단축)"]:format(TV.OBJ[u.m.key], tostring(p.title or p.questID)
                    .. ((p.zone and p.zone ~= "") and (" (" .. p.zone .. ")") or ""), saveText)
                    .. (u.pref and ((u.pref.sec < 1) and L[" 걸리는 시간이 %s 쪽과 거의 같아 쿨타임이 짧은 쪽을 넣었습니다."]:format(TV.NAMES[u.pref.over] or u.pref.over)
                        or L[" %s보다 약 %d초 느리지만 쿨타임이 짧아서 넣었습니다."]:format(TV.NAMES[u.pref.over] or u.pref.over, u.pref.sec)) or ""))
            end
        end
        -- 넣지 않은 이유 (설정 "이동 수단을 넣었는지와 그 이유를 채팅창에 알리기", 기본 끔, 2026-11-08 사용자 요청. 그전에는 귀환석만, 아무것도 안 넣었을 때 늘 알렸다)
        --   가지고 있고 설정도 켠 수단만: 목록에 넣었는데 고르지 않은 것(whyNots)과 위치를 몰라 목록에 못 넣은 것(missing)
        --   새로 시작할 때만 알린다 (다시 짤 때마다 알리면 시끄럽다)
        if DB.settings.travelWhyOn and not reason and not quiet then
            local listed = {}
            for _, w in ipairs(whyNots) do
                listed[w.key] = true
                Print(L["%s 넣지 않았습니다: %s"]:format(TV.OBJ[w.key] or w.key, w.text))
            end
            for _, key in ipairs({ "hearth", "astral", "arcantina", "maisara", "dundun", "delvebot" }) do
                if missing[key] and not listed[key] then
                    Print(L["%s 넣지 않았습니다: %s"]:format(TV.OBJ[key], missing[key]))
                end
            end
            -- 뿌리걸음 (2026-11-08 볶음밥의로아 시험에서 알림이 없었다): 포탈처럼 들어가므로 몇 번 넣었는지, 안 넣었으면 그 까닭
            if TV.SpellKnown(TV.ROOT.spell) and not DB.settings.travelRootOff then
                if travelCount.root then
                    Print(L["뿌리걸음을 동선에 넣었습니다: %d번 (포탈처럼 더 빠른 구간마다)"]:format(travelCount.root))
                else
                    Print(L["%s 넣지 않았습니다: %s"]:format(L["뿌리걸음을"], QTR.rootTele
                        and L["요람을 거쳐 더 빨라지는 구간이 없어서 (세계수 뿌리 근처에서는 쓰지 않습니다)."]
                        or L["요람 위치를 읽지 못해서."]))
                end
            end
        end
        PointFirst()
        QTR.RoutePopupUpdate()
        TV.UpdateButton()
        QTR.routeLastPos = PlayerPos()
        if not ticker and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(1, function() OnTick() end)
        end
    end

    -- 경로에 남은 퀘스트 중 만료된 것을 빼고 남은 경로를 다시 짠다 (OnTick에서 5초마다)
    -- 만료된 곳은 내비게이션 창의 완료 목록에 회색 줄과 시계 아이콘으로 남긴다 (완료 수, 획득 골드에는 넣지 않는다)
    local function CheckExpired()
        local now = time()
        local expired = {}
        for _, r in ipairs(QTR.route) do
            if r.questID and r.expire and now >= r.expire
                and not (C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(r.questID)) then
                table.insert(expired, r)
            end
        end
        if #expired == 0 then
            return false
        end
        QTR.routeDone = QTR.routeDone or {}
        QTR.routeDoneList = QTR.routeDoneList or {}
        local names = {}
        for _, r in ipairs(expired) do
            QTR.routeDone[r.questID] = true
            table.insert(QTR.routeDoneList, { questID = r.questID, title = r.title or r.questID, zone = r.zone,
                money = r.money, cache = r.cache, expired = true, t = r.expire })
            table.insert(names, (r.title or r.questID) .. ((r.zone and r.zone ~= "") and (" (" .. r.zone .. ")") or ""))
            if QTR.routeForceFirst == r.questID then
                QTR.routeForceFirst = nil
            end
        end
        QTR.RouteStart(L["퀘스트 만료: "] .. table.concat(names, ", ") .. ".")
        return true
    end

    -- 1초마다: 순간이동(다른 대륙으로 옮겨졌거나 1초 사이 JUMP 야드 넘게 이동)을 감지한다
    --   다음 목적지가 포탈이고 그 도착점에 서 있으면: 포탈을 탄 것이니 다음 목적지로 넘어간다
    --   그 밖의 순간이동(귀환석, 경로에 없는 포탈 등): 지금 위치에서 남은 경로를 다시 짠다
    local tickCount = 0
    OnTick = function()
        if not QTR.route then
            StopTicker()
            return
        end
        -- 5초마다 만료 확인, 30초마다 내비게이션 창의 남은 시간 표시를 고쳐 그린다
        tickCount = tickCount + 1
        if tickCount % 5 == 0 and CheckExpired() then
            return
        end
        if tickCount % 30 == 0 then
            QTR.RoutePopupUpdate()
        end
        -- 10초마다: 해금 예정 특별 과제가 남아 있으면 실제로 열렸는지 본다 (2026-11-08 사용자 제보: 퀘스트 완료 뒤 2초, 5초에만 봐서
        --   그때 게임 정보가 늦게 바뀌면 열린 뒤에도 계속 "해금 예정"이었다). 열렸으면 RouteWatch가 남은 경로를 다시 짠다
        if tickCount % 10 == 5 then
            for _, e in ipairs(QTR.route) do
                if e.locked then
                    QTR.RouteWatch()
                    break
                end
            end
        end
        local pos = PlayerPos()
        if not pos then
            return -- 로딩 화면 등
        end
        -- 30초마다: 아직 쓰지 않은 둔둔 장난감 단계가 있는데 풍요 지점이 바뀌었으면 (끝났거나 다른 곳) 남은 경로를 다시 짠다
        if tickCount % 30 == 15 then
            for _, e in ipairs(QTR.route) do
                if e.travel == "dundun" then
                    local ab = TV.Abundance()
                    if not ab or ab.poi ~= e.poi then
                        QTR.RouteStart(L["풍요 지점이 바뀌었습니다."])
                        return
                    end
                    break
                end
            end
        end
        local last = QTR.routeLastPos
        QTR.routeLastPos = pos
        if not last or (last.c == pos.c and Dist(last, pos) < JUMP) then
            return
        end
        local r = QTR.route[1]
        if (r.portal or r.travel) and r.arrival and Dist(pos, r.arrival) < JUMP then
            NavLogStop(nil, r.portal or r.travel)
            RemoveEntry(1)
            if QTR.route then
                Print(L["다음 목적지: "] .. (QTR.route[1].chatLabel or QTR.route[1].label))
                PointFirst()
            end
        elseif r.travel == "arcantina" and not r.inside and r.arrival and pos.c ~= r.arrival.c then
            -- 아르칸티나 열쇠: 먼저 아르칸티나(다른 공간)에 들어간다. 나가는 차원문을 타고 실버문에 설 때까지 기다린다
            r.inside = true
            TV.UpdateButton()
        else
            QTR.RouteStart(L["순간이동을 감지했습니다."], true)
        end
    end

    -- 경로를 짤 때 없던 곳이 생겼는지 본다 (퀘스트를 완료해 특별 과제가 열린 경우 등)
    -- 있으면 지금 위치에서 남은 경로를 다시 짜고 true
    local function CheckNewPoints()
        if not QTR.routeSeen then
            return false
        end
        QTR.forceScan = true
        local new = {}
        for _, p in ipairs(CollectRoutePoints()) do
            -- 해금 예정 특별 과제(아직 잠김)는 새로 열린 곳이 아니다
            if not p.locked and not QTR.routeSeen[p.questID] then
                table.insert(new, p)
            end
        end
        if #new == 0 then
            return false
        end
        local names, special = {}, false
        for _, p in ipairs(new) do
            table.insert(names, (p.title or p.questID) .. ((p.zone and p.zone ~= "") and (" (" .. p.zone .. ")") or ""))
            if QTR.SPECIAL_ASSIGNMENTS[p.questID] or (QTR.mapCaches and QTR.mapCaches[p.questID]) then
                special = true
            end
        end
        QTR.RouteStart((special and L["특별 과제 잠금 해제: "] or L["새 골드퀘: "]) .. table.concat(names, ", ") .. ".")
        return true
    end

    -- 퀘스트를 완료할 때마다 (내비게이션 중이거나 방금 끝났을 때) 몇 초 뒤 새로 열린 곳이 있는지 본다.
    -- 지도 정보가 늦게 바뀌는 경우가 있어 2초 뒤에 보고, 없으면 5초 뒤에 한 번 더 본다.
    -- 경로가 이미 끝났고 두 번 다 없으면 지켜보기를 그만둔다.
    local watchToken = 0
    function QTR.RouteWatch()
        if not QTR.routeSeen then
            return
        end
        watchToken = watchToken + 1
        local token = watchToken
        C_Timer.After(2, function()
            if token ~= watchToken or CheckNewPoints() then
                return
            end
            C_Timer.After(5, function()
                if token ~= watchToken then
                    return
                end
                if not CheckNewPoints() and not QTR.route then
                    QTR.routeSeen = nil
                end
            end)
        end)
    end

    -- 내비게이션 창에서 우클릭한 퀘스트를 다음 목적지로 하고, 나머지는 거기서부터 다시 짠다
    -- (그 퀘스트를 완료하거나 경로를 지울 때까지 다시 짜도 첫 번째로 둔다)
    function QTR.RouteFirst(questID)
        if not QTR.route then
            return
        end
        for _, r in ipairs(QTR.route) do
            if r.questID then
                if r.questID == questID then
                    Print(L["이미 다음 목적지입니다: "] .. r.label)
                    return
                end
                break
            end
        end
        QTR.routeForceFirst = questID
        if QTR.routeForceLast then
            QTR.routeForceLast[questID] = nil
        end
        QTR.RouteStart(L["다음 목적지를 바꿨습니다."])
    end

    -- 경로에 있는 퀘스트의 "퀘스트명 (지역명)"
    local function RouteQuestLabel(questID, fallback)
        for _, r in ipairs(QTR.route or {}) do
            if r.questID == questID then
                return tostring(r.title or questID) .. ((r.zone and r.zone ~= "") and (" (" .. r.zone .. ")") or ""), r
            end
        end
        return fallback or tostring(questID)
    end

    -- "이 퀘스트를 마지막에 하고 싶습니다": 나머지를 다 돈 뒤에 하도록 다시 짠다
    -- (그 퀘스트를 완료하거나 경로를 지울 때까지 다시 짜도 맨 뒤에 둔다)
    function QTR.RouteLast(questID)
        if not QTR.route then
            return
        end
        QTR.routeForceLast = QTR.routeForceLast or {}
        QTR.routeForceLast[questID] = true
        if QTR.routeForceFirst == questID then
            QTR.routeForceFirst = nil
        end
        QTR.RouteStart(L["마지막으로 미뤘습니다: "] .. RouteQuestLabel(questID) .. ".")
    end

    -- "이번만은 이 퀘스트를 하고 싶지 않습니다": 이번 내비게이션에서만 뺀다 (추적 제외 목록에는 넣지 않는다)
    -- 내비게이션 창의 완료 목록에 회색 "건너뜀"으로 남긴다 (완료 수, 골드에는 넣지 않는다)
    function QTR.NavSkipQuest(questID)
        if not QTR.route then
            return
        end
        local label, r = RouteQuestLabel(questID)
        QTR.routeSkip = QTR.routeSkip or {}
        QTR.routeSkip[questID] = true
        QTR.routeDoneList = QTR.routeDoneList or {}
        table.insert(QTR.routeDoneList, { questID = questID, title = r and r.title or questID, zone = r and r.zone,
            money = r and r.money, cache = r and r.cache, skipped = true, t = time() })
        if QTR.routeForceFirst == questID then
            QTR.routeForceFirst = nil
        end
        if QTR.routeForceLast then
            QTR.routeForceLast[questID] = nil
        end
        QTR.RouteStart(L["이번 내비게이션에서 뺐습니다: "] .. label .. ".")
    end

    -- 건너뛴 퀘스트 기록(완료 목록의 skipped 항목)을 찾는다: 위치, 항목
    local function FindSkipped(questID)
        for i, d in ipairs(QTR.routeDoneList or {}) do
            if d.skipped and d.questID == questID then
                return i, d
            end
        end
    end

    -- "이번만 빼기" 되돌리기: 건너뜀 기록을 지우고 다시 경로에 넣는다 (다 마친 뒤여도 다시 이어 간다)
    function QTR.NavUnskipQuest(questID)
        local i, d = FindSkipped(questID)
        if not i then
            return
        end
        table.remove(QTR.routeDoneList, i)
        if QTR.routeSkip then
            QTR.routeSkip[questID] = nil
        end
        QTR.forceScan = true
        QTR.RouteStart(L["다시 경로에 넣었습니다: "] .. tostring(d.title or questID)
            .. ((d.zone and d.zone ~= "") and (" (" .. d.zone .. ")") or "") .. ".")
    end

    -- 내비게이션 창의 건너뛴 줄 우클릭 메뉴
    function QTR.ShowNavSkipMenu(owner, questID, title)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then
            QTR.NavUnskipQuest(questID)
            return
        end
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(title or tostring(questID))
            root:CreateButton(L["이 퀘스트를 다시 경로에 넣습니다."], function()
                QTR.NavUnskipQuest(questID)
            end)
        end)
    end

    -- 내비게이션에서 뺄 퀘스트: 추적 제외 목록(/qtr ban과 같은 목록)에 넣고 남은 경로를 다시 짠다
    -- 설정창의 "추적 제외 퀘스트"에서 언제든 되돌릴 수 있다
    function QTR.NavBanQuest(questID, label)
        local name = label or tostring(questID)
        for _, r in ipairs(QTR.route or {}) do
            if r.questID == questID and r.title then
                name = r.title
            end
        end
        QTR.BanQuest(questID, name)
        if QTR.routeForceFirst == questID then
            QTR.routeForceFirst = nil
        end
        Print(L["추적에서 제외했습니다: "] .. QTR.BanLabel(questID) .. L[" (설정창의 추적 제외 퀘스트에서 되돌릴 수 있습니다)"])
        QTR.forceScan = true
        AceConfigRegistry:NotifyChange(ADDON_NAME)
        if QTR.route then
            QTR.RouteStart(L["제외한 퀘스트를 뺐습니다."])
        end
        QTR:Refresh()
    end

    -- 내비게이션 창 퀘스트 줄의 우클릭 메뉴 (게임 기본 우클릭 메뉴 모양)
    --   이 퀘스트를 가장 먼저 수행합니다: 다음 목적지로 하고 나머지는 거기서부터 다시 짠다
    --   이 퀘스트를 마지막에 하고 싶습니다: 나머지를 다 돈 뒤에 하도록 맨 뒤로 미룬다
    --   (구분선)
    --   이번만은 이 퀘스트를 하고 싶지 않습니다: 이번 내비게이션에서만 뺀다
    --   이 퀘스트를 더이상 하고 싶지 않습니다: 추적 제외 목록에 넣고 경로에서 뺀다
    function QTR.ShowNavRowMenu(owner, questID, title)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then
            QTR.RouteFirst(questID) -- 메뉴를 쓸 수 없는 클라이언트: 예전처럼 바로 다음 목적지로
            return
        end
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(title or tostring(questID))
            root:CreateButton(L["이 퀘스트를 가장 먼저 수행합니다."], function()
                QTR.RouteFirst(questID)
            end)
            root:CreateButton(L["이 퀘스트를 마지막에 하고 싶습니다."], function()
                QTR.RouteLast(questID)
            end)
            root:CreateDivider()
            root:CreateButton(L["이번만은 이 퀘스트를 하고 싶지 않습니다."], function()
                QTR.NavSkipQuest(questID)
            end)
            root:CreateButton(L["이 퀘스트를 더이상 하고 싶지 않습니다."], function()
                QTR.NavBanQuest(questID, title)
            end)
        end)
    end

    -- 퀘스트 완료 시 (QUEST_TURNED_IN): 경로에서 빼고, 첫 목적지였으면 다음 곳을 안내한다.
    -- 순서를 건너뛰어 완료했으면 (그 앞의 포탈 안내 등이 남으므로) 지금 위치에서 조용히 다시 짠다.
    function QTR.RouteAdvance(questID)
        -- 건너뛴 퀘스트를 결국 완료했으면 (건너뛰자마자 필드 보스가 나타난 경우 등) 이번 내비게이션의 완료로 바꾼다
        -- 하루 기록과 목표 진행은 원래 따로 기록되므로, 여기서는 내비게이션 창의 완료 수, 획득 골드, 기록(navLog)만 맞춘다
        local _, skipped = FindSkipped(questID)
        if skipped then
            skipped.skipped, skipped.t = nil, time()
            QTR.routeDone = QTR.routeDone or {}
            QTR.routeDone[questID] = true
            if QTR.routeSkip then
                QTR.routeSkip[questID] = nil
            end
            NavLogStop(questID)
            QTR.RoutePopupUpdate()
            return
        end
        if not QTR.route then
            return
        end
        for i, r in ipairs(QTR.route) do
            if r.questID == questID then
                QTR.routeDone = QTR.routeDone or {}
                QTR.routeDone[questID] = true
                -- 팝업창의 완료 목록 (다시 짜도 이번 안내 동안은 남긴다)
                QTR.routeDoneList = QTR.routeDoneList or {}
                -- t: 완료 시각 (창에 "21:05"처럼 적는다), cacheItem: 보관함을 열면 나온 골드로 바꿀 때 맞춰 보는 아이템
                table.insert(QTR.routeDoneList, { questID = questID, title = r.title or r.questID, zone = r.zone, money = r.money,
                    cache = r.cache, cacheItem = r.cacheItem, t = time() })
                NavLogStop(questID)
                if QTR.routeForceFirst == questID then
                    QTR.routeForceFirst = nil
                end
                if QTR.routeForceLast then
                    QTR.routeForceLast[questID] = nil
                end
                if i == 1 then
                    RemoveEntry(1)
                    if QTR.route then
                        Print(L["다음 목적지: "] .. (QTR.route[1].chatLabel or QTR.route[1].label))
                        PointFirst()
                    end
                else
                    QTR.RouteStart(L["순서를 건너뛴 완료가 있어"], true)
                end
                return
            end
        end
    end

    ---------------------------------------------------------------------------
    -- 내비게이션 창: 애드온이 편성한 동선을 간략하게 보여준다 (메인 창, 설정창과 같은 독립 창)
    --   제목 "[QTR] 골드퀘 내비게이션" (가운데), 오른쪽 위에 고정(압정) 버튼과 닫기 버튼
    --   윗줄: "전체 목적지 a곳 중 완료 b곳, 잔여 c곳 (포탈 d번)" (포탈 부분만 하늘색, 창보다 길면 괄호 부분을 둘째 줄로)
    --   목록: 완료한 곳(회색, 녹색 체크와 완료 시각), 다음 목적지(노란 띠), 남은 곳(흰색),
    --         중간에 거쳐 갈 포탈(하늘색, 들여쓰기). 아랫줄: 남은 골드와 완료 골드 합계
    --   보관함을 주는 퀘스트는 완료 뒤 그 보관함을 열면 "정점 보관함" 대신 나온 골드를 적고 완료 합계에 더한다
    --   다 마치면 소요 시간, 퀘스트 수, 획득 골드, 진척도 상승분을 적는다
    --   완료, 포탈 통과, 다시 짜기로 경로가 바뀌면 열려 있는 동안 바로 고쳐 그린다.
    --   창을 닫아도 내비게이션은 계속된다. 안내 중이 아니면 대기 화면(넣을 수 있는 곳, 내비게이션 버튼)을 보여 준다.
    --   고정을 켜면 Esc로 닫히지 않는다 (창은 계속 끌어서 옮길 수 있다). 단축키로 열고 닫는다 (QuestsToRiches_ToggleRoute).
    ---------------------------------------------------------------------------
    local POP_NAME = "QuestsToRichesRouteFrame"
    local POP_W = 360       -- 창 가로 길이
    local POP_LINE = 18     -- 줄 높이 (작은 글씨를 켜면 15, 그릴 때마다 SetPopFont가 정한다)
    local POP_TOP = -54     -- 첫 줄 위치 (윗줄 요약과 조금 띄운다)
    local POP_MAXLINES = 28 -- 이보다 많으면 완료한 곳을 한 줄로 줄이고, 그래도 넘치면 뒤를 "외 n줄"로 줄인다
    local POP_RIGHT_W = 90  -- 오른쪽 금액 칸
    local PORTAL_COLOR = "ff66ccff" -- 포탈 줄과 윗줄의 "(포탈 d번)" 색

    local pop = CreateFrame("Frame", POP_NAME, UIParent)
    pop:SetSize(POP_W, 120)
    pop:Hide()
    pop:SetFrameStrata("MEDIUM")
    pop:SetFrameLevel(120)
    pop:EnableMouse(true)
    pop:SetMovable(true)
    pop:SetClampedToScreen(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    pop:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            DB.settings.routePopPos = { left, top }
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    end)

    -- 고정: 켜면 Esc 목록(UISpecialFrames)에서 빼서 Esc로 닫히지 않게 한다
    local function ApplyPinned()
        for k = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[k] == POP_NAME then
                table.remove(UISpecialFrames, k)
            end
        end
        if not (DB and DB.settings.navPinned) then
            tinsert(UISpecialFrames, POP_NAME)
        end
    end
    ApplyPinned() -- 불러올 때는 고정 꺼짐(Esc로 닫힘)으로 두고, 설정을 읽은 뒤 다시 적용한다

    local popBg = pop:CreateTexture(nil, "BACKGROUND")
    popBg:SetAllPoints(pop)
    popBg:SetColorTexture(0, 0, 0, 0.85)
    -- 배경 투명도 (2026-10-30, 인벤 루세로님 요청): 글씨는 그대로 두고 검은 배경만. 대시보드 "배경 투명도"와 같은 방식, 기본 0.85
    --   "마우스를 올리지 않았을 때 흐리게"는 창 전체(글씨 포함)라 따로 둔다 (둘 다 켜면 곱해진다)
    function QTR.ApplyNavBg()
        popBg:SetColorTexture(0, 0, 0, (DB and DB.settings.navBgAlpha) or 0.85)
    end

    local popTitle = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popTitle:SetPoint("TOP", pop, "TOP", 0, -10)
    popTitle:SetText(L["[QTR] 골드퀘 내비게이션"])

    local popSub = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popSub:SetPoint("TOPLEFT", pop, "TOPLEFT", 12, -34)
    popSub:SetJustifyH("LEFT")

    local popClose = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
    popClose:SetPoint("TOPRIGHT", pop, "TOPRIGHT", 0, 0)

    -- 고정 버튼 (닫기 버튼 왼쪽 압정): 켜짐 빨강, 꺼짐 회색
    local pinBtn = CreateFrame("Button", nil, pop)
    pinBtn:SetSize(20, 20)
    pinBtn:SetPoint("RIGHT", popClose, "LEFT", 2, 0)
    local pinTex = pinBtn:CreateTexture(nil, "ARTWORK")
    pinTex:SetTexture("Interface\\AddOns\\QuestsToRiches\\Media\\Pin")
    pinTex:SetAllPoints(pinBtn)
    pinBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local function UpdatePinLook()
        local pinned = DB and DB.settings.navPinned
        pinTex:SetDesaturated(not pinned)
        pinTex:SetAlpha(pinned and 1 or 0.5)
    end
    local function ShowPinTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["고정"])
        if DB.settings.navPinned then
            GameTooltip:AddLine(L["켜짐: Esc를 눌러도 창이 닫히지 않습니다."], 1, 1, 1, true)
        else
            GameTooltip:AddLine(L["꺼짐: Esc를 누르면 창이 닫힙니다."], 1, 1, 1, true)
        end
        GameTooltip:AddLine(L["창 위치는 고정과 상관없이 끌어서 옮길 수 있습니다."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
    pinBtn:SetScript("OnClick", function(self)
        DB.settings.navPinned = not DB.settings.navPinned
        ApplyPinned()
        UpdatePinLook()
        ShowPinTip(self)
    end)
    pinBtn:SetScript("OnEnter", ShowPinTip)
    pinBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    -- 설정을 읽은 뒤(OnInitialize) 저장된 고정 상태를 적용한다
    function QTR.ApplyNavPinned()
        ApplyPinned()
        UpdatePinLook()
    end

    -- 마우스를 올리지 않았을 때 창 전체를 흐리게 한다 (설정: navFade 켜기, navFadeAlpha 불투명도, 기본 0.8)
    -- 창이 보이는 동안 0.05초마다 마우스가 창 위에 있는지 보고, 목표 불투명도로 부드럽게 바꾼다 (약 0.3초)
    local fadeElapsed = 0
    pop:SetScript("OnUpdate", function(self, elapsed)
        fadeElapsed = fadeElapsed + elapsed
        if fadeElapsed < 0.05 then
            return
        end
        local step = fadeElapsed
        fadeElapsed = 0
        local s = DB and DB.settings
        local target = 1
        if s and s.navFade and not self:IsMouseOver() then
            target = s.navFadeAlpha or 0.8
        end
        local a = self:GetAlpha() or 1
        if math.abs(a - target) < 0.01 then
            if a ~= target then
                self:SetAlpha(target)
            end
            return
        end
        local d = step * 3
        self:SetAlpha(a < target and math.min(target, a + d) or math.max(target, a - d))
    end)

    -- 다음 목적지 줄 뒤에 까는 노란 띠
    local popBand = pop:CreateTexture(nil, "ARTWORK")
    popBand:SetColorTexture(1, 0.82, 0, 0.18)
    popBand:SetSize(POP_W - 16, POP_LINE)
    popBand:Hide()

    local popRows = {}
    local function PopRow(i)
        local row = popRows[i]
        if not row then
            row = {}
            row.name = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetJustifyH("LEFT")
            if row.name.SetWordWrap then
                row.name:SetWordWrap(false)
            end
            -- 지역명은 따로 그려서 퀘스트 이름이 길어도 잘리지 않게 한다
            row.zone = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.zone:SetJustifyH("LEFT")
            if row.zone.SetWordWrap then
                row.zone:SetWordWrap(false)
            end
            row.right = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.right:SetJustifyH("RIGHT")
            row.right:SetWidth(POP_RIGHT_W)
            if row.right.SetWordWrap then
                row.right:SetWordWrap(false) -- 영어 "Pinnacle Caches"가 두 줄로 나뉘어 아래 줄과 겹쳤다 (2026-10-31)
            end
            -- 퀘스트 줄에 마우스를 올리면 골드퀘 탭과 같은 퀘스트 툴팁 (포탈 줄 등은 숨긴다)
            -- 줄 위에서 끌어도 창이 옮겨지도록 끌기는 창으로 넘긴다
            row.hit = CreateFrame("Frame", nil, pop)
            row.hit:SetSize(POP_W - 16, POP_LINE)
            row.hit:EnableMouse(true)
            row.hit:RegisterForDrag("LeftButton")
            row.hit:SetScript("OnDragStart", function()
                pop:GetScript("OnDragStart")(pop)
            end)
            row.hit:SetScript("OnDragStop", function()
                pop:GetScript("OnDragStop")(pop)
            end)
            -- 남은 퀘스트 줄: 툴팁 아래에 우클릭 안내, 우클릭하면 그 퀘스트를 다음 목적지로 (잘못 누르기 쉬운 왼쪽 클릭은 쓰지 않는다)
            row.hit:SetScript("OnEnter", function(self)
                QTR.ShowRowTooltip(self)
                if self.canFirst and GameTooltip:IsShown() then
                    GameTooltip:AddLine(L["우클릭: 메뉴 (먼저, 마지막에, 이번만 빼기, 제외하기)"], 0.25, 1, 0.25)
                    GameTooltip:Show()
                elseif self.canUndo and GameTooltip:IsShown() then
                    GameTooltip:AddLine(L["우클릭: 다시 경로에 넣기"], 0.25, 1, 0.25)
                    GameTooltip:Show()
                end
            end)
            row.hit:SetScript("OnLeave", QTR.HideRowTooltip)
            row.hit:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and self.canFirst and self.tipQuest then
                    GameTooltip:Hide()
                    QTR.ShowNavRowMenu(self, self.tipQuest, self.menuTitle)
                elseif button == "RightButton" and self.canUndo and self.tipQuest then
                    GameTooltip:Hide()
                    QTR.ShowNavSkipMenu(self, self.tipQuest, self.menuTitle)
                end
            end)
            row.hit:Hide()
            popRows[i] = row
        end
        return row
    end

    -- 작은 글씨 (2026-10-30, 인벤 루세로님 요청 "창은 크게, 글씨는 작게". 사용자 결정: 보통/작은 글씨 두 단계만)
    --   켜면 목록 줄 글씨를 한 단계 작은 글꼴(GameFontHighlightSmall)로, 줄 높이를 18에서 15로. 그릴 때마다 정한다
    --   (창 제목, 윗줄, 아랫줄, 버튼은 그대로. 큰 글씨는 창 크기 설정으로 키운다)
    local function SetPopFont()
        local small = DB and DB.settings.navSmallFont
        POP_LINE = small and 15 or 18
        popBand:SetSize(POP_W - 16, POP_LINE)
        return small and (GameFontHighlightSmall or GameFontHighlight) or GameFontHighlight
    end

    local popFoot = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popFoot:SetJustifyH("LEFT")
    popFoot:SetSpacing(4)

    -- 아래쪽 버튼 하나: 안내 중이면 "경로안내 중지"(내비게이션 창을 닫고 대시보드를 연다), 아니면 "내비게이션 시작!"
    --   다 마쳤으면 "대시보드로 돌아가기"(내비게이션 창을 닫고 대시보드를 연다)
    local popActBtn = CreateButton(pop, L["경로안내 중지"], 130)
    local function BackToDashboard()
        pop:Hide()
        if not f:IsShown() then
            QuestsToRiches_ToggleDashboard()
        end
    end
    popActBtn:SetScript("OnClick", function()
        if QTR.route then
            QTR.RouteClear()
            BackToDashboard()
        elseif popActBtn.backOnly or (QTR.routeDoneList and #QTR.routeDoneList > 0) then
            BackToDashboard()
        else
            QTR.RouteStart()
            QTR.RoutePopupUpdate(true)
        end
    end)

    -- 지역명 부분: " (지역명)" (지역을 모르면 빈 글자). 한국어가 아닌 클라이언트는 짧은 지역명 (QTR.ShortZone)
    local function ZoneText(zone)
        return (zone and zone ~= "") and (" (" .. QTR.ShortZone(zone) .. ")") or ""
    end

    -- 완료 표시: 녹색 체크 아이콘 (준비 확인 창의 체크, 글꼴에 없는 문자를 쓰지 않으려고 아이콘으로 넣는다)
    local DONE_CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
    -- 건너뜀 표시: 같은 준비 확인 창의 빨간 X 아이콘 (체크 자리에 넣는다)
    local SKIP_MARK = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"
    -- 만료 표시: 회중시계 아이콘 (시간이 다 돼서 빠졌다는 뜻, 직접 뺀 건너뜀과 구별한다). 아이콘 테두리는 잘라 낸다
    -- 그림이 꽉 차 보여서 체크, X(14)보다 작은 12로 둔다. 세로 위치 조정(offsetY)은 0이라 줄 가운데에 놓인다
    local EXPIRED_MARK = "|TInterface\\Icons\\INV_Misc_PocketWatch_01:12:12:0:0:64:64:5:59:5:59|t"

    -- 완료한 곳의 골드: 골드퀘 금액, 보관함을 열었으면 나온 골드
    local function DoneMoney(d)
        return (d.money or 0) + (d.cacheGold or 0)
    end

    -- 오른쪽 칸: 골드퀘는 금액, 특별 과제는 정점 보관함 (완료 뒤 보관함을 열었으면 나온 골드)
    local function RewardText(e, gray)
        if e.cache and not e.cacheGold then
            -- "##내비" 꼬리표: 좁은 오른쪽 칸용 번역 (영어는 "Cache")
            return gray and L["|cff808080정점 보관함|r##내비"] or L["|cffa335ee정점 보관함|r##내비"]
        end
        local money = DoneMoney(e)
        if money > 0 then
            return gray and ("|cff808080" .. FormatGold(money) .. "|r") or FormatSubGold(money)
        end
        return ""
    end

    -- 이번 내비게이션에서 완료한 보관함 퀘스트의 보관함을 열었을 때 (FinishCache에서 부른다)
    -- 같은 보관함 아이템을 주는, 아직 열지 않은 완료 줄 하나에 나온 골드를 적는다
    function QTR.NavCacheOpened(itemID, gained)
        local list = QTR.routeDoneList
        if not list or not gained or gained <= 0 then
            return
        end
        local target
        for _, d in ipairs(list) do
            if d.cache and not d.cacheGold and d.cacheItem == itemID then
                target = d
                break
            end
        end
        if not target then
            return
        end
        target.cacheGold = gained
        QTR.RoutePopupUpdate()
    end

    -- 창을 앞에 띄울 자리: 저장한 자리, 없으면 메인 창 오른쪽, 메인 창이 닫혀 있으면 화면 가운데
    local function PlacePopup()
        pop:ClearAllPoints()
        local p = DB.settings.routePopPos
        if p then
            pop:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
        elseif f:IsShown() then
            pop:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
        else
            pop:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    -- 내비게이션 창 크기 설정(navScale)을 적용한다. 저장 위치 좌표는 QTR.ApplyUIScale이 미리 고쳐 둔다
    function QTR.ApplyRouteScale()
        pop:SetScale(DB.settings.navScale or 1)
        if pop:IsShown() then
            PlacePopup()
            QTR.RoutePopupUpdate()
        end
    end

    local function ShowPopup()
        if not pop:IsShown() then
            PlacePopup()
            UpdatePinLook()
            pop:Show()
        end
    end

    -- open: 닫혀 있어도 연다 (내비게이션 버튼, 단축키, /qtr route). 그 밖에는 열려 있을 때만 고쳐 그린다.
    -- 경로도 완료 기록도 없으면 대기 화면을 그린다.
    function QTR.RoutePopupUpdate(open)
        if not open and not pop:IsShown() then
            return
        end
        local rowFont = SetPopFont() -- 작은 글씨 설정에 맞춘 줄 높이와 글꼴
        local doneList = QTR.routeDoneList or {}
        local route = QTR.route or {}
        if #route == 0 and #doneList == 0 then
            QTR.RoutePopupIdle()
            return
        end
        -- 그릴 줄 목록: { text, zone, right, color, indent, first }
        local lines, num = {}, 0
        local doneGold, doneCache, doneCount, expiredCount, skippedCount = 0, 0, 0, 0, 0
        for _, d in ipairs(doneList) do
            num = num + 1
            local doneAt = d.t and (" " .. date("%H:%M", d.t)) or ""
            if d.skipped then
                -- "이번만" 뺀 곳: 회색, 지역명 뒤에 빨간 X와 뺀 시각, 오른쪽 칸은 비운다 (완료 수, 골드에는 넣지 않는다)
                skippedCount = skippedCount + 1
                -- 우클릭하면 다시 경로에 넣을 수 있다 (canUndo)
                table.insert(lines, { text = num .. ". " .. tostring(d.title or ""),
                    zone = ZoneText(d.zone) .. " " .. SKIP_MARK .. doneAt, questID = d.questID,
                    right = "", color = "ff808080", canUndo = true,
                    menuTitle = tostring(d.title or d.questID or "") .. ZoneText(d.zone) })
            elseif d.expired then
                -- 만료로 빠진 곳: 회색, 지역명 뒤에 시계 아이콘과 만료 시각, 오른쪽 칸은 비운다 (완료 수, 골드에는 넣지 않는다)
                expiredCount = expiredCount + 1
                table.insert(lines, { text = num .. ". " .. tostring(d.title or ""),
                    zone = ZoneText(d.zone) .. " " .. EXPIRED_MARK .. doneAt, questID = d.questID,
                    right = "", color = "ff808080" })
            else
                doneCount = doneCount + 1
                doneGold = doneGold + DoneMoney(d)
                if d.cache and not d.cacheGold then
                    doneCache = doneCache + 1 -- 아직 열지 않은 보관함
                end
                -- 완료한 곳: 회색 글씨, 지역명 뒤에 녹색 체크와 완료 시각 ("1. 축하의 발톱을 (똬리의 섬) 체크 21:05")
                table.insert(lines, { text = num .. ". " .. tostring(d.title or ""),
                    zone = ZoneText(d.zone) .. " " .. DONE_CHECK .. doneAt, questID = d.questID,
                    right = RewardText(d, true), color = "ff808080" })
            end
        end
        local now = time()
        local leftGold, leftCache, places, portals, hearths = 0, 0, 0, 0, {}
        for i, r in ipairs(route) do
            local line
            if r.portal then
                portals = portals + 1
                local pt = PORTALS[r.portal]
                line = { text = L["포탈: %s"]:format(pt.name), zone = ZoneText(pt.zone), right = "", color = PORTAL_COLOR, indent = 16 }
            elseif r.travel then
                -- 귀환석, 영혼의 귀환, 아르칸티나 열쇠, 순간이동: 포탈처럼 하늘색, 들여쓰기, 지역은 따로 ("귀환석: 나그네의 쉼터" + " (실버문)")
                hearths[r.travel] = (hearths[r.travel] or 0) + 1
                line = { text = tostring(r.travelText or r.label), zone = ZoneText(r.innZone), right = "", color = PORTAL_COLOR, indent = 16 }
            else
                num = num + 1
                places = places + 1
                leftGold = leftGold + (r.money or 0)
                if r.cache then
                    leftCache = leftCache + 1
                end
                line = { text = num .. ". " .. tostring(r.title or r.questID or ""), zone = ZoneText(r.zone),
                    right = RewardText(r), color = "ffffffff", questID = r.questID, canFirst = true,
                    menuTitle = tostring(r.title or r.questID or "") .. ZoneText(r.zone) }
                if r.locked then
                    -- 해금 예정 특별 과제: 회색, 지역명 뒤에 "해금 예정" (아직 할 수 없어 툴팁, 우클릭 메뉴 없음)
                    line.color, line.questID, line.canFirst = "ffaaaaaa", nil, nil
                    line.zone = line.zone .. L[" 해금 예정"]
                end
                -- 만료 30분 미만: 주황색, 지역명 뒤에 남은 시간
                if r.expire and r.expire - now < NAV_URGENT then
                    line.color = "ffff9900"
                    local leftText = QTR.FormatTimeLeft(math.max(1, r.expire - now)):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    line.zone = line.zone .. " " .. leftText
                end
            end
            line.first = (i == 1)
            table.insert(lines, line)
        end
        -- 최대 줄 수: 창 크기를 키웠을 때 화면 밖으로 넘치지 않게 화면 높이(창 배율 기준)에 맞춰 줄인다 (머리, 아랫줄 몫 약 170)
        local maxLines = math.max(8, math.min(POP_MAXLINES, math.floor((UIParent:GetHeight() / pop:GetScale() - 170) / POP_LINE)))
        -- 너무 길면 완료한 곳을 한 줄로 줄인다
        if #lines > maxLines and #doneList > 0 then
            local rest = {}
            table.insert(rest, { text = L["완료 %d곳"]:format(doneCount) .. (expiredCount > 0 and L[", 만료 %d곳"]:format(expiredCount) or "")
                .. (skippedCount > 0 and L[", 건너뜀 %d곳"]:format(skippedCount) or ""),
                zone = " " .. DONE_CHECK, right = "", color = "ff808080" })
            for k = #doneList + 1, #lines do
                table.insert(rest, lines[k])
            end
            lines = rest
        end
        -- 그래도 길면 뒤를 줄인다
        if #lines > maxLines then
            local hidden = #lines - (maxLines - 1)
            for k = #lines, maxLines, -1 do
                lines[k] = nil
            end
            table.insert(lines, { text = L["외 %d줄"]:format(hidden), right = "", color = "ffaaaaaa" })
        end

        -- 윗줄: "전체 목적지 12곳 중 완료 3곳, 만료 1곳, 잔여 8곳 (포탈 2번)" (포탈 부분만 하늘색, 만료는 있을 때만)
        local sub = L["전체 목적지 %d곳 중 완료 %d곳"]:format(#doneList + places, doneCount)
            .. (expiredCount > 0 and L[", 만료 %d곳"]:format(expiredCount) or "")
            .. (skippedCount > 0 and L[", 건너뜀 %d곳"]:format(skippedCount) or "")
        local viaText
        if places > 0 then
            sub = sub .. L[", 잔여 %d곳"]:format(places)
            local via = {}
            if portals > 0 then
                table.insert(via, L["포탈 %d번"]:format(portals))
            end
            for _, key in ipairs({ "mage", "root", "hearth", "astral", "arcantina", "maisara", "dundun", "delvebot" }) do
                if hearths[key] then
                    table.insert(via, L["%s %d번"]:format(TV.NAMES[key], hearths[key]))
                end
            end
            if #via > 0 then
                viaText = "|c" .. PORTAL_COLOR .. "(" .. table.concat(via, ", ") .. ")|r"
            end
        else
            sub = sub .. L[", |cff40ff40모두 마쳤습니다.|r"]
        end
        popSub:SetText(viaText and (sub .. " " .. viaText) or sub)
        -- 이동 수단이 여럿이면 창 밖으로 넘치므로 괄호 부분을 둘째 줄로 내리고 목록도 그만큼 내린다 (2026-10-31 사용자 요청)
        local subExtra = 0
        if viaText and (popSub:GetStringWidth() or 0) > POP_W - 24 then
            local h1 = popSub:GetStringHeight() or 0
            popSub:SetText(sub .. "\n" .. viaText)
            subExtra = math.max(0, (popSub:GetStringHeight() or 0) - h1)
        end

        popBand:Hide()
        local y = POP_TOP - subExtra
        for k, line in ipairs(lines) do
            local row = PopRow(k)
            -- 글꼴을 먼저 바꿔야 아래에서 잰 글자 폭이 맞다
            row.name:SetFontObject(rowFont)
            row.zone:SetFontObject(rowFont)
            row.right:SetFontObject(rowFont)
            row.hit:SetSize(POP_W - 16, POP_LINE)
            local indent = line.indent or 0
            -- 이름 칸이 모자라면 퀘스트 이름만 줄이고("긴 퀘스트 이름..."), 뒤의 지역명은 그대로 둔다
            -- 오른쪽 칸은 실제 글자 폭만큼만 비운다 (포탈 줄처럼 비어 있으면 이름이 그 자리까지 쓴다, 2026-10-31. 전에는 늘 90)
            row.right:SetText(line.right or "")
            local rightW = ((line.right or "") ~= "") and math.min(POP_RIGHT_W, (row.right:GetStringWidth() or POP_RIGHT_W) + 8) or 0
            local avail = POP_W - 24 - rightW - indent - 6
            local zoneText = line.zone or ""
            row.zone:SetText(zoneText ~= "" and ("|c" .. line.color .. zoneText .. "|r") or "")
            local zoneW = (zoneText ~= "") and (row.zone:GetStringWidth() or 0) or 0
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", pop, "TOPLEFT", 12 + indent, y)
            row.name:SetWidth(0) -- 너비 제한을 풀고 원래 길이를 잰다
            row.name:SetText("|c" .. line.color .. line.text .. "|r")
            local nameW = (row.name.GetUnboundedStringWidth and row.name:GetUnboundedStringWidth())
                or row.name:GetStringWidth() or 0
            row.name:SetWidth(math.max(20, math.min(nameW + 1, avail - zoneW)))
            row.name:Show()
            row.zone:ClearAllPoints()
            row.zone:SetPoint("LEFT", row.name, "RIGHT", 0, 0)
            row.zone:SetShown(zoneText ~= "")
            row.right:ClearAllPoints()
            row.right:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -12, y)
            row.right:Show()
            -- 퀘스트 줄만 툴팁 영역을 켠다
            row.hit.tipQuest = line.questID
            row.hit.canFirst = line.canFirst
            row.hit.canUndo = line.canUndo
            row.hit.menuTitle = line.menuTitle
            row.hit:ClearAllPoints()
            row.hit:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, y + 2)
            row.hit:SetShown(line.questID ~= nil)
            if line.first then
                popBand:ClearAllPoints()
                popBand:SetPoint("TOPLEFT", pop, "TOPLEFT", 8, y + 2)
                popBand:Show()
            end
            y = y - POP_LINE
        end
        for k = #lines + 1, #popRows do
            popRows[k].name:Hide()
            popRows[k].zone:Hide()
            popRows[k].right:Hide()
            popRows[k].hit:Hide()
        end

        -- 아랫줄 (흰색): 안내 중이면 "체크 획득 5,045  남은 골드 969" (열지 않은 보관함, 남은 보관함 수는 뒤에 붙인다)
        --               다 마쳤으면 결과 한 줄: "체크 소요 시간 17분, 퀘스트 5개, 획득 골드 6,015, 진척도 +0.09%p"
        local doneText = FormatGold(doneGold) .. (doneCache > 0 and L[", 정점 보관함 %d개"]:format(doneCache) or "")
        local foot
        local wrapped = false
        if places > 0 then
            foot = DONE_CHECK .. "|cffffffff" .. L["획득 %s  남은 골드 %s"]:format(doneText, FormatGold(leftGold))
            if leftCache > 0 then
                foot = foot .. L[", 정점 보관함 %d개"]:format(leftCache)
            end
            foot = foot .. "|r"
        else
            local elapsed = (QTR.navStart and QTR.navFinish) and (QTR.navFinish - QTR.navStart) or nil
            local goal = GetGoalGold() * 10000
            local pct = (goal > 0) and string.format("+%.2f%%p", doneGold / goal * 100) or "-"
            local head = DONE_CHECK .. "|cffffffff" .. L["소요 시간 %s, 퀘스트 %d개, 획득 골드 %s"]:format(elapsed and FormatDuration(elapsed) or "-", doneCount, FormatGold(doneGold))
            local cachePart = (doneCache > 0) and L[", 정점 보관함 %d개"]:format(doneCache) or ""
            local pctPart = L[", 진척도 |cff00ff00%s|r"]:format(pct)
            foot = head .. cachePart .. "|r" .. pctPart
            -- 창보다 길면 "정점 보관함"(없으면 "진척도")부터 다음 줄로 (2026-11-08 사용자 요청: 완료 결과가 창 밖으로 넘쳤다)
            popFoot:SetText(foot)
            if (popFoot:GetStringWidth() or 0) > POP_W - 24 then
                local rest = (cachePart .. pctPart):gsub("^,%s*", "")
                foot = head .. ",|r\n|cffffffff" .. rest .. "|r"
                wrapped = true
            end
        end
        local footLines = wrapped and 2 or 1
        -- 다 마쳤으면 결과 아래에 다음 추천 캐릭터 (한 바퀴를 끝낸 지금이 다음 캐릭터를 고를 때)
        if places == 0 and QTR.RecommendText then
            foot = foot .. "\n" .. QTR.RecommendText()
            footLines = footLines + 1
        end
        popFoot:ClearAllPoints()
        popFoot:SetPoint("TOPLEFT", pop, "TOPLEFT", 12, y - 6)
        popFoot:SetText(foot)
        -- 다음 추천 캐릭터 이름에 마우스를 올리면 추천 이유 (마지막 줄)
        if places == 0 and QTR.recLast then
            local hgt = popFoot.GetStringHeight and popFoot:GetStringHeight() or 0
            QTR.PlaceRecHover(pop, popFoot, hgt * (footLines - 1) / footLines)
        elseif QTR.recHovers[popFoot] then
            QTR.recHovers[popFoot]:Hide()
        end
        -- 안내 중이면 오른쪽 아래 "경로안내 중지", 다 마쳤으면 "대시보드로 돌아가기"
        popActBtn.backOnly = false
        popActBtn:SetText(#route > 0 and L["경로안내 중지"] or L["대시보드로 돌아가기"])
        popActBtn:ClearAllPoints()
        popActBtn:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -10, 10)

        pop:SetHeight(-y + 6 + 16 * footLines + 8 + 22 + 10)
        ShowPopup()
    end

    -- 대기 화면 (안내 중이 아니고 완료 기록도 없을 때)
    --   회색 "현재 내비게이션 대기중", 지금 넣을 수 있는 곳(골드퀘 수와 골드 합계, 특별 과제 수),
    --   그 밑 가운데에 "내비게이션 시작!" 버튼 (넣을 곳이 없으면 "대시보드로 돌아가기")
    function QTR.RoutePopupIdle()
        if QTR.recHovers[popFoot] then
            QTR.recHovers[popFoot]:Hide()
        end
        popSub:SetText(L["|cff808080현재 내비게이션 대기중|r"])
        popBand:Hide()
        for k = 1, #popRows do
            popRows[k].name:Hide()
            popRows[k].zone:Hide()
            popRows[k].right:Hide()
            popRows[k].hit:Hide()
        end
        local gq, cache, gold = 0, 0, 0
        local lockedCount = 0
        for _, p in ipairs(CollectRoutePoints()) do
            if p.locked then
                lockedCount = lockedCount + 1
            elseif p.cache then
                cache = cache + 1
            else
                gq = gq + 1
                gold = gold + (p.money or 0)
            end
        end
        local row = PopRow(1)
        row.name:SetFontObject(SetPopFont())
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", pop, "TOPLEFT", 12, POP_TOP)
        row.name:SetWidth(POP_W - 24)
        if gq + cache > 0 then
            local text = L["넣을 수 있는 곳: 골드퀘 %d곳"]:format(gq)
            if cache > 0 then
                text = text .. L[", 특별 과제 %d곳"]:format(cache)
            end
            if lockedCount > 0 then
                text = text .. L[", 해금 예정 %d곳"]:format(lockedCount)
            end
            row.name:SetText(text)
            popFoot:SetText(L["|cffaaaaaa골드 합계 |r"] .. FormatSubGold(gold) .. L["|cffaaaaaa, 가까운 순서로 동선을 짭니다.|r"])
        else
            row.name:SetText(L["|cff808080지금 내비게이션에 넣을 골드퀘가 없습니다.|r"])
            popFoot:SetText(L["|cff808080위치를 아는, 아직 안 한 골드퀘와 특별 과제만 넣습니다.|r"])
        end
        row.name:Show()
        popFoot:ClearAllPoints()
        popFoot:SetPoint("TOPLEFT", pop, "TOPLEFT", 12, POP_TOP - POP_LINE - 4)
        -- 넣을 곳이 없으면 시작해도 할 일이 없으니 "대시보드로 돌아가기" (2026-10-30 사용자 요청)
        popActBtn.backOnly = (gq + cache == 0)
        popActBtn:SetText(popActBtn.backOnly and L["대시보드로 돌아가기"] or L["내비게이션 시작!"])
        popActBtn:ClearAllPoints()
        popActBtn:SetPoint("TOP", pop, "TOP", 0, POP_TOP - POP_LINE - 4 - 16 - 12)
        pop:SetHeight(-(POP_TOP - POP_LINE - 4 - 16 - 12) + 22 + 12)
        ShowPopup()
    end

    -- 내비게이션 창 열기/닫기 (단축키)
    function QuestsToRiches_ToggleRoute()
        if not DB then
            return
        end
        if pop:IsShown() then
            pop:Hide()
        else
            QTR.RoutePopupUpdate(true)
        end
    end

    -- 골드퀘 탭 오른쪽 위 버튼: 왼쪽 클릭 내비게이션 시작(내비게이션 창에 동선 표시), 오른쪽 클릭 경로안내 중지
    -- 내비게이션을 시작하고 내비게이션 창을 연다. 대시보드(메인 창)는 닫는다 (버튼, 단축키 R)
    function QTR.NavStartFromDashboard()
        QTR.RouteStart()
        QTR.RoutePopupUpdate(true)
        f:Hide()
    end

    -- 내비게이션 시작 단축키 (2026-11-08 사용자 요청: 창 열기, 1, R을 한 번에). 버튼을 누른 것과 같다
    function QuestsToRiches_StartNav()
        if not DB then
            return
        end
        QTR.NavStartFromDashboard()
    end

    local routeBtn = CreateButton(gqPanel, L["내비게이션 시작!"], 110, "R")
    routeBtn:SetPoint("TOPRIGHT", gqPanel, "TOPRIGHT", -20, -4)
    -- 글자가 110에 안 들어가면 (영어 "Start Navigation!") 글자 폭 + 24로 넓힌다 (오른쪽 끝 고정이라 왼쪽으로 늘어난다, 2026-10-31)
    --   기준 106: 버튼 글자는 108 언저리에서 잘린다. 한국어 "내비게이션 시작!"은 들어가므로 110 그대로
    -- 불러오는 순간에는 글꼴 폭이 정확하지 않을 수 있어 창이 보일 때 다시 잰다
    local function FitRouteBtn(self)
        local fs = self.GetFontString and self:GetFontString()
        local w = fs and fs:GetStringWidth() or 0
        if w > 106 then
            self:SetWidth(math.ceil(w) + 24)
        end
    end
    FitRouteBtn(routeBtn)
    routeBtn:HookScript("OnShow", FitRouteBtn)
    routeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    routeBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            QTR.RouteClear()
        else
            QTR.NavStartFromDashboard()
        end
    end)
    routeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["내비게이션 시작!"])
        GameTooltip:AddLine(L["남은 골드퀘와 정점 보관함 특별 과제를 가까운 순서로 이어 안내합니다."], 1, 1, 1, true)
        GameTooltip:AddLine(L["포탈이 빠르면 포탈 위치를 먼저 안내하고, 포탈을 타면 다음 목적지로 넘어갑니다."], 1, 1, 1, true)
        GameTooltip:AddLine(L["TomTom이 있으면 전체 경로를 등록하고, 없으면 게임 웨이포인트로 한 곳씩 안내합니다."], 1, 1, 1, true)
        GameTooltip:AddLine(L["편성한 동선은 내비게이션 창으로 보여 줍니다."], 1, 1, 1, true)
        GameTooltip:AddLine(L["왼쪽 클릭: 내비게이션 시작 / 오른쪽 클릭: 경로안내 중지"], 0.25, 1, 0.25)
        GameTooltip:AddLine(L["단축키 R: 내비게이션 시작 (창 위에 마우스가 있을 때, 전투 중이 아닐 때)"], 0.25, 1, 0.25, true)
        GameTooltip:AddLine(L["시작하면 이 창은 닫히고 내비게이션 창이 열립니다."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    routeBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end
QTR.SetupRoute()

-- 메인 청크의 local 개수 제한(200) 때문에 아래 local들은 함수 안에 두고 바로 실행한다
-- 골드퀘 탭에서도 쓰는 함수는 QTR에 붙여 밖으로 꺼낸다.
QTR.SetupRichTab = function()
-------------------------------------------------------------------------------
-- 정점 보관함 출처의 완료 판정 (골드퀘 탭, 부자되기 탭 공용)
-------------------------------------------------------------------------------

-- 출처 이름: 특별 과제는 앞의 "특별 과제:"를 떼고 보여준다
local function GetSourceName(src)
    if src.kind == "item" then
        return GetItemNameSafe(src.itemID)
    end
    local title = QTR.ShownTitle(src.questID, src.title) or GetKnownQuestTitle(src.questID) or L["퀘스트 %s"]:format(src.questID)
    return QTR.NoPrefix(title)
end

-- 이번 주에 받을 수 있는 출처인지: 이번 주에 보상을 본 퀘스트, 또는 퀘스트 없이 받은 보관함(매주 받는다고 본다)
local function IsSourceThisWeek(src, weekStart)
    if src.kind == "item" then
        return true
    end
    -- 특별 과제 ID 표에 있는 퀘스트: 게임이 남은 시간을 알려주면(잠겨 있어도) 이번 주 특별 과제다.
    -- 그 남은 시간으로 만료 시각도 바로잡는다. 시간을 못 읽으면 아래 판단(저장된 만료 시각 등)을 따른다.
    local left, from = QTR.GetSpecialTimeLeft(src.questID)
    if left then
        src.onMap = true
        src.expire = time() + left
        -- 특별 과제 자체에서 읽은 만료 시각인지 (잠김 상태용 퀘스트의 시간으로 덮지 않으려고, 2026-11-01)
        if from == "quest" then
            src.expireSeen = true
        elseif from == "unlock" then
            src.expireSeen = nil
        end
        return true
    end
    -- 지도에서 본 퀘스트(특별 과제 등)는 주간 초기화가 아니라 자기 만료 시각까지 할 수 있다
    -- (초기화 뒤에도 남아 있는 특별 과제가 있다)
    if src.onMap and src.expire then
        return src.expire > time()
    end
    return (src.lastSeen or 0) >= weekStart
end

-- 완료로 볼 기간의 시작: 보통은 이번 주 초기화 시각,
-- 만료 시각을 아는 특별 과제는 그 회차의 시작(만료 7일 전)부터 본다
-- (초기화 전에 완료한 특별 과제가 초기화 뒤 미완료로 바뀌지 않게, 지난 회차 완료는 세지 않게)
local SPECIAL_MAX_DURATION = 7 * 86400
local function GetSourceSince(src, weekStart)
    if src.onMap and src.expire then
        return src.expire - SPECIAL_MAX_DURATION
    end
    return weekStart
end

-- 조건에 맞는 보관함 획득 중 가장 이른 시각 (없으면 nil)
local function GetCacheGetTime(key, since, match)
    local first
    for _, g in ipairs(DB.cacheGets[key] or {}) do
        if (g.t or 0) >= since and match(g) and (not first or g.t < first) then
            first = g.t
        end
    end
    return first
end

-- 반환: 이번 주(특별 과제는 이번 회차) 완료 시각 (시각을 모르면 math.huge), 미완료면 nil
local function GetSourceDoneTime(key, src, weekStart)
    if src.kind == "item" then
        return GetCacheGetTime(key, weekStart, function(g) return g.id == src.itemID end)
    end
    local since = GetSourceSince(src, weekStart)
    return GetQuestDoneTime(key, src.questID, since)
        or GetCacheGetTime(key, since, function(g) return g.q == src.questID end)
end

local function IsSourceDoneBy(key, src, weekStart)
    return GetSourceDoneTime(key, src, weekStart) ~= nil
end

-- 받은 보관함을 연 골드 (2026-11-11 사용자 요청: 부자되기 탭 보관함 줄에 대박 표시, 동기부여)
--   연 기록(days의 caches)에는 출처가 없어, 같은 캐릭터의 같은 보관함을 받은 차례와 연 차례로 짝짓는다 (먼저 받은 것을 먼저 열었다고 본다).
--   받은 시각보다 앞선 연 기록은 그 받은 기록의 짝으로 쓰지 않는다. 결과: { [받은 기록] = 연 골드 중 가장 큰 것(코퍼) }
function QTR.CacheOpenMatch(key)
    local byTime = function(a, b) return (a.t or 0) < (b.t or 0) end
    local opens, gets = {}, {}
    for _, day in pairs(DB.days) do
        local rec = day[key]
        for _, c in ipairs(rec and rec.caches or {}) do
            opens[c.id] = opens[c.id] or {}
            table.insert(opens[c.id], c)
        end
    end
    for _, g in ipairs(DB.cacheGets[key] or {}) do
        gets[g.id] = gets[g.id] or {}
        for _ = 1, math.max(1, g.n or 1) do
            table.insert(gets[g.id], g)
        end
    end
    local match = {}
    for id, list in pairs(gets) do
        table.sort(list, byTime)
        local ol = opens[id] or {}
        table.sort(ol, byTime)
        local j = 1
        for _, g in ipairs(list) do
            while ol[j] and (ol[j].t or 0) < (g.t or 0) do
                j = j + 1
            end
            if ol[j] then
                match[g] = math.max(match[g] or 0, ol[j].money or 0)
                j = j + 1
            end
        end
    end
    return match
end

-- since 뒤에 받은 보관함 중 match에 맞는 것을 열어 나온 골드의 가장 큰 값 (연 기록이 없으면 nil)
function QTR.OpenGoldSince(key, since, match)
    local opened, best = nil, nil
    for _, g in ipairs(DB.cacheGets[key] or {}) do
        if (g.t or 0) >= since and match(g) then
            opened = opened or QTR.CacheOpenMatch(key)
            local m = opened[g]
            if m and (not best or m > best) then
                best = m
            end
        end
    end
    return best
end
-- 이 출처(src)로 이번 주(특별 과제는 이번 회차)에 받은 보관함
function QTR.SourceOpenGold(key, src, weekStart)
    return QTR.OpenGoldSince(key, GetSourceSince(src, weekStart), function(g)
        if src.kind == "item" then
            return g.id == src.itemID
        end
        return g.q == src.questID
    end)
end
-- 부자되기 탭 펼친 캐릭터 줄의 오른쪽 칸: 미개봉 개수, 없으면 열어서 대박이었을 때 별과 "대박"/"초대박" (대박이 아니면 비움)
function QTR.CacheCellText(key, itemID, gold)
    local c = DB.chars[key]
    local n = c and c.cacheBag and c.cacheBag[itemID] or 0 -- GetUnopenedCount와 같다 (그 함수가 아래에 있어 직접 읽는다)
    if n > 0 then
        return L["|cffffd100미개봉 %d|r"]:format(n)
    end
    -- 금액 대신 "대박", "초대박" (2026-11-11 사용자 요청: 금액은 비슷비슷하니 말이 더 동기부여가 된다). 글자색은 채팅 대박 알림과 같은 주황
    local tier, star = QTR.JackpotTier(gold)
    if star then
        return star .. " |cffff8000" .. QTR.JACKPOT_NAMES[tier] .. "|r"
    end
end

-- 특별 과제 줄에서 아직 안 한 캐릭터의 상태 (2026-11-01 사용자 요청: 잠김과 해금했는데 미완료를 나눠서)
--   그 캐릭터로 이번 회차에 지도를 읽었을 때(DB.saLock) 잠겨 있었으면 회색 "잠김(n/3)", 해금했으면 nil (빨간 "미완료" 그대로)
--   이번 회차에 그 캐릭터로 읽은 적이 없으면 회색 "미확인"
--   지역: 특별 과제 ID 표, 없으면 전에 본 위치(wp)의 지도가 속한 지역
--   since: 이번 회차 시작. 지난 회차에 본 상태나 같은 지역 다른 특별 과제의 상태는 쓰지 않는다
--   반환: 상태 글자, 정렬 순서 (잠김 2, 미확인 3)
QTR.SpecialState = function(key, src, since)
    local sa = QTR.SPECIAL_ASSIGNMENTS[src.questID]
    local mapID = sa and sa.mapID
    if not mapID and src.wp then
        for _, zone in ipairs(GQ_ZONES) do
            if QTR.ZoneHasMap(zone, src.wp[1]) then
                mapID = zone.mapID
                break
            end
        end
    end
    if not mapID then
        return nil
    end
    local s = DB.saLock[key] and DB.saLock[key][mapID]
    if not s or (s.t or 0) < since or (s.q and s.q ~= src.questID) then
        return L["|cff808080미확인|r"], 3
    end
    if s.open then
        return nil
    end
    return L["|cffaaaaaa잠김(%d/%d)|r"]:format(s.p or 0, META_TOTAL), 2
end

-- 정점 보관함 줄의 남은 시간: 만료 시각을 아는 퀘스트(특별 과제 등)는 자기 남은 시간
-- (주간 초기화 뒤까지 남는 특별 과제도 있다), 모르면 주간 초기화까지
-- (만료 시각은 지도에서 퀘스트 남은 시간을 먼저 읽고, 못 읽었을 때만 주간 초기화 시각으로 채운다)
QTR.SourceTimeText = function(src, nextReset)
    local now = time()
    if src.onMap and src.expire and src.expire > now then
        return FormatTimeLeft(src.expire - now)
    end
    return FormatTimeLeft(nextReset - now)
end

-- 정점 보관함 줄의 이름: "퀘스트명 (지역명)" (지역을 모르면 이름만)
QTR.SourceLabel = function(src)
    local name = GetSourceName(src)
    local zone = src.zone
    -- 다른 언어로 저장된 지역 이름: 특별 과제는 그 지역 지도 이름을 게임에서 읽는다 (2026-10-31)
    if zone and QTR.WrongLang(zone) then
        local sa = QTR.SPECIAL_ASSIGNMENTS[src.questID]
        local info = sa and C_Map.GetMapInfo(sa.mapID)
        zone = (info and info.name) or zone
    end
    if zone and zone ~= "" then
        return name .. " (" .. QTR.ShortZone(zone) .. ")" -- 한국어가 아닌 클라이언트는 짧은 지역명 (2026-10-31)
    end
    return name
end

-- 출처 목록: 이번 주 출처 먼저, 그 안에서 지역, 이름 순
local function GetSortedSources(weekStart)
    local list = {}
    for key, src in pairs(DB.cacheSources) do
        local thisWeek = IsSourceThisWeek(src, weekStart)
        -- 지도에서 본 퀘스트(특별 과제 등)는 매주 바뀌므로 지금 할 수 있는 것만 보여준다
        -- (지난 출처가 "이번 주 미확인"으로 계속 쌓이지 않게)
        if not (QTR.IsMapSource(src) and not thisWeek) and not (src.kind == "quest" and QTR.IsHiddenQuest(src.questID)) then
            table.insert(list, { key = key, src = src, thisWeek = thisWeek })
        end
    end
    table.sort(list, function(a, b)
        if a.thisWeek ~= b.thisWeek then
            return a.thisWeek
        end
        local za, zb = a.src.zone or "", b.src.zone or ""
        if za ~= zb then
            return za < zb
        end
        return GetSourceName(a.src) < GetSourceName(b.src)
    end)
    return list
end

local function GetUnopenedCount(key, itemID)
    local c = DB.chars[key]
    return c and c.cacheBag and c.cacheBag[itemID] or 0
end

-- 이번 주에 받은 다른 정점 보관함 (특별 과제 보상 2종 말고): { { id, got = { [캐릭터키] = 받은 시각 } } }, 이름 순
--   받은 시각: 이번 주에 여러 개 받았으면 나중에 받은 것 (2026-10-29 사용자 결정: 실버문 주간 "잘아타스 추적"과
--   "한밤: 야외 우두머리"가 같은 최정상 보관함을 준다. 둘째를 받으면 시각이 바뀌어 보인다)
--   받은 기록(cacheGets)이 있으면 그것으로, 없으면 연 기록(days의 caches)으로 본다 (한 보관함의 받은 시각과 연 시각을
--   섞으면 하나만 받았어도 연 시각이 "나중에 받은 것"이 되므로 섞지 않는다. 연 기록은 받은 기록이 없던 그전 시험판 데이터용)
function QTR.OtherApexThisWeek(weekStart)
    local byID, list = {}, {}
    local function add(id, key, t, fromOpen)
        if not id or IsCacheItem(id) or (t or 0) < weekStart then
            return
        end
        local o = byID[id]
        if not o then
            o = { id = id, got = {}, fromGet = {} }
            byID[id] = o
            table.insert(list, o)
        end
        if fromOpen and o.fromGet[key] then
            return
        end
        if not fromOpen then
            o.fromGet[key] = true
        end
        if not o.got[key] or t > o.got[key] then
            o.got[key] = t
        end
    end
    for key, gets in pairs(DB.cacheGets) do
        for _, g in ipairs(gets) do
            add(g.id, key, g.t)
        end
    end
    local firstDay = TimeToDayKey(weekStart)
    for dayKey, day in pairs(DB.days) do
        if dayKey >= firstDay then
            for key, r in pairs(day) do
                for _, c in ipairs(r.caches or {}) do
                    add(c.id, key, c.t, true)
                end
            end
        end
    end
    table.sort(list, function(a, b) return GetItemNameSafe(a.id) < GetItemNameSafe(b.id) end)
    return list
end

-------------------------------------------------------------------------------
-- 부자되기 탭: 지금 할 수 있는 골드퀘와 이번 주 정점 보관함을 다른 캐릭터 중 누가 아직 안 했는지
--   항목 줄: 이름 | 남은 시간(또는 지역) | 보상 | 완료한 캐릭터 수 / 만렙 캐릭터 수
--   줄을 누르면 그 아래에 캐릭터별 완료 여부를 펼친다 (미완료가 위)
-- 골드퀘 목록은 각 캐릭터로 접속했을 때 지도에서 본 것을 계정 공용으로 모아 둔 것이다.
-- 완료 여부는 이 애드온이 기록한 퀘스트 완료(turnIns)로 판단한다.
-------------------------------------------------------------------------------

local rich = { expanded = {} }
rich.summary = CreateText(dashPanel, 20, -6, "GameFontNormal")
rich.sub = CreateText(dashPanel, 20, -26, "GameFontHighlightSmall")
rich.rec = CreateText(dashPanel, 20, -44, "GameFontHighlightSmall") -- 다음 추천 캐릭터
rich.list = CreateList(dashPanel, -64)

-- 항목 이름, 남은 시간, 보상 칸은 골드퀘 탭과 같은 칸(COL.gqQuest, COL.gqTime, COL.gold)을 써서
-- 1, 2번 탭을 오갈 때 목록이 같은 자리에 보이게 한다. 펼침 표시(+/-)는 이름 앞 빈 자리에 둔다.
-- 정점 보관함 줄만 COL.richCacheName, COL.richCacheTime (보상 칸이 아이콘뿐이라 이름을 더 넓게, 2026-10-31)
local RICH_COL = {
    mark = { x = 6, w = 14 },   -- 펼침 표시
    dot = { x = 20, w = 16 },   -- 완료 표시
    char = { x = 38, w = 138 }, -- 캐릭터 이름
}
local DONE_ICON = "|TInterface\\COMMON\\Indicator-Green:12:12:0:0|t"

local function GetTargetChars()
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    if maxLevel and maxLevel <= 0 then
        maxLevel = nil
    end
    local list = {}
    for key, c in pairs(DB.chars) do
        if not maxLevel or not c.level or c.level >= maxLevel then
            table.insert(list, key)
        end
    end
    table.sort(list)
    return list, maxLevel
end

-- 대상 캐릭터(만렙) 중 누군가 지도에서 본 골드퀘인가 (2026-11-11 사용자 결정 "부자되기 탭에 뜨는 퀘스트는 만렙 캐릭이 본 것만"):
--   84레벨 마래푸누렁스만 볼 수 있던 레벨업용 "어둠의 군대"(92566, 만렙용은 92571)가 만렙 기준 부자되기 탭에 0/7로 나왔고,
--   만렙 캐릭터는 접속할 때마다 "안 보임"이 되었다.
--   "볼 때 만렙이었는가"로 판단한다 (e.seenMax, 기록할 때 정한다). 사용자 지적: 마래푸가 나중에 90이 되어도 92566은 레벨업용이라 나오면 안 된다.
--   seenMax가 없는 예전 항목은 처음 볼 때 그때의 레벨로 한 번 정해 둔다 (본 캐릭터 기록 seenBy도 없으면 만렙이 본 것으로)
function QTR.SeenByTarget(e, targets)
    if e.seenMax == nil then
        local seen = not (e.seenBy and next(e.seenBy))
        for _, key in ipairs(targets) do
            if e.seenBy and e.seenBy[key] then
                seen = true
            end
        end
        e.seenMax = seen
    end
    return e.seenMax
end
-- 지금 캐릭터가 만렙인가 (최고 레벨을 못 읽으면 만렙으로 본다)
function QTR.IsMaxChar()
    local m = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    if not m or m <= 0 then
        return true
    end
    return (UnitLevel("player") or 0) >= m
end

local function FormatProgress(done, total)
    local color = "|cffffffff"
    if total > 0 and done >= total then
        color = "|cff00ff00"
    elseif done == 0 then
        color = "|cffff4444"
    end
    return color .. done .. "/" .. total .. "|r"
end

local function ToggleExpanded(key)
    return function()
        rich.expanded[key] = not rich.expanded[key]
        QTR:Refresh()
    end
end

local function ExpandMark(key)
    return rich.expanded[key] and "|cffffd100-|r" or "|cffffd100+|r"
end

-- 캐릭터별 줄: 미완료 먼저, 그 안에서 이름 순
-- 캐릭터별 줄 정렬
--   완료: 먼저, 완료 시각이 이른 순 (시각을 모르면 맨 뒤)
--   미완료: 서버별로 묶고(아즈샤라 먼저, 나머지는 가나다순), 서버 안에서 직업별로 묶은 뒤 이름 가나다순
local FIRST_REALM = QTR.GameText("FIRST_REALM") or "아즈샤라"

local function GetCharSortInfo(key)
    local c = DB.chars[key] or {}
    local name, realm = key:match("^(.-)%-(.+)$")
    realm = c.realm or realm or ""
    local className = c.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class or ""
    return realm, className, c.name or name or key
end

local function SortCharRows(rows)
    for _, r in ipairs(rows) do
        r.realm, r.className, r.name = GetCharSortInfo(r.key)
    end
    table.sort(rows, function(a, b)
        local da, db = a.t ~= nil, b.t ~= nil
        if da ~= db then
            return da
        end
        if da then
            if a.t ~= b.t then
                return a.t < b.t
            end
            return a.key < b.key
        end
        -- 미완료 중에서는 상태 순서대로: 수행중(실버문 주간 퀘스트를 받아 둠), 미완료, 잠김(특별 과제), 미확인
        if (a.rank or 1) ~= (b.rank or 1) then
            return (a.rank or 1) < (b.rank or 1)
        end
        if a.realm ~= b.realm then
            if a.realm == FIRST_REALM or b.realm == FIRST_REALM then
                return a.realm == FIRST_REALM
            end
            return a.realm < b.realm
        end
        if a.className ~= b.className then
            return a.className < b.className
        end
        return a.name < b.name
    end)
end

-- 설정창 캐릭터 고르기 목록의 순서 (2026-10-31 사용자 요청): 서버별(아즈샤라 먼저, 나머지는 가나다순), 서버 안에서 이름 가나다순
--   values: QTR.charOptValues 등이 돌려준 { [캐릭터키] = 표시 이름 }. AceConfig select의 sorting으로 쓴다
function QTR.charOptSorting(values)
    local keys, info = {}, {}
    for key in pairs(values) do
        table.insert(keys, key)
        local realm, _, name = GetCharSortInfo(key)
        info[key] = { realm = realm, name = name }
    end
    table.sort(keys, function(a, b)
        local ra, rb = info[a].realm, info[b].realm
        if ra ~= rb then
            if ra == FIRST_REALM or rb == FIRST_REALM then
                return ra == FIRST_REALM
            end
            return ra < rb
        end
        if info[a].name ~= info[b].name then
            return info[a].name < info[b].name
        end
        return a < b
    end)
    return keys
end

-- doneTime(캐릭터키): 완료 시각 (시각을 모르면 math.huge), 미완료면 nil
-- hidden: 이 퀘스트가 지도에 안 보이는 캐릭터 { [캐릭터키] = true } (맨 아래에 "안 보임"으로)
-- notGold: 이 캐릭터에게는 보상이 골드가 아님 { [캐릭터키] = true } (맨 아래에 "골드 아님"으로)
-- state(캐릭터키): 미완료일 때 "미완료" 대신 보일 상태 글자와 정렬 순서 (nil이면 "미완료", 순서 1)
--   실버문 주간 퀘스트 수행중 진행도(순서 0, 2026-11-01), 특별 과제 잠김(2), 리에드린 지난주 완료(2), 미확인(3)
local function AddCharRows(entries, targets, doneTime, extraText, hidden, notGold, state)
    local rows, hiddenRows = {}, {}
    for _, key in ipairs(targets) do
        if notGold and notGold[key] and not doneTime(key) then
            table.insert(hiddenRows, { key = key, notGold = true })
        elseif hidden and hidden[key] and not doneTime(key) then
            table.insert(hiddenRows, { key = key })
        else
            local r = { key = key, t = doneTime(key) }
            if not r.t and state then
                r.status, r.rank = state(key)
            end
            table.insert(rows, r)
        end
    end
    SortCharRows(rows)
    SortCharRows(hiddenRows)
    for _, r in ipairs(hiddenRows) do
        r.hidden = true
        table.insert(rows, r)
    end
    for _, r in ipairs(rows) do
        local status
        if r.hidden then
            status = r.notGold and L["|cff808080골드 아님|r"] or L["|cff808080안 보임|r"]
        elseif not r.t then
            status = r.status or L["|cffff4444미완료|r"]
        elseif r.t == math.huge then
            status = L["|cff00ff00완료|r"]
        else
            -- "17(토) 14:02": 최근 일주일 안의 기록만 보이므로 월은 빼고 요일로 구분한다
            local green = "|cff00ff00"
            status = green .. tonumber(date("%d", r.t)) .. FormatWeekday(r.t, green) .. " " .. date("%H:%M", r.t) .. "|r"
        end
        local cells = {
            Cell(r.t and DONE_ICON or "", RICH_COL.dot),
            Cell(ColorName(r.key), RICH_COL.char),
            Cell(status, COL.mid),
        }
        local extra = extraText and extraText(r.key)
        if extra then
            table.insert(cells, Cell(extra, COL.gold, "RIGHT"))
        end
        table.insert(entries, cells)
    end
end

-- 다음 접속 추천 캐릭터 (부자되기 탭 셋째 줄, 내비게이션 완료 화면). 지금 캐릭터와 만렙이 아닌 캐릭터는 뺀다
--   1) 가장 빨리 끝나는 골드퀘를 아직 안 한 캐릭터들로 후보를 좁힌다 (모두 했으면 그다음으로 빨리 끝나는 퀘스트)
--   2) 후보 중 아직 안 한 골드퀘의 골드 합계가 가장 큰 캐릭터
--   3) 골드가 비슷하면(1등과 1,000골드 이내) 지금 캐릭터와 같은 서버의 캐릭터를 먼저 (캐릭터 선택창의 서버 전환 시간)
--   세지 않는 퀘스트: 10분 안에 끝나는 것(캐릭터를 바꾸고 날아가기 전에 끝난다), 정점 보관함 보상, 추적 제외,
--   그 캐릭터 지도에 안 보이는 것, 그 캐릭터에게는 보상이 골드가 아닌 것(notGoldFor, 보상은 캐릭터마다 다를 수 있다)
--   정점 보관함은 보지 않는다: 특별 과제는 캐릭터마다 해금 진행(3개 중 몇 개)을 알 수 없어 받을 수 있을지 모른다 (사용자 결정)
--   반환: { key, count, money(코퍼), sameRealm, urgent(1번 기준 퀘스트) } 또는 nil
local REC_SOON = 600          -- 이 시간(초) 안에 끝나는 퀘스트는 세지 않는다 (처음 30분이었으나 1번 기준이 생겨 줄임)
local REC_NEAR = 1000 * 10000 -- 1등과 이 골드(코퍼) 차이 안이면 같은 서버를 먼저
function QTR.RecommendNextChar()
    local now = time()
    local targets = GetTargetChars()
    local quests = {}
    for questID, e in pairs(DB.activeGQ) do
        if (not e.expire or e.expire - now > REC_SOON) and not e.cacheItem and not QTR.IsHiddenQuest(questID)
            and QTR.SeenByTarget(e, targets) then
            table.insert(quests, { id = questID, e = e, since = GetGQInstanceStart(questID, e) })
        end
    end
    local myRealm = charKey and GetCharSortInfo(charKey)
    local all = {}
    for _, key in ipairs(targets) do
        if key ~= charKey then
            local r = { key = key, count = 0, money = 0, realm = GetCharSortInfo(key), todo = {} }
            for _, q in ipairs(quests) do
                -- 그 캐릭터 지도에 안 보이거나, 그 캐릭터에게는 보상이 골드가 아닌 퀘스트(마지막으로 봤을 때 기준)는 세지 않는다
                local hidden = (q.e.hiddenFor and q.e.hiddenFor[key]) or (q.e.notGoldFor and q.e.notGoldFor[key])
                if not hidden and not GetQuestDoneTime(key, q.id, q.since) then
                    r.count = r.count + 1
                    r.money = r.money + (q.e.money or 0)
                    r.todo[q.id] = true
                end
            end
            if r.money > 0 then
                table.insert(all, r)
            end
        end
    end
    if #all == 0 then
        return nil
    end
    -- 1) 가장 빨리 끝나는 퀘스트부터 보며, 그 퀘스트를 안 한 캐릭터가 있으면 그 캐릭터들만 후보로 남긴다
    table.sort(quests, function(a, b)
        local ea, eb = a.e.expire or math.huge, b.e.expire or math.huge
        if ea ~= eb then
            return ea < eb
        end
        return a.id < b.id
    end)
    local list, urgent = all, nil
    for _, q in ipairs(quests) do
        local pool = {}
        for _, r in ipairs(all) do
            if r.todo[q.id] then
                table.insert(pool, r)
            end
        end
        if #pool > 0 then
            list, urgent = pool, q
            break
        end
    end
    -- 직업 선호 (2026-11-08 사용자 요청): 1번 다음, 골드보다 먼저. 선호 1, 보통 2(기본), 비선호 3 (설정 classPref)
    local richest
    for _, r in ipairs(list) do
        r.tier = QTR.ClassTier(r.key)
        if not richest or r.money > richest.money then
            richest = r
        end
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then
            return a.tier < b.tier
        end
        if a.money ~= b.money then
            return a.money > b.money
        end
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.key < b.key
    end)
    local best = list[1]
    -- 툴팁에 쓸 추천 이유: 1번으로 좁혔는가, 직업 선호 때문에 골드가 더 많은 캐릭터를 건너뛰었는가, 같은 서버로 바꿨는가
    local function done(r, realmOver)
        r.sameRealm, r.urgent = (r.realm == myRealm), urgent
        r.narrowed = (#list < #all)
        r.richer = (richest ~= r and richest.money > r.money and richest.tier > r.tier) and richest or nil
        r.realmOver = realmOver
        r.tiersUsed = QTR.ClassPrefUsed()
        r.hasPref = false
        for _, c in ipairs(list) do
            if c.tier == 1 then
                r.hasPref = true
            end
        end
        return r
    end
    if myRealm and best.realm ~= myRealm then
        for _, r in ipairs(list) do
            if r.realm == myRealm and r.tier == best.tier and best.money - r.money <= REC_NEAR then
                return done(r, best)
            end
        end
    end
    return done(best)
end

-- 직업 선호 단계: 1 선호, 2 보통, 3 비선호 (DB.settings.classPref[직업 토큰])
QTR.recHovers = {} -- 추천 줄 글자 칸별 이름 위 마우스 영역 (QTR.PlaceRecHover, 글자 칸에 직접 두지 않는다)
QTR.CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
    "DRUID", "DEMONHUNTER", "EVOKER" }
function QTR.ClassTier(key)
    local c = DB.chars[key]
    local p = DB.settings.classPref
    return (c and c.class and p and p[c.class]) or 2
end
function QTR.ClassPrefUsed()
    for _, v in pairs(DB.settings.classPref or {}) do
        if v ~= 2 then
            return true
        end
    end
    return false
end

-- 추천 이유 툴팁 (2026-11-08 사용자 요청: 추천 줄에 글을 붙이지 말고 캐릭터 이름에 마우스를 올리면 보이게)
function QTR.ShowRecTip(owner)
    local r = QTR.recLast
    if not r then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(ColorName(r.key))
    GameTooltip:AddLine(L["추천 이유"], 1, 0.82, 0)
    local function add(text)
        GameTooltip:AddLine("- " .. text, 1, 1, 1, true)
    end
    if r.narrowed and r.urgent then
        local e = r.urgent.e
        local left = e.expire and (e.expire - time()) or nil
        add(L["가장 빨리 끝나는 골드퀘 %s을(를) 아직 하지 않은 캐릭터 중에서 골랐습니다%s."]:format(tostring(e.name or r.urgent.id),
            (left and left > 0) and L[" (%s 남음)"]:format(FormatDuration(left)) or ""))
    end
    if r.tiersUsed then
        local _, className = GetCharSortInfo(r.key)
        if r.tier == 1 then
            add(L["선호 직업(%s)입니다."]:format(className))
        elseif r.tier == 3 then
            add(L["비선호 직업(%s)이지만 다른 후보가 없습니다."]:format(className))
        else
            add(L["보통 직업(%s)입니다. 후보 중에 선호 직업 캐릭터가 없습니다."]:format(className))
        end
        if r.richer then
            add(L["%s보다 남은 골드는 %s 적지만 직업 선호가 더 높습니다."]:format(ColorName(r.richer.key), FormatGold(r.richer.money - r.money)))
        end
    end
    if r.realmOver and r.realmOver.money == r.money then
        add(L["지금 캐릭터와 같은 서버라서, 남은 골드가 같은 %s 대신 골랐습니다."]:format(ColorName(r.realmOver.key)))
    elseif r.realmOver then
        add(L["지금 캐릭터와 같은 서버라서, 남은 골드가 %s 더 많은 %s 대신 골랐습니다 (1천 골드 안 차이)."]:format(
            FormatGold(r.realmOver.money - r.money), ColorName(r.realmOver.key)))
    elseif r.tiersUsed then
        add(L["같은 직업 선호 중에서 남은 골드가 가장 많습니다: 골드퀘 %d개, %s."]:format(r.count, FormatGold(r.money)))
    else
        add(L["후보 중에서 남은 골드가 가장 많습니다: 골드퀘 %d개, %s."]:format(r.count, FormatGold(r.money)))
    end
    GameTooltip:Show()
end

-- 추천 줄의 캐릭터 이름 위에 마우스 영역을 둔다. lineTop: 글자 위쪽에서 추천 줄까지 내려간 거리 (여러 줄 글자의 마지막 줄일 때)
function QTR.PlaceRecHover(parent, fs, lineTop)
    local h = QTR.recHovers[fs]
    if not h then
        h = CreateFrame("Frame", nil, parent)
        h:EnableMouse(true)
        h:SetScript("OnEnter", function(self) QTR.ShowRecTip(self) end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h.measure = parent:CreateFontString(nil, "OVERLAY")
        h.measure:Hide()
        QTR.recHovers[fs] = h
    end
    local r = QTR.recLast
    if not r then
        h:Hide()
        return
    end
    local font = fs.GetFontObject and fs:GetFontObject()
    if font then
        h.measure:SetFontObject(font)
    end
    h.measure:SetText(L["다음 추천: %s |cffaaaaaa(남은 골드퀘 %d개, %s)|r"]:match("^(.-)%%s") or "")
    local x = h.measure:GetStringWidth() or 0
    h.measure:SetText(r.key)
    local w = h.measure:GetStringWidth() or 0
    h.measure:SetText("")
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", fs, "TOPLEFT", x, -(lineTop or 0))
    h:SetSize(math.max(w, 20), 14)
    h:Show()
end

-- 추천 한 줄: "다음 추천: 겨울이간다-데스윙 (남은 골드퀘 8개, 8,400골드)"
function QTR.RecommendText()
    local r = QTR.RecommendNextChar()
    QTR.recLast = r -- 이름 툴팁 (QTR.ShowRecTip)
    if not r then
        return L["|cffaaaaaa다음 추천: 남은 골드퀘가 있는 다른 캐릭터가 없습니다.|r"]
    end
    return L["다음 추천: %s |cffaaaaaa(남은 골드퀘 %d개, %s)|r"]:format(ColorName(r.key), r.count, FormatGold(r.money))
end

function QTR:UpdateRich()
    ScanQuestBoard()
    QTR.ScanWeeklyFlags()
    local now = time()
    local targets, maxLevel = GetTargetChars()
    local weekStart, nextReset = GetWeekBounds()
    local entries = {}

    -- 골드퀘: 지역별로 묶고, 지역은 가장 빨리 끝나는 퀘스트 순
    local zones, zoneByName = {}, {}
    local gqCount = 0
    for questID, e in pairs(DB.activeGQ) do
        if (not e.expire or e.expire > now) and not QTR.IsHiddenQuest(questID) and QTR.SeenByTarget(e, targets) then
            local zname = e.zone or "?"
            -- 다른 언어로 저장된 지역 이름은 그 지역 지도 이름을 게임에서 읽는다 (2026-10-31 영어 클라이언트 지원)
            if QTR.WrongLang(zname) and e.mapID then
                local info = C_Map.GetMapInfo(e.mapID)
                zname = (info and info.name) or zname
            end
            local z = zoneByName[zname]
            if not z then
                z = { name = zname, quests = {}, money = 0, minExpire = math.huge }
                zoneByName[zname] = z
                table.insert(zones, z)
            end
            table.insert(z.quests, { id = questID, e = e })
            if not e.cacheItem then
                z.money = z.money + (e.money or 0)
            end
            z.minExpire = math.min(z.minExpire, e.expire or math.huge)
            gqCount = gqCount + 1
        end
    end
    table.sort(zones, function(a, b)
        if a.minExpire ~= b.minExpire then
            return a.minExpire < b.minExpire
        end
        return a.name < b.name
    end)
    for _, z in ipairs(zones) do
        table.sort(z.quests, function(a, b)
            local ea, eb = a.e.expire or math.huge, b.e.expire or math.huge
            if ea ~= eb then
                return ea < eb
            end
            return (a.e.name or "") < (b.e.name or "")
        end)
        -- 골드퀘 개수는 따로 쓰지 않는다 (골드퀘 탭과 같은 모양)
        -- 지역 줄 오른쪽(골드 합계)은 읽기 쉽도록 비워 둔다
        table.insert(entries, {
            Cell("|cff00ccff" .. z.name .. "|r", COL.name),
        })
        for _, q in ipairs(z.quests) do
            local key = "gq" .. q.id
            local since = GetGQInstanceStart(q.id, q.e)
            local function doneTime(k)
                return GetQuestDoneTime(k, q.id, since)
            end
            -- 지도에 안 보이는 캐릭터, 보상이 골드가 아닌 캐릭터는 분모에서 뺀다 (완료했다면 그대로 센다)
            local hidden, notGold = q.e.hiddenFor, q.e.notGoldFor
            local done, total = 0, 0
            for _, k in ipairs(targets) do
                local t = doneTime(k)
                if t then
                    done = done + 1
                end
                if t or not ((hidden and hidden[k]) or (notGold and notGold[k])) then
                    total = total + 1
                end
            end
            table.insert(entries, {
                Cell(ExpandMark(key), RICH_COL.mark),
                Cell("|cffffffff" .. (QTR.ShownTitle(q.id, q.e.name) or q.id) .. "|r" .. QTR.BanMark(q.id), COL.gqQuest),
                Cell(FormatTimeLeft(q.e.expire and (q.e.expire - now)), COL.gqTime, "RIGHT"),
                Cell(q.e.cacheItem and ("|T" .. GetItemIconSafe(q.e.cacheItem) .. ":0|t") or FormatSubGold(q.e.money), COL.gold, "RIGHT"),
                Cell(FormatProgress(done, total), COL.pct, "RIGHT"),
                onClick = ToggleExpanded(key),
                tipQuest = q.id,
            })
            if rich.expanded[key] then
                local cacheItem = q.e.cacheItem
                AddCharRows(entries, targets, doneTime, cacheItem and function(k)
                    local n = GetUnopenedCount(k, cacheItem)
                    if n > 0 then
                        return L["|cffffd100미개봉 %d|r"]:format(n)
                    end
                end, hidden, notGold)
            end
        end
    end
    if gqCount == 0 then
        table.insert(entries, L["|cff808080알고 있는 골드퀘가 없습니다. 캐릭터로 접속하면 지도에서 읽어 모아 둡니다.|r"])
    end

    -- 정점 보관함(특별 과제 포함): 남은 시간은 줄마다 따로 보여준다. 학습한 출처가 없으면 묶음 자체를 그리지 않는다
    -- 특별 과제와 다른 정점 보관함은 한 묶음 "정점 보관함"에 (2026-10-29 사용자 결정: 묶음 머리가 둘이면 너무 길어서)
    --   특별 과제 줄("퀘스트명 (지역)") 먼저, 그 아래 다른 정점 보관함 줄(보관함 이름). 줄마다 묶는 기준은 그대로
    local sources = GetSortedSources(weekStart)
    -- 최정상 보관함은 아래 실버문 주간 퀘스트 두 줄이 대신한다 (2026-10-30)
    local others = {}
    for _, o in ipairs(QTR.OtherApexThisWeek(weekStart)) do
        if o.id ~= QTR.SILVERMOON_CACHE then
            table.insert(others, o)
        end
    end
    local smInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(2393)
    local smName = QTR.ShortZone(smInfo and smInfo.name or L["실버문"]) -- 지역 이름은 게임에서 읽는다 (영어는 "Silvermoon"으로 줄임)
    -- 실버문 주간 퀘스트는 이번 주에 완료한 만렙 캐릭터가 있는 줄만 그린다 (2026-10-30 사용자 결정:
    -- 실버문 주간에 관심 없는 사람에게 숙제처럼 보이면 안 된다)
    --   수행중(받아 둔) 캐릭터가 있어도 그린다 (2026-11-01)
    local weeklyRows = {}
    --   지난주에 해서 이번 주에 받을 수 없는 캐릭터(리에드린, QTR.WeeklyLastWeek)는 개수에서 뺀다 (2026-11-07)
    for _, w in ipairs(QTR.SILVERMOON_WEEKLY) do
        local done, doing, skip = 0, 0, 0
        for _, k in ipairs(targets) do
            if QTR.WeeklyDoneTime(k, w, weekStart) then
                done = done + 1
            elseif QTR.WeeklyOnQuest(k, w, weekStart) then
                doing = doing + 1
            elseif QTR.WeeklyLastWeek(k, w, weekStart) then
                skip = skip + 1
            end
        end
        if done + doing > 0 then
            table.insert(weeklyRows, { w = w, done = done, skip = skip })
        end
    end
    if #sources + #weeklyRows + #others > 0 then
        table.insert(entries, "")
        table.insert(entries, { Cell(L["|cffa335ee정점 보관함|r"], COL.name) })
    end
    for _, item in ipairs(sources) do
        local src = item.src
        local key = "src" .. item.key
        local function doneTime(k)
            return GetSourceDoneTime(k, src, weekStart)
        end
        local done = 0
        for _, k in ipairs(targets) do
            if doneTime(k) then
                done = done + 1
            end
        end
        local nameColor = item.thisWeek and "|cffffffff" or "|cff707070"
        local midText = item.thisWeek and QTR.SourceTimeText(src, nextReset) or L["|cff606060이번 주 미확인|r"]
        table.insert(entries, {
            Cell(ExpandMark(key), RICH_COL.mark),
            Cell(nameColor .. QTR.SourceLabel(src) .. "|r"
                .. (src.kind == "quest" and QTR.BanMark(src.questID) or ""), COL.richCacheName),
            Cell(midText, COL.richCacheTime, "RIGHT"),
            Cell("|T" .. GetItemIconSafe(src.itemID) .. ":0|t", COL.gold, "RIGHT"),
            Cell(FormatProgress(done, #targets), COL.pct, "RIGHT"),
            onClick = ToggleExpanded(key),
            tipQuest = src.kind == "quest" and src.questID or nil,
            tipItem = src.kind == "item" and src.itemID or nil,
        })
        if rich.expanded[key] then
            local since = GetSourceSince(src, weekStart)
            AddCharRows(entries, targets, doneTime, function(k)
                -- 미개봉 개수, 없으면 열어서 대박이었을 때 별과 골드 (2026-11-11 사용자 요청: 동기부여)
                return QTR.CacheCellText(k, src.itemID, doneTime(k) and QTR.SourceOpenGold(k, src, weekStart))
            end, nil, nil, QTR.IsMapSource(src) and function(k)
                return QTR.SpecialState(k, src, since)
            end or nil)
        end
    end

    -- 실버문 주간 퀘스트 두 줄 (2026-10-30 사용자 요청): "잘아타스 추적 (실버문)", "리에드린 주간 퀘스트 (실버문)"
    --   줄: 이름 | 주간 초기화까지 | 최정상 보관함 아이콘 | 이번 주 완료한 캐릭터 수 / 만렙 캐릭터 수
    --   이번 주에 완료한 캐릭터가 있는 줄만 (weeklyRows, 위에서 센다)
    --   펼치면 캐릭터별 완료 시각과 최정상 보관함 "미개봉 n" (가방 개수라 두 줄에 똑같이 나온다)
    --   두 퀘스트가 같은 최정상 보관함을 주므로 아래 다른 정점 보관함 줄에서는 최정상 보관함을 뺀다
    for _, row in ipairs(weeklyRows) do
        local w, done = row.w, row.done
        local key = "weekly" .. w.key
        local function doneTime(k)
            return (QTR.WeeklyDoneTime(k, w, weekStart))
        end
        table.insert(entries, {
            Cell(ExpandMark(key), RICH_COL.mark),
            Cell("|cffffffff" .. QTR.WeeklyName(w) .. " (" .. smName .. ")|r", COL.richCacheName),
            Cell(FormatTimeLeft(nextReset - now), COL.richCacheTime, "RIGHT"),
            Cell("|T" .. GetItemIconSafe(QTR.SILVERMOON_CACHE) .. ":0|t", COL.gold, "RIGHT"),
            Cell(FormatProgress(done, #targets - row.skip), COL.pct, "RIGHT"),
            onClick = ToggleExpanded(key),
            tipQuest = (#w.ids == 1) and w.ids[1] or nil,
        })
        if rich.expanded[key] then
            AddCharRows(entries, targets, doneTime, function(k)
                -- 대박 표시: 이번 주에 이 주간 퀘스트(w.ids)로 받은 최정상 보관함을 연 골드
                local gold = doneTime(k) and QTR.OpenGoldSince(k, weekStart, function(g)
                    if g.id ~= QTR.SILVERMOON_CACHE then
                        return false
                    end
                    for _, id in ipairs(w.ids) do
                        if g.q == id then
                            return true
                        end
                    end
                    return false
                end)
                return QTR.CacheCellText(k, QTR.SILVERMOON_CACHE, gold)
            end, nil, nil, function(k)
                return QTR.WeeklyState(k, w, weekStart)
            end)
        end
    end

    -- 다른 정점 보관함 (2026-10-29 사용자 결정: 실버문 주간퀘가 간편한 주간일 때는 넓게 보아 골드퀘처럼 캐릭터별로 챙긴다)
    --   특별 과제 보상 2종이 아닌 정점 보관함을 이번 주에 받은 캐릭터가 있을 때만 그 보관함 줄을 그린다
    --   줄: 보관함 이름 | 주간 초기화까지 | 아이콘 | 받은 캐릭터 수 / 만렙 캐릭터 수. 펼치면 캐릭터별 받은 시각과 미개봉 개수
    for _, o in ipairs(others) do
        local key = "apex" .. o.id
        local function doneTime(k)
            return o.got[k]
        end
        local done = 0
        for _, k in ipairs(targets) do
            if o.got[k] then
                done = done + 1
            end
        end
        table.insert(entries, {
            Cell(ExpandMark(key), RICH_COL.mark),
            Cell("|cffffffff" .. GetItemNameSafe(o.id) .. "|r", COL.richCacheName),
            Cell(FormatTimeLeft(nextReset - now), COL.richCacheTime, "RIGHT"),
            Cell("|T" .. GetItemIconSafe(o.id) .. ":0|t", COL.gold, "RIGHT"),
            Cell(FormatProgress(done, #targets), COL.pct, "RIGHT"),
            onClick = ToggleExpanded(key),
            tipItem = o.id,
        })
        if rich.expanded[key] then
            AddCharRows(entries, targets, doneTime, function(k)
                -- 대박 표시: 이번 주에 받은 이 보관함을 연 골드
                local gold = doneTime(k) and QTR.OpenGoldSince(k, weekStart, function(g) return g.id == o.id end)
                return QTR.CacheCellText(k, o.id, gold)
            end)
        end
    end
    RenderList(rich.list, entries)

    local summary = string.format(L["골드퀘 %d개"], gqCount)
    if #sources > 0 then
        summary = summary .. string.format(L[" / 특별 과제 %d개"], #sources)
    end
    if #others > 0 then
        summary = summary .. string.format(L[" / 다른 정점 보관함 %d개"], #others)
    end
    rich.summary:SetText(summary)
    if maxLevel then
        rich.sub:SetText(L["|cffaaaaaa만렙(%d) 캐릭터 %d개 기준, 줄을 누르면 캐릭터별 현황|r"]:format(maxLevel, #targets))
    else
        rich.sub:SetText(L["|cffaaaaaa캐릭터 %d개 기준, 줄을 누르면 캐릭터별 현황|r"]:format(#targets))
    end
    rich.rec:SetText(QTR.RecommendText())
    QTR.PlaceRecHover(dashPanel, rich.rec)
end

-- 탭이 열려 있는 동안 남은 시간을 주기적으로 갱신
dashPanel:SetScript("OnShow", function(self)
    self.elapsed = 0
end)
dashPanel:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= GQ_REFRESH_SECONDS then
        self.elapsed = 0
        QTR:Refresh()
    end
end)

QTR.GetSortedSources = GetSortedSources
QTR.GetSourceName = GetSourceName
QTR.IsSourceDoneBy = IsSourceDoneBy
QTR.GetUnopenedCount = GetUnopenedCount
end
QTR.SetupRichTab()

-- 이 블록 밖(이벤트 처리)에서 쓰는 함수
QTR.ScanQuestBoard = ScanQuestBoard
QTR.PreloadGoldQuests = PreloadGoldQuests
end
QTR.SetupGQTab()

-------------------------------------------------------------------------------
-- 화면 갱신과 탭 전환
-------------------------------------------------------------------------------

function QTR:Refresh()
    if not f:IsShown() or not DB then
        return
    end
    QTR:UpdateHeader()
    if currentTab == "stats" then
        QTR:UpdateStats()
    elseif currentTab == "gq" then
        QTR:UpdateGoldQuests()
    elseif currentTab == "hold" then
        QTR:UpdateHoldings()
    else
        QTR:UpdateRich()
    end
end

-- 짧은 시간에 여러 번 생기는 갱신 요청(퀘스트 완료, 가방 변화)은 한 번으로 묶는다
local refreshQueued = false
function QTR:ScheduleRefresh()
    if refreshQueued then
        return
    end
    refreshQueued = true
    C_Timer.After(0.5, function()
        refreshQueued = false
        QTR:Refresh()
    end)
end

-- 탭 이름과 그 탭의 영역, 버튼
local TABS = {
    gq = { panel = gqPanel, button = tabGQ },
    dash = { panel = dashPanel, button = tabDash },
    stats = { panel = statsPanel, button = tabStats },
    hold = { panel = holdPanel, button = tabHold },
}

local function ShowTab(tab)
    if not TABS[tab] then
        tab = "dash"
    end
    QTR.forceScan = true
    currentTab = tab
    if DB then
        DB.settings.tab = tab -- 다음에 창을 열 때 마지막으로 본 탭을 연다
    end
    for name, t in pairs(TABS) do
        if name == tab then
            t.panel:Show()
            t.button:LockHighlight()
        else
            t.panel:Hide()
            t.button:UnlockHighlight()
        end
    end
    QTR:Refresh()
end

tabGQ:SetScript("OnClick", function()
    ShowTab("gq")
end)

tabDash:SetScript("OnClick", function()
    ShowTab("dash")
end)

tabStats:SetScript("OnClick", function()
    ShowTab("stats")
end)

tabHold:SetScript("OnClick", function()
    ShowTab("hold")
end)

-- 숫자키 1~4로 탭 전환: 마우스가 창 위에 있을 때만 키보드를 받는다.
-- 1~4와 지금 탭의 버튼 단축키(수정키 없이)만 가로채고 나머지 키는 그대로 게임으로 넘긴다. 전투 중에는 받지 않는다.
--   골드퀘: R 내비게이션 시작! / 획득량: Q W E R 일별 주별 월별 전체, 쉼표 마침표 이전 다음, T 현재
--   보유량: Q W 요약 상세, 쉼표 마침표 이전 다음 날짜, T 오늘 (쉼표 마침표는 마우스 휠로도)
local TAB_KEYS = { ["1"] = "gq", ["2"] = "dash", ["3"] = "stats", ["4"] = "hold" }
local keyboardOn = false

local function SetTabKeys(on)
    if keyboardOn == on or InCombatLockdown() then
        return
    end
    keyboardOn = on
    f:EnableKeyboard(on)
    if on then
        f:SetPropagateKeyboardInput(true)
    end
end
QTR.SetTabKeys = SetTabKeys

f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then
        return
    end
    local tab = TAB_KEYS[key]
    -- 지금 탭 영역의 버튼 단축키 (CreateButton의 key). 보이고 눌 수 있는 버튼만 누른다.
    local keys = QTR.panelKeys[TABS[currentTab].panel]
    local btn = keys and keys[key]
    if IsModifierKeyDown() then
        self:SetPropagateKeyboardInput(true)
    elseif tab then
        self:SetPropagateKeyboardInput(false)
        ShowTab(tab)
    elseif btn and btn:IsShown() and btn:IsEnabled() ~= false then
        self:SetPropagateKeyboardInput(false)
        btn:Click()
    else
        self:SetPropagateKeyboardInput(true)
    end
end)
f:SetScript("OnKeyUp", function(self)
    if not InCombatLockdown() then
        self:SetPropagateKeyboardInput(true)
    end
end)

local keyWatcher = CreateFrame("Frame", nil, f)
keyWatcher:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.1 then
        return
    end
    self.elapsed = 0
    SetTabKeys(f:IsShown() and f:IsMouseOver() and true or false)
end)
f:HookScript("OnHide", function()
    SetTabKeys(false)
end)

-- 창 위치 적용: 위쪽이 고정되도록 왼쪽 위 기준으로 놓는다 (저장된 위치가 없으면 화면 위쪽 가운데)
-- 예전 버전이 저장한 위치(창 가운데 등 다른 기준)는 예전 세로 길이로 한 번 놓아 본 뒤 왼쪽 위 기준으로 바꿔 저장한다
local function ConvertOldFramePosition()
    local p = DB and DB.settings.pos
    if p and p[1] ~= "TOPLEFT" then
        QTR.SaveFramePosition()
        if DB.settings.pos[1] == "TOPLEFT" then
            DB.settings.frameHeight = nil
        end
    end
end

local function ApplyFramePosition()
    f:ClearAllPoints()
    local p = DB and DB.settings.pos
    if p and p[1] == "TOPLEFT" then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[3], p[4])
    elseif p then
        f:SetHeight(DB.settings.frameHeight or 640)
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        ConvertOldFramePosition()
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
end
-- 불러올 때 창 좌표를 아직 못 읽었다면 처음 열 때 바꾼다 (이때는 아직 예전 세로 길이 그대로다)
f:HookScript("OnShow", ConvertOldFramePosition)

-- 창 크기 (기본 1): 대시보드(dashScale)와 내비게이션 창(navScale)을 따로 정한다 (2026-10-27 사용자 요청)
-- 1.4.0의 두 창 공통 설정(uiScale)이 있으면 두 창에 옮겨 쓰고 지운다
-- 저장한 위치는 창 배율 기준 좌표라서, 배율이 old에서 바뀌면 왼쪽 위 모서리가 화면에서 그대로 있도록 좌표도 고친다
-- which: "dash" 또는 "nav" (바꾼 창), old: 그 창의 예전 배율. 둘 다 없으면 (접속 때) 두 창에 저장된 배율만 적용한다
function QTR.ApplyUIScale(which, old)
    local s = DB.settings
    if s.uiScale then
        s.dashScale = s.dashScale or s.uiScale
        s.navScale = s.navScale or s.uiScale
        s.uiScale = nil
    end
    local new = (which == "nav") and (s.navScale or 1) or (s.dashScale or 1)
    if old and old ~= new then
        local p = s.pos
        if which == "dash" and p and p[1] == "TOPLEFT" then
            p[3], p[4] = p[3] * old / new, p[4] * old / new
        end
        local r = s.routePopPos
        if which == "nav" and r then
            r[1], r[2] = r[1] * old / new, r[2] * old / new
        end
    end
    if which ~= "nav" then
        f:SetScale(s.dashScale or 1)
        ApplyFramePosition()
        if f:IsShown() then
            QTR:Refresh() -- 최대 높이가 바뀌었을 수 있어 세로 길이를 다시 맞춘다
        end
    end
    if which ~= "dash" and QTR.ApplyRouteScale then
        QTR.ApplyRouteScale()
    end
end

-------------------------------------------------------------------------------
-- 창 열기/닫기 (단축키와 슬래시 명령어에서 호출)
-------------------------------------------------------------------------------

function QuestsToRiches_ToggleDashboard()
    if not DB then
        return
    end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        ShowTab(currentTab)
    end
end

function QuestsToRiches_ToggleConfig()
    if AceConfigDialog.OpenFrames[ADDON_NAME] then
        AceConfigDialog:Close(ADDON_NAME)
    else
        AceConfigDialog:Open(ADDON_NAME)
    end
end

configBtn:SetScript("OnClick", function()
    QuestsToRiches_ToggleConfig()
end)

-------------------------------------------------------------------------------
-- 미니맵 버튼
--   왼쪽 클릭: 창 열기/닫기, 오른쪽 클릭: 설정창, 끌기: 미니맵 둘레를 따라 위치 옮기기
--   위치(각도)는 DB.settings.minimapAngle, 숨기기는 DB.settings.minimapHide (설정창에서 바꾼다)
--   미니맵이 네모난 UI(GetMinimapShape가 SQUARE)면 네모 둘레를 따라 놓는다
-------------------------------------------------------------------------------
QTR.MINIMAP_ICON = "Interface\\AddOns\\QuestsToRiches\\Media\\MinimapIcon"

QTR.SetupMinimap = function()
    if QTR.minimapBtn or not Minimap then
        return
    end
    local btn = CreateFrame("Button", "QuestsToRichesMinimapButton", Minimap)
    QTR.minimapBtn = btn
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- 다른 애드온 미니맵 버튼과 같은 표준 구조: 기본 배경 + 아이콘 + 기본 금색 테두리
    -- (미니맵 버튼 모음 애드온이 다른 버튼과 같은 모양으로 정리할 수 있도록)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(QTR.MINIMAP_ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function UpdatePosition()
        local angle = math.rad(DB.settings.minimapAngle or 225)
        local x, y = math.cos(angle), math.sin(angle)
        local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
        if shape == "SQUARE" then
            -- 네모 둘레에 닿을 때까지 늘린다
            local m = math.max(math.abs(x), math.abs(y))
            if m > 0 then
                x, y = x / m, y / m
            end
        end
        local rx = (Minimap:GetWidth() or 140) / 2 + 5
        local ry = (Minimap:GetHeight() or 140) / 2 + 5
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
    end
    QTR.UpdateMinimapPosition = UpdatePosition

    -- 끄는 동안 커서 방향으로 각도를 바꾼다
    local function OnDragUpdate()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        if not (mx and my and px and py and scale and scale > 0) then
            return
        end
        local atan2 = math.atan2 or math.atan
        DB.settings.minimapAngle = math.deg(atan2(py / scale - my, px / scale - mx)) % 360
        UpdatePosition()
    end
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            QuestsToRiches_ToggleConfig()
        else
            QuestsToRiches_ToggleDashboard()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QuestsToRiches")
        GameTooltip:AddLine(L["왼쪽 클릭: 창 열기/닫기"], 1, 1, 1)
        GameTooltip:AddLine(L["오른쪽 클릭: 설정창"], 1, 1, 1)
        GameTooltip:AddLine(L["끌기: 버튼 위치 옮기기"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
    QTR.UpdateMinimapButton()
end

-- 설정에 따라 미니맵 버튼을 보이거나 숨긴다
function QTR.UpdateMinimapButton()
    local btn = QTR.minimapBtn
    if not btn then
        return
    end
    if DB.settings.minimapHide then
        btn:Hide()
    else
        btn:Show()
        QTR.UpdateMinimapPosition()
    end
end

-- 애드온 보관함(미니맵 옆 애드온 목록)에서 눌렀을 때: 미니맵 버튼과 같다
function QuestsToRiches_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        QuestsToRiches_ToggleConfig()
    else
        QuestsToRiches_ToggleDashboard()
    end
end

-------------------------------------------------------------------------------
-- 단축키 (계정 공통)
-- 저장 데이터의 키를 접속할 때마다 덮어쓰기 바인딩으로 적용한다.
-- 캐릭터별 키 설정을 쓰더라도 모든 캐릭터에 같은 키가 적용된다.
-------------------------------------------------------------------------------

local bindOwner = CreateFrame("Frame")

local function ApplyKeyBindings()
    if not DB then
        return
    end
    if InCombatLockdown() then
        pendingBindings = true
        return
    end
    pendingBindings = false
    ClearOverrideBindings(bindOwner)
    local keys = DB.settings.keys
    if keys.dashboard and keys.dashboard ~= "" then
        SetOverrideBinding(bindOwner, false, keys.dashboard, BIND_DASHBOARD)
    end
    if keys.config and keys.config ~= "" then
        SetOverrideBinding(bindOwner, false, keys.config, BIND_CONFIG)
    end
    if keys.route and keys.route ~= "" then
        SetOverrideBinding(bindOwner, false, keys.route, BIND_ROUTE)
    end
    if keys.navStart and keys.navStart ~= "" then
        SetOverrideBinding(bindOwner, false, keys.navStart, "QUESTSTORICHES_NAVSTART") -- 메인 청크 local 한도로 상수 없이
    end
end

-- 예전 버전에서 게임 키 설정에 저장했던 키를 처음 한 번 가져온다
local function MigrateKeyBindings()
    local keys = DB.settings.keys
    if keys.dashboard == nil then
        local key = GetBindingKey(BIND_DASHBOARD)
        if key then
            keys.dashboard = key
        end
    end
    if keys.config == nil then
        local key = GetBindingKey(BIND_CONFIG)
        if key then
            keys.config = key
        end
    end
end

local function GetSavedKey(field)
    local key = DB.settings.keys[field]
    if key == "" then
        return nil
    end
    return key
end

local function SetSavedKey(field, key)
    if InCombatLockdown() then
        Print(L["전투 중에는 단축키를 바꿀 수 없습니다."])
        return
    end
    DB.settings.keys[field] = key or ""
    ApplyKeyBindings()
end

-------------------------------------------------------------------------------
-- 설정창
-------------------------------------------------------------------------------

-- 직업 선호 바꾸기 (세 칸 화면에서): 단계 1 선호, 2 보통, 3 비선호. 보통은 저장하지 않는다
function QTR.SetClassTier(token, tier)
    tier = math.max(1, math.min(3, tier))
    if tier == QTR.ClassTierOf(token) then
        return -- 같은 칸에 놓으면 그대로 (차례도 바꾸지 않는다)
    end
    local s = DB.settings
    s.classPref = s.classPref or {}
    s.classPref[token] = (tier ~= 2) and tier or nil
    if not next(s.classPref) then
        s.classPref = nil
    end
    -- 옮긴 차례: 마지막에 옮긴 직업이 그 칸의 맨 끝 (2026-11-11 사용자 요청)
    s.classSeq = (s.classSeq or 0) + 1
    s.classOrder = s.classOrder or {}
    s.classOrder[token] = s.classSeq
    QTR.ClassTiersChanged()
end
function QTR.ResetClassTiers()
    DB.settings.classPref, DB.settings.classOrder, DB.settings.classSeq = nil, nil, nil
    QTR.ClassTiersChanged()
end
function QTR.ClassTierOf(token)
    return (DB.settings.classPref and DB.settings.classPref[token]) or 2
end
-- 칸 안의 차례 (2026-11-11 사용자 요청): 옮긴 적 없는 직업이 먼저 (판금, 사슬, 가죽, 천 순, 같은 방어구 안에서는 이름순),
-- 옮긴 직업은 그 뒤에 옮긴 차례대로
QTR.CLASS_ARMOR = { WARRIOR = 1, PALADIN = 1, DEATHKNIGHT = 1, HUNTER = 2, SHAMAN = 2, EVOKER = 2,
    ROGUE = 3, DRUID = 3, MONK = 3, DEMONHUNTER = 3, PRIEST = 4, MAGE = 4, WARLOCK = 4 }
function QTR.ClassName(token)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end
function QTR.ClassTierList(tier)
    local list = {}
    for _, token in ipairs(QTR.CLASS_TOKENS) do
        if QTR.ClassTierOf(token) == tier then
            table.insert(list, token)
        end
    end
    local order = DB.settings.classOrder or {}
    table.sort(list, function(a, b)
        local oa, ob = order[a] or 0, order[b] or 0
        if oa ~= ob then
            return oa < ob
        end
        local ra, rb = QTR.CLASS_ARMOR[a] or 9, QTR.CLASS_ARMOR[b] or 9
        if ra ~= rb then
            return ra < rb
        end
        return QTR.ClassName(a) < QTR.ClassName(b)
    end)
    return list
end
-- 바뀐 뒤: 열려 있는 세 칸을 다시 그리고 추천 줄을 새로 계산
function QTR.ClassTiersChanged()
    if QTR.classTierWidget and QTR.classTierWidget.Layout then
        QTR.classTierWidget:Layout()
    end
    QTR:Refresh()
end

-- 세 칸 화면 (AceGUI 칸 "QTR_ClassTiers", 설정창의 description 자리에 dialogControl로 넣는다)
--   칸마다 제목과 직업 단추(직업 색 이름)를 두 줄로 늘어놓는다. 13개가 한 칸에 다 들어가도 7줄
--   단추를 끌면 이름이 커서를 따라오고, 커서 아래 칸의 테두리가 노랗게 바뀌며, 놓은 자리의 칸으로 옮긴다
--   (2026-11-11 사용자 요청: 클릭으로 옮기기는 빼고 끌기만). "모두 보통으로" 단추는 보통 칸 아래 가운데
function QTR.RegisterClassTierWidget()
    local AceGUI = LibStub("AceGUI-3.0", true)
    if QTR.classTierRegistered or not (AceGUI and AceGUI.RegisterWidgetType and AceGUI.RegisterAsWidget) then
        return
    end
    QTR.classTierRegistered = true
    local Type, ROW, HEAD = "QTR_ClassTiers", 18, 22
    local TIER_NAME = { L["선호"], L["보통"], L["비선호"] }
    local TIER_COLOR = { { 0.2, 0.6, 0.2 }, { 0.5, 0.5, 0.5 }, { 0.7, 0.2, 0.2 } }
    local BOX_H = HEAD + 7 * ROW + 10
    local HEIGHT = BOX_H + 6 + 22 + 4 -- 칸 + 간격 + "모두 보통으로" 단추

    local function ClassLabel(token)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] and RAID_CLASS_COLORS[token].colorStr
        local name = QTR.ClassName(token)
        return color and ("|c" .. color .. name .. "|r") or name
    end
    -- 칸 테두리: 끄는 동안 커서 아래 칸은 노랑, 아니면 칸 색
    local function SetBorder(box, t, lit)
        if box.SetBackdropBorderColor then
            local c = TIER_COLOR[t]
            if lit then
                box:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                box:SetBackdropBorderColor(c[1], c[2], c[3], 1)
            end
        end
        box.lit = lit or nil
    end

    local methods = {}
    function methods.OnAcquire(self)
        self:SetHeight(HEIGHT)
        QTR.classTierWidget = self
        self:Layout()
    end
    function methods.OnRelease(self)
        if QTR.classTierWidget == self then
            QTR.classTierWidget = nil
        end
        self.ghost:Hide()
    end
    function methods.OnWidthSet(self, width)
        self.boxWidth = width
        self:Layout()
    end
    -- description 자리라 AceConfigDialog가 부르는 것들 (쓰지 않는다)
    function methods.SetText() end
    function methods.SetFontObject() end
    function methods.SetImage() end
    function methods.SetImageSize() end
    -- 칸 크기와 단추 자리를 지금 설정대로
    function methods.Layout(self)
        local w = self.boxWidth or self.frame:GetWidth() or 0
        if w < 300 then
            w = 540
        end
        local boxW = math.floor((w - 16) / 3)
        local half = math.floor((boxW - 12) / 2)
        for t = 1, 3 do
            local box = self.boxes[t]
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (t - 1) * (boxW + 8), 0)
            box:SetSize(boxW, BOX_H)
            SetBorder(box, t, false)
            local list = QTR.ClassTierList(t)
            for n, token in ipairs(list) do
                local b = self.chips[token]
                local col, row = (n - 1) % 2, math.floor((n - 1) / 2)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", box, "TOPLEFT", 6 + col * half, -(HEAD + row * ROW))
                b:SetSize(half, ROW)
                b.text:SetText(ClassLabel(token))
            end
            box.title:SetText(TIER_NAME[t] .. " (" .. #list .. ")")
        end
        self.reset:ClearAllPoints()
        self.reset:SetPoint("TOP", self.boxes[2], "BOTTOM", 0, -6)
    end

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()
        local self = { frame = frame, type = Type, boxes = {}, chips = {} }
        for k, fn in pairs(methods) do
            self[k] = fn
        end
        for t = 1, 3 do
            local box = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
            if box.SetBackdrop then
                box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
                local c = TIER_COLOR[t]
                box:SetBackdropColor(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 0.6)
            end
            SetBorder(box, t, false)
            box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            box.title:SetPoint("TOP", box, "TOP", 0, -5)
            self.boxes[t] = box
        end
        local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        reset:SetSize(140, 22)
        reset:SetText(L["모두 보통으로"])
        reset:SetScript("OnClick", function() QTR.ResetClassTiers() end)
        self.reset = reset
        -- 끄는 동안 커서를 따라오는 이름. 커서 아래 칸의 테두리를 노랗게
        local ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP")
        ghost:SetSize(120, ROW)
        ghost.text = ghost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        ghost.text:SetPoint("CENTER")
        ghost:Hide()
        ghost:SetScript("OnUpdate", function(g)
            local x, y = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            g:ClearAllPoints()
            g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
            for t = 1, 3 do
                local over = self.boxes[t]:IsMouseOver() and true or false
                if over ~= (self.boxes[t].lit or false) then
                    SetBorder(self.boxes[t], t, over)
                end
            end
        end)
        self.ghost = ghost
        for _, token in ipairs(QTR.CLASS_TOKENS) do
            local b = CreateFrame("Button", nil, frame)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b:RegisterForDrag("LeftButton")
            b:SetScript("OnDragStart", function()
                GameTooltip:Hide()
                ghost.text:SetText(ClassLabel(token))
                ghost:Show()
            end)
            b:SetScript("OnDragStop", function()
                ghost:Hide()
                local target
                for t = 1, 3 do
                    if self.boxes[t]:IsMouseOver() then
                        target = t
                    end
                    SetBorder(self.boxes[t], t, false)
                end
                if target then
                    QTR.SetClassTier(token, target)
                end
            end)
            b:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:AddLine(ClassLabel(token))
                GameTooltip:AddLine(L["끌어서 다른 칸에 놓으면 옮깁니다."], 1, 1, 1, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            self.chips[token] = b
        end
        return AceGUI:RegisterAsWidget(self)
    end
    AceGUI:RegisterWidgetType(Type, Constructor, 1)
end

local function BuildOptions()
    -- 줄바꿈: 폭이 좁은 버튼 뒤에 넣어 다음 항목을 새 줄에서 시작하게 한다
    local function Break(order)
        return { type = "description", name = "", order = order, width = "full" }
    end
    -- 단축키 항목명: 키 버튼(높이 24) 옆에 세로 가운데로 오도록, 왼쪽에 높이 24의 보이지 않는 그림을 둔다
    -- (AceGUI 글자 칸은 왼쪽 그림이 글자보다 높으면 글자를 그림의 세로 가운데에 맞춘다. 글자 칸 폭이 200 이상일 때)
    -- 그림은 압정 그림(Pin.tga)의 투명한 모서리 한 점을 쓴다
    local function BindLabel(order, text)
        return { type = "description", name = "|cffffd100" .. text .. "|r", order = order, width = 1.5, fontSize = "medium",
            image = "Interface\\AddOns\\QuestsToRiches\\Media\\Pin", imageCoords = { 0, 0.03, 0, 0.03 },
            imageWidth = 1, imageHeight = 24 }
    end
    -- 다음 추천 캐릭터의 직업 선호 (2026-11-08 사용자 요청): 직업마다 선호, 보통(기본), 비선호. 골드보다 먼저 본다
    --   2026-11-11 사용자 요청: 드롭다운 13개 대신 선호, 보통, 비선호 세 칸 (끌어서 옮기기, QTR_ClassTiers 칸. "모두 보통으로" 단추도 그 안에)
    QTR.RegisterClassTierWidget()
    local classArgs = {
        desc = { type = "description", order = 0, width = "full",
            name = L["다음 추천 캐릭터를 고를 때 골드보다 먼저 봅니다 (가장 빨리 끝나는 골드퀘를 아직 안 한 캐릭터로 후보를 좁힌 다음).\n"]
                .. L["추천된 캐릭터 이름에 마우스를 올리면 추천 이유가 나옵니다.\n"]
                .. L["직업을 끌어서 다른 칸에 놓으면 옮깁니다. 칸 안에서는 마지막에 옮긴 직업이 맨 끝에 놓입니다."] },
        tiers = { type = "description", order = 1, width = "full", name = "", dialogControl = "QTR_ClassTiers" },
    }
    return {
        type = "group",
        name = "QuestsToRiches",
        args = {
            helpGroup = {
                type = "group", name = L["명령어"], order = 100, inline = true,
                args = {
                    desc = {
                        type = "description",
                        name = L["|cffffff00/qtr : 창 열기/닫기\n/qtr gq : 골드퀘 탭 열기\n/qtr rich : 부자되기 탭 열기\n/qtr stats : 획득량 탭 열기\n/qtr hold : 보유량 탭 열기\n/qtr set : 설정창 열기/닫기\n/qtr list : 캐릭터별 저장된 보유 골드 출력\n/qtr ban, /qtr unban : 추적 제외 퀘스트 추가, 해제 (퀘스트 Shift+클릭)\n/qtr route : 남은 골드퀘 내비게이션 (/qtr route clear : 경로안내 중지)\n/qtr hearth : 귀환석 상태 (귀환 지점, 쿨타임, 쓸 수 있는 충전 수)\n/qtr pos [메모] : 지금 위치의 지도 ID와 좌표 저장 (list : 목록, clear : 지우기)\n골드퀘 탭의 퀘스트 줄 클릭: 웨이포인트\n창 위에 마우스를 올리고 숫자키 1~4: 탭 전환\n창 위에 마우스를 올리고 탭 버튼 단축키: 골드퀘 R 내비게이션 시작 / 획득량 Q W E R 보기, T 현재 / 보유량 Q W 보기, T 오늘\n획득량, 보유량 탭의 이전/다음: 쉼표, 마침표 또는 마우스 휠|r\n|cffaaaaaa모든 설정은 계정 공통이라 모든 서버, 모든 캐릭터에 같이 적용됩니다.|r"],
                        order = 1, fontSize = "medium", width = "full",
                    },
                },
            },
            goalGroup = {
                type = "group", name = L["목표"], order = 1.5, inline = true,
                args = {
                    goalDesc = {
                        type = "description",
                        name = L["|cffaaaaaa골드 단위로 입력합니다. 쉼표는 넣어도 되고 빼도 됩니다. (예: 6500000 또는 6,500,000)\n"]
                            .. L["1골드부터 %s골드까지 입력할 수 있습니다.|r"]:format(BreakUpLargeNumbers(GOAL_MAX)),
                        order = 1, fontSize = "medium", width = "full",
                    },
                    goal = {
                        type = "input", name = L["목표 골드"], order = 2, width = 1.2,
                        get = function() return BreakUpLargeNumbers(DB.settings.goal) end,
                        validate = function(_, val)
                            local digits = (val or ""):gsub("[,%s]", "")
                            if not digits:match("^%d+$") then
                                return L["숫자만 입력하세요. (쉼표는 넣어도 됩니다)"]
                            end
                            -- 자릿수가 너무 많으면 숫자로 바꾸기 전에 막는다
                            if #digits > #tostring(GOAL_MAX) then
                                return L["%s골드 이하로 입력하세요."]:format(BreakUpLargeNumbers(GOAL_MAX))
                            end
                            local n = tonumber(digits)
                            if not n or n < 1 then
                                return L["1골드 이상 입력하세요."]
                            end
                            if n > GOAL_MAX then
                                return L["%s골드 이하로 입력하세요."]:format(BreakUpLargeNumbers(GOAL_MAX))
                            end
                            return true
                        end,
                        set = function(_, val)
                            DB.settings.goal = tonumber((val:gsub("[,%s]", "")))
                            QTR:Refresh()
                        end,
                    },
                    goalPreview = {
                        type = "description", order = 3, fontSize = "medium", width = 1.8,
                        name = function()
                            local g = GetGoalGold()
                            -- "만 골드" 풀이는 한국어 화면에서만 (영어는 숫자 그대로 읽는다)
                            if g >= 10000 and GetLocale() == "koKR" then
                                local man = g / 10000
                                if g % 10000 == 0 then
                                    return "  = " .. BreakUpLargeNumbers(math.floor(man)) .. "만 골드"
                                end
                                return "  = 약 " .. string.format("%.1f", man) .. "만 골드"
                            end
                            return ""
                        end,
                    },
                    holdNoWarband = {
                        type = "toggle", name = L["이 계정 보유량에 전투부대 은행 넣지 않기"], order = 4, width = "full",
                        desc = L["하위 계정(WoW1, WoW2 등)은 전투부대 은행을 함께 쓰므로, 계정마다 보유량에 같은 은행이 들어갑니다.\n"]
                            .. L["계정별 보유량을 더해 볼 때는 은행을 넣을 계정 하나만 남기고 나머지 계정에서 켜세요. 설정은 계정마다 따로 저장됩니다.\n"]
                            .. L["켜면 목표 진행률, 보유량 순증, 달성 예상일, 보유량 탭에서 은행을 뺍니다. 지난 기록도 은행을 빼고 다시 계산합니다."],
                        get = function() return DB.settings.holdNoWarband == true end,
                        set = function(_, val)
                            DB.settings.holdNoWarband = val or nil
                            QTR:Refresh()
                        end,
                    },
                },
            },
            displayGroup = {
                type = "group", name = L["대시보드 창"], order = 2, inline = true,
                args = {
                    bgAlpha = {
                        type = "range", name = L["배경 투명도"], order = 2, width = "full",
                        min = 0, max = 1, step = 0.05,
                        get = function() return DB.settings.alpha end,
                        set = function(_, val)
                            DB.settings.alpha = val
                            customBg:SetColorTexture(0, 0, 0, val)
                        end,
                    },
                    dashScale = {
                        type = "range", name = L["대시보드 창 크기"], order = 2.5, width = "full",
                        desc = L["글씨와 창을 함께 키우거나 줄입니다. 창 왼쪽 위 모서리는 제자리에 있습니다.\n"]
                            .. L["내비게이션 창 크기는 내비게이션 묶음에서 따로 정합니다."],
                        min = 0.8, max = 1.5, step = 0.05, isPercent = true,
                        get = function() return DB.settings.dashScale or DB.settings.uiScale or 1 end,
                        set = function(_, val)
                            QTR.ApplyUIScale() -- 예전 공통 설정이 있으면 먼저 옮긴다
                            local old = DB.settings.dashScale or 1
                            DB.settings.dashScale = val
                            QTR.ApplyUIScale("dash", old)
                        end,
                    },
                    -- 창 세로 길이는 탭 내용에 맞춰 자동으로 바뀐다 (최소 400, 최대 700)
                    frameLocked = {
                        type = "toggle", name = L["창 위치 고정 (창을 끌어서 옮기지 못하게 합니다)"], order = 2.9, width = "full",
                        get = function() return DB.settings.frameLocked end,
                        set = function(_, val)
                            DB.settings.frameLocked = val
                        end,
                    },
                    minimapShow = {
                        type = "toggle", name = L["미니맵 버튼 보이기"], order = 2.95, width = "full",
                        get = function() return not DB.settings.minimapHide end,
                        set = function(_, val)
                            DB.settings.minimapHide = not val
                            QTR.UpdateMinimapButton()
                        end,
                    },
                    resetPos = {
                        type = "execute", name = L["창 위치 초기화"], order = 4, width = 1.5,
                        desc = L["대시보드는 기본 위치로, 내비게이션 창은 다음에 열 때 대시보드 오른쪽으로 돌아갑니다."],
                        func = function()
                            DB.settings.pos = nil
                            DB.settings.routePopPos = nil -- 경로 팝업창은 다음에 열 때 메인 창 오른쪽에 붙는다
                            ApplyFramePosition()
                        end,
                    },
                },
            },
            notifyGroup = {
                type = "group", name = L["기록 알림"], order = 3, inline = true,
                args = {
                    chatNotify = {
                        type = "toggle", name = L["골드 전역퀘 기록 시 채팅창에 알림"], order = 1, width = "full",
                        get = function() return DB.settings.chatNotify end,
                        set = function(_, val) DB.settings.chatNotify = val end,
                    },
                },
            },
            keybindsGroup = {
                type = "group", name = L["단축키"], order = 4, inline = true,
                args = {
                    bindDesc = {
                        type = "description",
                        name = L["|cffaaaaaa버튼을 누른 뒤 원하는 키를 누르면 지정됩니다. 여기서 지정한 키는 모든 캐릭터에 공통으로 적용되며, 같은 키를 쓰는 다른 기능보다 우선합니다.|r"],
                        order = 1, fontSize = "medium", width = "full",
                    },
                    -- 한 줄에 항목명(왼쪽)과 키 버튼(오른쪽): 게임 기본 단축키 설정창과 같은 모양
                    bindDashboardLabel = BindLabel(2, L["대시보드 열기/닫기"]),
                    bindDashboard = {
                        type = "keybinding", name = "", order = 2.1, width = 1.2,
                        get = function() return GetSavedKey("dashboard") end,
                        set = function(_, val) SetSavedKey("dashboard", val) end,
                    },
                    bindBreak1 = Break(2.5),
                    bindConfigLabel = BindLabel(3, L["설정창 열기/닫기"]),
                    bindConfig = {
                        type = "keybinding", name = "", order = 3.1, width = 1.2,
                        get = function() return GetSavedKey("config") end,
                        set = function(_, val) SetSavedKey("config", val) end,
                    },
                    bindBreak2 = Break(3.5),
                    bindRouteLabel = BindLabel(4, L["내비게이션 창 열기/닫기"]),
                    bindRoute = {
                        type = "keybinding", name = "", order = 4.1, width = 1.2,
                        get = function() return GetSavedKey("route") end,
                        set = function(_, val) SetSavedKey("route", val) end,
                    },
                    bindBreak3 = Break(4.5),
                    bindNavStartLabel = BindLabel(5, L["내비게이션 시작!"]),
                    bindNavStart = {
                        type = "keybinding", name = "", order = 5.1, width = 1.2,
                        get = function() return GetSavedKey("navStart") end,
                        set = function(_, val) SetSavedKey("navStart", val) end,
                    },
                },
            },
            navGroup = {
                type = "group", name = L["내비게이션"], order = 2.5, inline = true,
                args = {
                    navScale = {
                        type = "range", name = L["내비게이션 창 크기"], order = 0.5, width = "full",
                        desc = L["글씨와 창을 함께 키우거나 줄입니다. 창 왼쪽 위 모서리는 제자리에 있습니다."],
                        min = 0.8, max = 1.5, step = 0.05, isPercent = true,
                        get = function() return DB.settings.navScale or DB.settings.uiScale or 1 end,
                        set = function(_, val)
                            QTR.ApplyUIScale() -- 예전 공통 설정이 있으면 먼저 옮긴다
                            local old = DB.settings.navScale or 1
                            DB.settings.navScale = val
                            QTR.ApplyUIScale("nav", old)
                        end,
                    },
                    -- 작은 글씨, 배경 투명도 (2026-10-30, 인벤 루세로님 요청: 창은 크게 두고 글씨만 작게, 글씨는 그대로 두고 배경만 투명하게)
                    navSmallFont = {
                        type = "toggle", name = L["작은 글씨"], order = 0.6, width = "full",
                        desc = L["내비게이션 창 목록의 글씨를 한 단계 작게 하고 줄 간격도 줄입니다.\n"]
                            .. L["창은 크게 두고 글씨만 작게 하고 싶을 때 창 크기와 함께 쓰세요."],
                        get = function() return DB.settings.navSmallFont end,
                        set = function(_, val)
                            DB.settings.navSmallFont = val or nil
                            QTR.RoutePopupUpdate()
                        end,
                    },
                    navBgAlpha = {
                        type = "range", name = L["배경 투명도"], order = 0.7, width = "full",
                        desc = L["내비게이션 창의 검은 배경만 투명하게 합니다. 글씨는 그대로입니다.\n"]
                            .. L["(아래 \"흐리게\"는 마우스를 올리지 않았을 때 글씨까지 창 전체를 흐리게 합니다.)"],
                        min = 0, max = 1, step = 0.05,
                        get = function() return DB.settings.navBgAlpha or 0.85 end,
                        set = function(_, val)
                            DB.settings.navBgAlpha = val
                            QTR.ApplyNavBg()
                        end,
                    },
                    navSoundOn = {
                        type = "toggle", name = L["모두 완료 시 소리 재생"], order = 1, width = "full",
                        desc = L["DBM이 설치되어 있으면 DBM의 FF 팡파레, 없으면 보스 처치 배너 소리를 재생합니다."],
                        get = function() return not DB.settings.navSoundOff end,
                        set = function(_, val) DB.settings.navSoundOff = not val end,
                    },
                    navFade = {
                        type = "toggle", name = L["마우스를 올리지 않았을 때 내비게이션 창을 흐리게"], order = 1.5, width = "full",
                        desc = L["창을 고정해 두고 동선을 돌 때 화면을 덜 가리게 합니다. 마우스를 올리면 다시 선명해집니다."],
                        get = function() return DB.settings.navFade end,
                        set = function(_, val) DB.settings.navFade = val end,
                    },
                    navFadeAlpha = {
                        type = "range", name = L["흐릴 때 불투명도"], order = 1.6, width = 1.5,
                        desc = L["100%면 그대로, 낮을수록 더 투명해집니다."],
                        min = 0.1, max = 1, step = 0.05, isPercent = true,
                        disabled = function() return not DB.settings.navFade end,
                        get = function() return DB.settings.navFadeAlpha or 0.8 end,
                        set = function(_, val) DB.settings.navFadeAlpha = val end,
                    },
                },
            },
            -- 동선에 넣는 이동 수단과 쓸 차례의 사용 버튼 창 (2026-10-27 사용자 요청으로 묶음을 나눔)
            travelGroup = {
                type = "group", name = L["동선에 넣는 이동 수단"], order = 2.6, inline = true,
                args = {
                    hearthOn = {
                        type = "toggle", name = L["귀환석을 동선에 넣기"], order = 2, width = "full",
                        desc = L["귀환석을 쓰면 15초 이상 빨라지는 구간이 있으면 한 번 넣습니다. 귀환석 모양 장난감도 같은 쿨타임이라 함께 쓸 수 있습니다.\n"]
                            .. L["귀환 지점 위치는 귀환석을 한 번 타면 캐릭터별로 기억합니다. 길드 혜택(빠른 귀환)과 인간 종족 특성도 반영합니다.\n"]
                            .. L["/qtr hearth 로 지금 상태를 볼 수 있습니다."],
                        get = function() return not DB.settings.hearthOff end,
                        set = function(_, val) DB.settings.hearthOff = not val end,
                    },
                    travelAstral = {
                        type = "toggle", name = L["주술사 영혼의 귀환을 동선에 넣기"], order = 4, width = "full",
                        desc = L["귀환 지점으로 가는 주술사 기술입니다. 쿨타임이 귀환석과 따로라 귀환석과 함께 쓸 수 있습니다."],
                        get = function() return not DB.settings.travelAstralOff end,
                        set = function(_, val) DB.settings.travelAstralOff = not val end,
                    },
                    travelMage = {
                        type = "toggle", name = L["마법사 실버문 순간이동을 동선에 넣기"], order = 5, width = "full",
                        desc = L["쿨타임이 없어 포탈처럼 필요할 때마다 씁니다."],
                        get = function() return not DB.settings.travelMageOff end,
                        set = function(_, val) DB.settings.travelMageOff = not val end,
                    },
                    -- 2026-11-08 인벤 김다크님 제안 (하라니르 종족 기술). 기본 켬 (마법사 순간이동과 같이)
                    travelRoot = {
                        type = "toggle", name = L["하라니르 뿌리걸음을 동선에 넣기"], order = 5.5, width = "full",
                        desc = L["하란다르의 요람으로 가는 종족 기술입니다. 쿨타임이 없어 포탈처럼 필요할 때마다 씁니다.\n"]
                            .. L["요람에 내리는 곳은 처음에는 어림으로 잡고, 하란다르의 세계수 뿌리에서 떨어진 곳에서 한 번 쓰면 실제로 내린 곳을 기억합니다.\n"]
                            .. L["세계수 뿌리 가까이에서는 다른 대륙의 세계수로 가므로 그 근처에서는 넣지 않습니다."],
                        get = function() return not DB.settings.travelRootOff end,
                        set = function(_, val) DB.settings.travelRootOff = not val end,
                    },
                    travelArcantina = {
                        type = "toggle", name = L["아르칸티나로 통하는 개인 열쇠를 동선에 넣기"], order = 6, width = "full",
                        desc = L["아르칸티나에 들어갔다가 나가는 차원문을 타면 실버문 여관(나그네의 쉼터)으로 나옵니다.\n"]
                            .. L["로딩이 두 번이라 귀환석보다 비용을 조금 크게(약 30초) 잡습니다. 쿨타임은 귀환석과 따로입니다."],
                        get = function() return not DB.settings.travelArcantinaOff end,
                        set = function(_, val) DB.settings.travelArcantinaOff = not val end,
                    },
                    travelMaisara = {
                        type = "toggle", name = L["마이사라 동굴 순간이동을 동선에 넣기"], order = 6.5, width = "full",
                        desc = L["쐐기돌 던전 마이사라 동굴을 10단계 이상으로 마치면 받는 순간이동(심연의 동굴의 길)으로 줄아만 마이사라 동굴 입구에 내립니다.\n"]
                            .. L["45초 이상 빨라지는 구간이 있으면 한 번 넣습니다 (다른 수단은 15초. 쿨타임이 길어서 확실히 빨라질 때만). 쿨타임이 8시간이고 다른 던전 순간이동도 함께 쿨타임에 걸리니, 쐐기돌 던전에 갈 때 쓰려면 끄세요."],
                        get = function() return DB.settings.travelMaisaraOn == true end,
                        set = function(_, val) DB.settings.travelMaisaraOn = val or nil end,
                    },
                    travelDundun = {
                        type = "toggle", name = L["둔둔의 풍요로운 이동 수단을 동선에 넣기 (시험 기능)"], order = 6.6, width = "full",
                        desc = L["지금 풍요가 열린 동굴로 가는 장난감입니다. 쿨타임이 30분이라 한 경로에서 두 번까지 넣습니다.\n"]
                            .. L["풍요 지점이 끝나기 2분 전부터는 넣지 않고, 안내 중에 지점이 바뀌면 남은 경로를 다시 짭니다.\n"]
                            .. L["제작자가 장난감이 없어 게임에서 확인하지 못한 기능입니다. 써 보시고 이상하면 알려 주세요."],
                        get = function() return DB.settings.travelDundunOn == true end,
                        set = function(_, val) DB.settings.travelDundunOn = val or nil end,
                    },
                    travelDelveBot = {
                        type = "toggle", name = L["구렁로봇 7001로 킨도잔의 미궁 가기를 동선에 넣기"], order = 6.7, width = "full",
                        desc = L["구렁로봇을 불러 \"킨도잔의 미궁으로 데려다주십시오.\"를 고르면 영원노래 숲 남쪽 미궁 입구로 순간이동합니다.\n"]
                            .. L["미궁 업데이트 칩이 있어야 합니다. 로봇에게 한 번 말을 걸면 칩이 있는지 기억합니다.\n"]
                            .. L["15초 이상 빨라지는 구간이 있으면 한 번 넣고, 그 차례에 로봇에게 말을 걸면 미궁을 자동으로 고릅니다 (Shift를 누르고 말을 걸면 고르지 않습니다).\n"]
                            .. L["쿨타임이 1시간이라 구렁에 갈 때 쓰려면 끄세요."],
                        get = function() return DB.settings.travelDelveBotOn == true end,
                        set = function(_, val) DB.settings.travelDelveBotOn = val or nil end,
                    },
                    -- 2026-11-08 사용자 요청 (램값 내비게이션에서 마이사라가 빠진 까닭을 알 수 없었다). 기본 끔
                    travelWhy = {
                        type = "toggle", name = L["이동 수단을 넣었는지와 그 이유를 채팅창에 알리기"], order = 6.8, width = "full",
                        desc = L["내비게이션을 시작할 때, 위의 이동 수단 중 가지고 있고 켜 둔 것을 동선에 넣었으면 어디서 쓰는지와 줄어드는 시간을,\n"]
                            .. L["넣지 않았으면 그 이유를 한 줄씩 알립니다.\n"]
                            .. L["예: 15초 이상 빨라지는 구간이 없어서, 쿨타임 중이라서, 귀환석 1회 남기기 때문에"],
                        get = function() return DB.settings.travelWhyOn == true end,
                        set = function(_, val) DB.settings.travelWhyOn = val or nil end,
                    },
                    travelPopup = {
                        type = "toggle", name = L["귀환석, 순간이동을 쓸 차례에 사용 버튼 창 띄우기"], order = 7, width = "full",
                        desc = L["창을 누르면 그 기술이나 장난감을 씁니다. 창 위쪽 띠를 끌어서 옮길 수 있습니다."],
                        get = function() return not DB.settings.travelPopupOff end,
                        set = function(_, val)
                            DB.settings.travelPopupOff = not val
                            QTR.UpdateTravelButton()
                        end,
                    },
                    travelPopupReset = {
                        type = "execute", name = L["사용 버튼 창 위치 초기화"], order = 8, width = 1.5,
                        desc = L["동선 중 사용 버튼 창과 마친 뒤 귀환 버튼 창은 같은 창입니다."],
                        func = function() QTR.ResetTravelAlertPos() end,
                    },
                },
            },
            -- 내비게이션을 마칠 때: 귀환석 1회 남기기와 마친 뒤 귀환 버튼 창
            finishGroup = {
                type = "group", name = L["내비게이션을 마칠 때"], order = 2.7, inline = true,
                args = {
                    hearthKeep = {
                        type = "toggle", name = L["내비게이션을 마칠 때 귀환석 1회 남기기"], order = 3, width = "full",
                        desc = L["켜 두면 다 마칠 무렵에 귀환석을 다시 쓸 수 있을 때만 동선에 넣습니다."],
                        disabled = function() return DB.settings.hearthOff end,
                        get = function() return not DB.settings.hearthKeepOff end,
                        set = function(_, val) DB.settings.hearthKeepOff = not val end,
                    },
                    finishPopup = {
                        type = "toggle", name = L["내비게이션을 마치면 귀환 버튼 창 띄우기"], order = 7.5, width = "full",
                        desc = L["모든 목적지를 마치면 아래에서 고른 것 중 지금 쓸 수 있는 것 하나를 사용 버튼 창에 띄웁니다.\n"]
                            .. L["순서: 실버문 순간이동, 영혼의 귀환, 귀환석, 아르칸티나 열쇠. 쓸 수 있는 것이 없거나 이미 그 도착지 가까이 있으면 띄우지 않습니다.\n"]
                            .. L["동선에 넣는 설정과는 따로입니다."],
                        get = function() return not DB.settings.finishPopupOff end,
                        set = function(_, val)
                            DB.settings.finishPopupOff = not val
                            if not val then
                                QTR.UpdateTravelButton()
                            end
                        end,
                    },
                    finishMage = {
                        type = "toggle", name = L["실버문 순간이동"], order = 7.51, width = 0.8,
                        disabled = function() return DB.settings.finishPopupOff end,
                        get = function() return not DB.settings.finishMageOff end,
                        set = function(_, val) DB.settings.finishMageOff = not val end,
                    },
                    finishAstral = {
                        type = "toggle", name = L["영혼의 귀환"], order = 7.52, width = 0.8,
                        disabled = function() return DB.settings.finishPopupOff end,
                        get = function() return not DB.settings.finishAstralOff end,
                        set = function(_, val) DB.settings.finishAstralOff = not val end,
                    },
                    finishHearth = {
                        type = "toggle", name = L["귀환석"], order = 7.53, width = 0.8,
                        disabled = function() return DB.settings.finishPopupOff end,
                        get = function() return not DB.settings.finishHearthOff end,
                        set = function(_, val) DB.settings.finishHearthOff = not val end,
                    },
                    finishArcantina = {
                        type = "toggle", name = L["아르칸티나 열쇠"], order = 7.54, width = 0.8,
                        disabled = function() return DB.settings.finishPopupOff end,
                        get = function() return not DB.settings.finishArcantinaOff end,
                        set = function(_, val) DB.settings.finishArcantinaOff = not val end,
                    },
                },
            },
            classGroup = {
                type = "group", name = L["다음 추천 캐릭터"], order = 4.6, inline = true, args = classArgs,
            },
            cacheGroup = {
                type = "group", name = L["정점 보관함"], order = 4.5, inline = true,
                args = {
                    cacheDesc = {
                        type = "description",
                        name = L["|cffaaaaaa골드퀘를 하다 열리는 특별 과제와 그 보상인 정점 보관함 2종(%s, %s)을 따라갑니다.\n"]:format(
                            GetItemNameSafe(DEFAULT_CACHE_ITEMS[1]), GetItemNameSafe(DEFAULT_CACHE_ITEMS[2]))
                            .. L["실버문 주간 퀘스트 등에서 받는 다른 정점 보관함은 열 때 나온 골드를 획득량 탭에 기록하고,\n"]
                            .. L["이번 주에 받은 캐릭터가 있으면 부자되기 탭 \"다른 정점 보관함\" 묶음에 캐릭터별 획득 여부를 보여 줍니다.\n"]
                            .. L["보관함 하나에서 3,000골드 이상 나오면 대박(은색 별), 10,000골드 이상이면 초대박(금색 별)으로 표시합니다.|r"],
                        order = 1, fontSize = "medium", width = "full",
                    },
                    cacheAlert = {
                        type = "toggle", name = L["가방에 열지 않은 정점 보관함이 있으면 알림창 표시 (클릭해서 열기)"], order = 2, width = "full",
                        get = function() return DB.settings.cacheAlert end,
                        set = function(_, val)
                            DB.settings.cacheAlert = val
                            UpdateCacheAlert()
                        end,
                    },
                    resetAlertPos = {
                        type = "execute", name = L["알림창 위치 초기화"], order = 2.1, width = 1.2,
                        func = function()
                            DB.settings.cacheAlertPos = nil
                            ApplyCacheAlertPosition()
                        end,
                    },
                },
            },
            banGroup = {
                type = "group", name = L["추적 제외 퀘스트"], order = 4.7, inline = true,
                args = {
                    banDesc = {
                        type = "description", order = 1, fontSize = "medium", width = "full",
                        name = L["|cffaaaaaaPVP 퀘스트처럼 하지 않는 퀘스트를 골드퀘, 부자되기 탭에서 뺍니다. 완료 기록은 그대로 남습니다.\n"]
                            .. L["채팅창에 /qtr ban 을 입력하고 한 칸 띄운 뒤 퀘스트를 Shift+클릭해도 추가됩니다.|r"],
                    },
                    hideBanned = {
                        type = "toggle", name = L["제외 목록 적용 (끄면 목록은 두고 다시 보여줍니다)"], order = 2, width = "full",
                        get = function() return DB.settings.hideBanned end,
                        set = function(_, val)
                            DB.settings.hideBanned = val
                            QTR.forceScan = true
                            QTR:Refresh()
                        end,
                    },
                    candidate = {
                        type = "select", name = L["지금 알고 있는 골드퀘"], order = 3, width = 2,
                        -- "퀘스트명 (지역명)", 지역별로 묶어 보여준다 (지역, 이름 순)
                        values = function()
                            local values = {}
                            for questID, e in pairs(DB.activeGQ) do
                                if not DB.settings.bannedQuests[questID] then
                                    values[questID] = tostring(e.name or questID) .. (e.zone and (" (" .. e.zone .. ")") or "")
                                end
                            end
                            return values
                        end,
                        sorting = function()
                            local keys = {}
                            for questID, e in pairs(DB.activeGQ) do
                                if not DB.settings.bannedQuests[questID] then
                                    table.insert(keys, questID)
                                end
                            end
                            table.sort(keys, function(a, b)
                                local ea, eb = DB.activeGQ[a], DB.activeGQ[b]
                                local za, zb = ea.zone or "", eb.zone or ""
                                if za ~= zb then
                                    return za < zb
                                end
                                return (ea.name or "") < (eb.name or "")
                            end)
                            return keys
                        end,
                        get = function() return QTR.banCandidate end,
                        set = function(_, val) QTR.banCandidate = val end,
                    },
                    addBan = {
                        type = "execute", name = L["제외 목록에 추가"], order = 4, width = 1,
                        disabled = function() return not QTR.banCandidate or not DB.activeGQ[QTR.banCandidate] end,
                        func = function()
                            local e = DB.activeGQ[QTR.banCandidate]
                            QTR.BanQuest(QTR.banCandidate, e.name)
                            QTR.forceScan = true
                            QTR.banCandidate = nil
                            AceConfigRegistry:NotifyChange(ADDON_NAME)
                            QTR:Refresh()
                        end,
                    },
                    banned = {
                        type = "select", name = L["제외한 퀘스트"], order = 5, width = 2,
                        values = function()
                            local values = {}
                            for questID in pairs(DB.settings.bannedQuests) do
                                values[questID] = QTR.BanLabel(questID)
                            end
                            return values
                        end,
                        sorting = function()
                            local keys = {}
                            for questID in pairs(DB.settings.bannedQuests) do
                                table.insert(keys, questID)
                            end
                            table.sort(keys, function(a, b) return QTR.BanLabel(a) < QTR.BanLabel(b) end)
                            return keys
                        end,
                        get = function() return QTR.banSelected end,
                        set = function(_, val) QTR.banSelected = val end,
                    },
                    removeBan = {
                        type = "execute", name = L["제외 해제"], order = 6, width = 1,
                        disabled = function() return not QTR.banSelected or not DB.settings.bannedQuests[QTR.banSelected] end,
                        func = function()
                            QTR.UnbanQuest(QTR.banSelected)
                            QTR.forceScan = true
                            QTR.banSelected = nil
                            AceConfigRegistry:NotifyChange(ADDON_NAME)
                            QTR:Refresh()
                        end,
                    },
                },
            },
            charGroup = {
                type = "group", name = L["캐릭터 관리"], order = 5, inline = true,
                args = {
                    charDesc = {
                        type = "description",
                        name = L["|cffaaaaaa캐릭터는 접속하면 자동으로 등록됩니다.\n"]
                            .. L["목록에서 제거: 보유 골드 목록과 합계에서만 뺍니다. 기록은 남고, 그 캐릭터로 다시 접속하면 다시 등록됩니다.\n"]
                            .. L["보유량 기록 삭제: 보유량 탭 상세 보기의 날짜별 기록에서 그 캐릭터를 지웁니다. 다음에 접속하면 그날부터 다시 쌓입니다.\n"]
                            .. L["모든 기록 삭제: 목록, 골드퀘/정점 보관함 기록, 보유량 기록을 모두 지웁니다. 되돌릴 수 없습니다.\n"]
                            .. L["(보유량 탭 요약의 날짜별 계정 합계는 캐릭터별로 나뉘어 있지 않아 그대로 남습니다.)|r"],
                        order = 1, fontSize = "medium", width = "full",
                    },
                    target = {
                        type = "select", name = L["캐릭터"], order = 2, width = "full",
                        values = function() return QTR.charOptValues() end,
                        sorting = function() return QTR.charOptSorting(QTR.charOptValues()) end,
                        get = function() return selectedChar end,
                        set = function(_, val) selectedChar = val end,
                    },
                    remove = {
                        type = "execute", name = L["목록에서 제거"], order = 3, width = 1,
                        disabled = function() return not selectedChar or not DB.chars[selectedChar] end,
                        confirm = true,
                        confirmText = L["선택한 캐릭터를 목록에서 제거할까요? 기록은 남습니다."],
                        func = function()
                            DB.chars[selectedChar] = nil
                                                            Print(L["%s 캐릭터를 목록에서 제거했습니다."]:format(selectedChar))
                            RecordSnapshot()
                            AceConfigRegistry:NotifyChange(ADDON_NAME)
                            QTR:Refresh()
                        end,
                    },
                    deleteHold = {
                        type = "execute", name = L["보유량 기록 삭제"], order = 4, width = 1,
                        disabled = function() return not selectedChar or not HasHoldRecord(selectedChar) end,
                        confirm = true,
                        confirmText = L["선택한 캐릭터의 날짜별 보유량 기록을 모두 삭제할까요? 되돌릴 수 없습니다."],
                        func = function()
                            DeleteHoldRecords(selectedChar)
                                                            Print(L["%s 캐릭터의 보유량 기록을 삭제했습니다."]:format(selectedChar))
                            AceConfigRegistry:NotifyChange(ADDON_NAME)
                            QTR:Refresh()
                        end,
                    },
                    deleteAll = {
                        type = "execute", name = L["모든 기록 삭제"], order = 5, width = 1,
                        disabled = function() return not selectedChar end,
                        confirm = true,
                        confirmText = L["선택한 캐릭터의 목록, 골드퀘/정점 보관함 기록, 보유량 기록을 모두 삭제할까요? 되돌릴 수 없습니다."],
                        func = function()
                            local key = selectedChar
                            DB.chars[key] = nil
                            DB.turnIns[key] = nil
                            DB.cacheGets[key] = nil
                            DB.flagDone[key] = nil
                            DB.weeklyOn[key] = nil
                            DB.saLock[key] = nil
                            DeleteHoldRecords(key)
                            for dayKey, day in pairs(DB.days) do
                                day[key] = nil
                                if next(day) == nil then
                                    DB.days[dayKey] = nil
                                end
                            end
                            selectedChar = nil
                            Print(L["%s 캐릭터의 모든 기록을 삭제했습니다."]:format(key))
                            RecordSnapshot()
                            AceConfigRegistry:NotifyChange(ADDON_NAME)
                            QTR:Refresh()
                        end,
                    },
                    -- 기록 합치기 (2026-10-29): 원본의 기록을 대상에 합치고 원본 기록은 지운다 (QTR.MergeChars)
                    mergeDesc = {
                        type = "description", order = 6, fontSize = "medium", width = "full",
                        name = L["\n|cffaaaaaa기록 합치기: 원본 캐릭터의 골드퀘/정점 보관함 기록, 보유량 기록, 완료 기록을 대상 캐릭터에 합칩니다.\n"]
                            .. L["캐릭터 이름을 바꿨거나 같은 캐릭터가 둘로 보일 때 씁니다. 같은 날 보유 골드는 대상의 값을 남깁니다.\n"]
                            .. L["합친 뒤 원본의 기록은 지워지며 되돌릴 수 없습니다. 지금 접속한 캐릭터는 원본으로 고를 수 없습니다.|r"],
                    },
                    mergeFrom = {
                        type = "select", name = L["원본 (지워질 캐릭터)"], order = 7, width = 1.5,
                        values = function() return QTR.mergeFromValues() end,
                        sorting = function() return QTR.charOptSorting(QTR.mergeFromValues()) end,
                        get = function() return QTR.mergeFrom end,
                        set = function(_, val)
                            QTR.mergeFrom = val
                            -- 대상과 같은 캐릭터를 원본으로 고르면 대상을 비운다 (대상 목록에서 원본은 빠지므로)
                            if QTR.mergeTo == val then
                                QTR.mergeTo = nil
                            end
                        end,
                    },
                    mergeTo = {
                        type = "select", name = L["대상 (남을 캐릭터)"], order = 8, width = 1.5,
                        values = function() return QTR.mergeToValues() end,
                        sorting = function() return QTR.charOptSorting(QTR.mergeToValues()) end,
                        get = function() return QTR.mergeTo end,
                        set = function(_, val) QTR.mergeTo = val end,
                    },
                    mergeRun = {
                        type = "execute", name = L["기록 합치기"], order = 9, width = 1,
                        disabled = function()
                            local a, b = QTR.mergeFrom, QTR.mergeTo
                            return not a or not b or a == b or a == charKey
                        end,
                        confirm = function()
                            local a, b = QTR.mergeFrom, QTR.mergeTo
                            local p = QTR.MergePreview(a, b)
                            -- 캐릭터 이름은 직업 색, 이름과 괄호 부분이 줄 중간에서 끊기지 않게 줄을 나눈다 (2026-11-01 사용자 요청)
                            local ca, cb = ColorName(a), ColorName(b)
                            local text = L["%s의 기록을\n%s(으)로 합칩니다.\n\n"]:format(ca, cb)
                                .. string.format(L["골드퀘/정점 보관함 기록 %d일치\n(골드퀘 %d개, 보관함 %d개, %s)"], p.days, p.quests, p.caches, FormatGold(p.money))
                            if p.sameDays > 0 then
                                text = text .. L["\n그중 %d일은 같은 날 기록이 있어 하나로 합칩니다."]:format(p.sameDays)
                            end
                            text = text .. L["\n보유량 기록 %d일치"]:format(p.holdDays)
                            if p.holdKept > 0 then
                                text = text .. L["\n(같은 날 %d일은 %s의 값을 남깁니다)"]:format(p.holdKept, cb)
                            end
                            -- 마지막 줄 빨간색 강조 (2026-10-31 사용자 요청)
                            text = text .. L["\n완료 기록 %d개\n\n%s의 기록은 모두 지워지며\n|cffff2020되돌릴 수 없습니다.|r"]:format(p.turnIns, ca)
                            return text
                        end,
                        func = function()
                            local a, b = QTR.mergeFrom, QTR.mergeTo
                            local ca, cb = ColorName(a), ColorName(b) -- 합치면 원본 캐릭터 정보가 지워지므로 미리 색을 입힌다
                            if QTR.MergeChars(a, b) then
                                Print(L["%s의 기록을 %s(으)로 합쳤습니다."]:format(ca, cb))
                                if selectedChar == a then
                                    selectedChar = nil
                                end
                                QTR.mergeFrom = nil
                                RecordSnapshot()
                                AceConfigRegistry:NotifyChange(ADDON_NAME)
                                QTR:Refresh()
                            end
                        end,
                    },
                },
            },
            dataGroup = {
                type = "group", name = L["데이터 관리"], order = 6, inline = true,
                args = {
                    dataDesc = {
                        type = "description", order = 1, fontSize = "medium", width = "full",
                        name = function()
                            return L["|cffaaaaaa기록은 자동으로 지워지지 않고 계속 쌓입니다. 현재 저장된 기록: %d일|r"]:format(GetStoredDayCount())
                        end,
                    },
                    resetData = {
                        type = "execute", name = L["기록 전체 삭제"], order = 2, width = 1.5,
                        desc = L["날짜별 골드 전역퀘 기록과 보유 골드 추세 기록을 모두 지웁니다. 캐릭터 목록, 보유 골드, 설정은 남습니다."],
                        confirm = true,
                        confirmText = L["골드 전역퀘 기록과 보유 골드 추세 기록을 모두 삭제할까요? 되돌릴 수 없습니다."],
                        func = function()
                            DB.days = {}
                            DB.snapshots = {}
                            DB.holdDays = {}
                            DB.turnIns = {}
                            DB.cacheGets = {}
                            RecordSnapshot()
                            statsPeriodKey = nil
                            wipe(stats.periodByMode)
                            AceConfigRegistry:NotifyChange(ADDON_NAME)
                            QTR:Refresh()
                            Print(L["기록을 모두 삭제했습니다."])
                        end,
                    },
                },
            },
        },
    }
end

-------------------------------------------------------------------------------
-- 이벤트
-------------------------------------------------------------------------------

function QTR:QUEST_TURNED_IN(_, questID, xpReward, moneyReward)
    if not DB or not charKey or not questID then
        return
    end
    -- 퀘스트 완료 시각 (부자되기 탭의 골드퀘, 보관함 출처 완료 판정)
    RecordTurnIn(questID)
    -- 이 퀘스트에 찍어 둔 웨이포인트를 지우고, 내비게이션 중이면 다음 목적지로 넘어간다
    QTR.ClearWaypointFor(questID)
    if QTR.RouteAdvance then
        QTR.RouteAdvance(questID)
        -- 이 완료로 특별 과제가 열렸을 수 있다: 잠시 뒤 확인해서 경로에 넣는다 (내비게이션 중일 때만)
        QTR.RouteWatch()
    end
    QTR.forceScan = true
    QTR:ScheduleRefresh()
    -- 내비게이션 창이 대기 화면으로 열려 있으면 넣을 수 있는 곳 수를 다시 센다 (완료 표시가 늦게 바뀌어 잠시 뒤에)
    if not QTR.route and not QTR.routeDoneList then
        C_Timer.After(2, function()
            if not QTR.route and not QTR.routeDoneList then
                QTR.forceScan = true
                QTR.RoutePopupUpdate()
            end
        end)
    end
    if not (C_QuestLog and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID)) then
        return
    end
    moneyReward = moneyReward or 0
    if moneyReward < GOLD_THRESHOLD then
        return
    end

    local dayKey = GetDayKey()
    DB.days[dayKey] = DB.days[dayKey] or {}
    local rec = DB.days[dayKey][charKey]
    if not rec then
        rec = { count = 0, money = 0, quests = {} }
        DB.days[dayKey][charKey] = rec
    end

    -- 같은 날 같은 퀘스트 중복 기록 방지
    for _, q in ipairs(rec.quests) do
        if q.id == questID then
            return
        end
    end

    local title = GetQuestTitle(questID)
    local zone = GetQuestZoneName(questID)
    table.insert(rec.quests, {
        id = questID,
        name = title,
        zone = zone,
        money = moneyReward,
        t = time(),
    })
    rec.count = rec.count + 1
    rec.money = rec.money + moneyReward

    if DB.settings.chatNotify then
        Print(string.format(L["%s (%s) +%s / 오늘 %d개, %s"], title, zone, FormatGold(moneyReward), rec.count, FormatGold(rec.money)) .. FormatGoalNote(moneyReward) .. FormatSavedNote(moneyReward))
    end

    QTR:Refresh()
end

-- 내비게이션 중 전쟁 모드를 바꾸면 남은 경로를 바로 다시 짠다 (2026-11-05 사용자 결정, 인벤 나이샤님 질문에서:
--   전쟁 모드에서는 보상이 골드가 아닌 것으로 바뀌는 퀘스트가 있다. 다시 짜지 않으면 골드가 아니게 된 퀘스트가 경로에 남고,
--   골드가 된 퀘스트는 다음 완료 때에야 들어간다). 전쟁 모드 상태는 접속 때부터 기억해 바뀐 때만 다시 짠다 (자리비움 등은 무시)
--   보상 정보가 바뀌어 들어올 시간을 1초 둔다. 골드가 아니게 된 퀘스트는 검색 때 notGoldFor로 기억되어 RouteQuestsMissing이 기다리지 않는다
function QTR.WarModeCheck()
    local on = (C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired()) and true or false
    local before = QTR.warModeSeen
    QTR.warModeSeen = on
    if before == nil or before == on or not QTR.route then
        return
    end
    C_Timer.After(1, function()
        if QTR.route then
            QTR.forceScan = true
            QTR.RouteStart(on and L["전쟁 모드를 켰습니다."] or L["전쟁 모드를 껐습니다."])
        end
    end)
end

function QTR:PLAYER_FLAGS_CHANGED(_, unit)
    if unit == "player" then
        QTR.NavLogAfk() -- 자리비움 켜고 끄기도 이 이벤트로 온다
        QTR.forceScan = true
        QTR:ScheduleRefresh()
        QTR.WarModeCheck()
    end
end

function QTR:PLAYER_MONEY()
    UpdateCharInfo()
    RecordSnapshot()
    OnCacheMoneyChanged()
    QTR:Refresh()
end

function QTR:ACCOUNT_MONEY()
    UpdateWarbandMoney()
    RecordSnapshot()
    QTR:Refresh()
end

-- 전투가 시작되기 직전: 키보드를 놓아 둔다 (전투 중에는 키보드 설정을 바꿀 수 없다)
function QTR:PLAYER_REGEN_DISABLED()
    QTR.SetTabKeys(false)
end

function QTR:PLAYER_REGEN_ENABLED()
    if pendingBindings then
        ApplyKeyBindings()
    end
    if pendingAlertUpdate then
        UpdateCacheAlert()
    end
    if QTR.TravelButtonPending and QTR.TravelButtonPending() then
        QTR.UpdateTravelButton()
    end
end

-- 정점 보관함: 전리품 창이 열리면 보관함을 여는 중인지 표시하고, 놓친 경우 출처로 확인
function QTR:LOOT_OPENED()
    if pendingCache then
        pendingCache.lootSeen = true
        return
    end
    local itemID = GetLootSourceCacheID()
    if itemID then
        StartCache(itemID)
        if pendingCache then
            pendingCache.lootSeen = true
        end
    end
end

function QTR:LOOT_CLOSED()
    if pendingCache then
        C_Timer.After(0.5, FinishCache)
    end
end

function QTR:BAG_UPDATE_DELAYED()
    UpdateCacheGets()
    UpdateCacheAlert()
    RecordCacheBag()
    if currentTab ~= "stats" and currentTab ~= "hold" then
        QTR:ScheduleRefresh()
    end
end

function QTR:PLAYER_ENTERING_WORLD()
    -- 접속, 순간이동 때마다 사용자가 닫은 알림을 다시 보여준다 (HDT 은혜 알림과 같은 방식)
    cacheAlert.closedByUser = false
    C_Timer.After(2, UpdateCacheAlert)
    C_Timer.After(3, function() -- 캐릭터 정보(2초 뒤 저장)가 먼저 만들어진 뒤
        UpdateCacheGets()
        RecordCacheBag()
    end)
    QTR.PreloadGoldQuests()
    QTR.WarModeCheck() -- 전쟁 모드 상태를 기억해 둔다 (바뀌면 내비게이션 경로를 다시 짠다)
    -- 현재 골드 전역퀘와 특별 과제 보상을 계정 공용 목록에 모아 둔다 (부자되기 탭용)
    C_Timer.After(5, QTR.ScanQuestBoard)
    C_Timer.After(15, QTR.ScanQuestBoard)
    -- 완료 기록의 하위 지도 이름을 골드퀘 지역 이름으로 바로잡는다 (접속 후 한 번, 고친 게 있으면 알린다)
    if not QTR.zonesFixed then
        QTR.zonesFixed = true
        local ok, fixed = pcall(QTR.FixRecordedZones)
        if ok and fixed and fixed > 0 then
            Print(L["완료 기록 %d건의 지역명을 골드퀘 지역 이름으로 바로잡았습니다. (예: 학살자의 오름길은 공허폭풍으로)"]:format(fixed))
            QTR:Refresh()
        end
    end
end

-- NPC 퀘스트 창: 보상이 정점 보관함이면 출처로 학습
function QTR:QUEST_DETAIL()
    LearnFromQuestFrame()
end

function QTR:QUEST_COMPLETE()
    LearnFromQuestFrame()
end

-- 실버문 주간 퀘스트를 받거나 포기하면 "수행중" 기록을 새로 쓴다 (퀘스트 목록이 바뀐 뒤에 보도록 조금 뒤에)
function QTR.WeeklyLogChanged(questID) -- 메인 청크 local을 아끼려고 QTR에 둔다
    if questID and QTR.SILVERMOON_WEEKLY_IDS[questID] then
        C_Timer.After(0.5, function()
            QTR.ScanWeeklyFlags()
            QTR:Refresh()
        end)
    end
end

function QTR:QUEST_ACCEPTED(_, questID)
    LearnFromQuestLog(questID)
    QTR.WeeklyLogChanged(questID)
end

function QTR:QUEST_REMOVED(_, questID)
    QTR.WeeklyLogChanged(questID)
end

-- 접속 종료(/reload 포함) 직전에 실버문 주간 퀘스트 진행도를 한 번 더 남긴다 (창을 열지 않고 진행한 만큼, 2026-11-01)
-- 실버문 주간 퀘스트 진행도는 퀘스트 목록이 바뀔 때마다 남긴다 (창을 열지 않고 진행한 만큼, 2초 안의 호출은 한 번으로 묶는다)
--   처음에는 접속 종료(PLAYER_LOGOUT) 때 남겼으나 그때는 퀘스트 목록이 이미 비어 있어 수행중 기록을 지웠다 (2026-11-01 사용자 제보)
function QTR.QueueWeeklyScan()
    if QTR.weeklyScanQueued then
        return
    end
    QTR.weeklyScanQueued = true
    C_Timer.After(2, function()
        QTR.weeklyScanQueued = false
        QTR.ScanWeeklyFlags()
    end)
end

-- 전역퀘 정보가 바뀌면 골드퀘 탭을 갱신 (자주 발생하는 이벤트라 0.5초 안의 호출은 한 번으로 묶는다)
local gqUpdateQueued = false
function QTR:QUEST_LOG_UPDATE()
    QTR.QueueWeeklyScan()
    if (currentTab ~= "gq" and currentTab ~= "dash") or not f:IsShown() or gqUpdateQueued then
        return
    end
    gqUpdateQueued = true
    C_Timer.After(0.5, function()
        gqUpdateQueued = false
        QTR:Refresh()
    end)
end

-------------------------------------------------------------------------------
-- 초기화
-------------------------------------------------------------------------------

function QTR:OnInitialize()
    InitDB()
    AceConfig:RegisterOptionsTable(ADDON_NAME, BuildOptions())
    AceConfigDialog:SetDefaultSize(ADDON_NAME, 640, 620)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions(ADDON_NAME, "QuestsToRiches")
    customBg:SetColorTexture(0, 0, 0, DB.settings.alpha)
    QTR.ApplyUIScale() -- 창 크기와 위치 (세로 길이는 탭 내용을 그릴 때 맞춘다)
    ApplyCacheAlertPosition()
    QTR.ApplyDashPinned() -- 대시보드 창 고정(Esc로 닫히지 않음) 상태
    QTR.ApplyNavPinned() -- 내비게이션 창 고정 상태
    QTR.ApplyNavBg() -- 내비게이션 창 배경 투명도
    currentTab = DB.settings.tab
end

function QTR:OnEnable()
    charKey = GetCharKey()
    self:RegisterEvent("QUEST_TURNED_IN")
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_FLAGS_CHANGED") -- 전쟁 모드 켜고 끄기 (골드퀘 탭 금액 다시 계산)
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    -- 전투부대 은행 골드 변동 이벤트 (없는 클라이언트에서는 등록하지 않는다)
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("ACCOUNT_MONEY") then
        self:RegisterEvent("ACCOUNT_MONEY")
    end

    -- 정점 보관함 기록과 알림
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("QUEST_ACCEPTED")
    self:RegisterEvent("QUEST_REMOVED") -- 실버문 주간 퀘스트 포기 (완료도 이 이벤트가 오지만 완료 기록이 먼저 본다)    -- 가방에서 우클릭으로 열 때 (상점, 은행, 우편이 열려 있으면 StartCache에서 제외)
    if C_Container and C_Container.UseContainerItem and C_Container.GetContainerItemID then
        hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if QTR.IsApexItem(itemID) then
                StartCache(itemID)
            end
        end)
    end

    MigrateKeyBindings()
    ApplyKeyBindings()
    QTR.SetupMinimap()

    -- 접속 직후에는 보유 골드가 늦게 들어올 수 있어 잠시 뒤에 저장한다
    C_Timer.After(2, function()
        UpdateCharInfo()
        UpdateWarbandMoney()
        RecordSnapshot()
        QTR.ScanWeeklyFlags() -- 실버문 주간 퀘스트 완료 표시 (부자되기 탭을 열지 않아도 남긴다)
        QTR:Refresh()
    end)

    if migratedFrom then
        Print(L["이전 %s 기록과 설정을 옮겨 왔습니다."]:format(migratedFrom))
    end
    -- 애드온 버전도 함께 (2026-11-08 사용자 요청). TOC의 Version을 읽고, 못 읽으면 예전 문구
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local okVer, ver = pcall(function() return getMeta and getMeta(ADDON_NAME, "Version") end)
    if okVer and type(ver) == "string" and ver ~= "" then
        Print(L["로드 완료 (v%s). /qtr 창 열기, /qtr set 설정창"]:format(ver))
    else
        Print(L["로드 완료. /qtr 창 열기, /qtr set 설정창"])
    end
    if QTR.whyNotice then
        QTR.whyNotice = nil
        Print(L["이번 버전부터 이동 수단 채팅 알림(동선에 넣었습니다, 넣지 않았습니다)은 기본으로 나오지 않습니다. 보고 싶으면 설정창 '동선에 넣는 이동 수단' 묶음에서 '이동 수단을 넣었는지와 그 이유를 채팅창에 알리기'를 켜 주세요."])
    end
end

-------------------------------------------------------------------------------
-- 슬래시 명령어
-------------------------------------------------------------------------------

-- /qtr locale: 클라이언트 언어로 게임이 주는 글자를 채팅창에 찍는다 (2026-10-31 영어 클라이언트 지원)
--   Locales\enUS.lua의 Game 값(특별 과제 앞말, 정점 보관함 툴팁 줄, 여관 이름, 주문 이름)을 확인해 채우는 데 쓴다
--   개발용이라 화면 문구는 번역하지 않는다 (영어 그대로)
function QTR.LocaleCheck()
    local function show(label, value)
        Print(label .. ": " .. tostring(value))
    end
    show("locale", GetLocale())
    show("realm", GetRealmName())
    show("char key", charKey)
    show("bind location (ARC_INN when at the Silvermoon inn)", GetBindLocation and GetBindLocation())
    for _, id in ipairs({ 92145, 93438, 95918 }) do
        show("special assignment " .. id .. " (SPECIAL_PREFIX)", QTR.LiveQuestTitle(id))
    end
    show("weekly quest 98172", QTR.LiveQuestTitle(98172))
    for _, id in ipairs({ 279520, 282183, 279527, 253629 }) do
        show("item " .. id, C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
    end
    -- 정점 보관함 툴팁 줄 (APEX_TOOLTIP: "정점 보관함 - 한밤 2 시즌"에 해당하는 줄)
    local ok, data = pcall(function() return C_TooltipInfo.GetItemByID(279520) end)
    if ok and type(data) == "table" and type(data.lines) == "table" then
        for i = 2, math.min(#data.lines, 5) do
            show("cache tooltip line " .. i, QTR.PlainText(data.lines[i].leftText))
        end
    end
    for _, id in ipairs({ 1259190, 556, 1255801 }) do
        show("spell " .. id .. " (MAGE_TELE for 1259190)", C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id))
    end
    for _, id in ipairs({ 2393, 2405, 2413, 2437, 2395, 2512, 2576 }) do
        local info = C_Map.GetMapInfo(id)
        show("map " .. id, info and info.name)
    end
end

SLASH_QUESTSTORICHES1 = "/qtr"
SlashCmdList["QUESTSTORICHES"] = function(msg)
    msg = strtrim(msg or "")
    local cmd = (msg:match("^(%S*)") or ""):lower()
    if cmd == "" then
        QuestsToRiches_ToggleDashboard()
    elseif cmd == "stats" or cmd == "gq" or cmd == "hold" or cmd == "rich" or cmd == "box" then
        if not f:IsShown() then
            QuestsToRiches_ToggleDashboard()
        end
        ShowTab((cmd == "rich" or cmd == "box") and "dash" or cmd)
    elseif cmd == "set" then
        QuestsToRiches_ToggleConfig()
    elseif cmd == "ban" or cmd == "unban" then
        -- /qtr ban [퀘스트 링크 또는 ID]: 추적 제외 목록에 추가, 인수가 없으면 목록 출력
        -- /qtr unban [퀘스트 링크 또는 ID]: 제외 목록에서 빼기
        local arg = msg:match("^%S+%s+(.+)$")
        local banned = DB.settings.bannedQuests
        if not arg then
            local any = false
            for questID in pairs(banned) do
                any = true
                Print(L["제외 퀘스트: "] .. QTR.BanLabel(questID))
            end
            if not any then
                Print(L["제외한 퀘스트가 없습니다. /qtr ban 입력 후 한 칸 띄우고 퀘스트를 Shift+클릭하세요."])
            end
        else
            local questID, name = QTR.ParseQuestArg(arg)
            if not questID then
                Print(L["퀘스트 링크나 숫자 퀘스트 ID를 넣어주세요."])
            elseif cmd == "ban" then
                QTR.BanQuest(questID, name)
                Print(L["추적에서 제외했습니다: "] .. QTR.BanLabel(questID))
            elseif banned[questID] then
                Print(L["제외를 해제했습니다: "] .. QTR.BanLabel(questID))
                QTR.UnbanQuest(questID)
            else
                local zone = QTR.QuestZone(questID)
                Print(L["제외 목록에 없는 퀘스트입니다: "] .. name .. (zone and (" (" .. zone .. ")") or ""))
            end
            QTR.forceScan = true
            AceConfigRegistry:NotifyChange(ADDON_NAME)
            QTR:Refresh()
        end
    elseif cmd == "pos" then
        -- /qtr pos [메모]: 지금 서 있는 곳의 지도 ID와 좌표를 저장하고 채팅창에 출력 (포탈 좌표 수집용)
        -- /qtr pos list: 저장한 좌표 목록 / /qtr pos clear: 저장한 좌표 모두 지우기
        QTR.PosCommand(msg:match("^%S+%s*(.-)$") or "")
    elseif cmd == "hearth" then
        -- /qtr hearth: 귀환석 상태 (귀환 지점, 대기시간, 지금 쓸 수 있는 충전 수)
        QTR.HearthStatus()
    elseif cmd == "route" then
        -- /qtr route: 남은 골드퀘 내비게이션, /qtr route clear: 경로안내 중지
        local arg = (msg:match("^%S+%s+(%S+)") or ""):lower()
        if arg == "clear" then
            QTR.RouteClear()
        else
            QTR.RouteStart()
            QTR.RoutePopupUpdate(true)
        end
    elseif cmd == "locale" then
        QTR.LocaleCheck()
    elseif cmd == "navlog" then
        -- /qtr navlog all: 내비게이션 기록을 지우지 않고 모두 남긴다 (개발 PC용, 2026-11-01 사용자 요청. 도움말에는 넣지 않는다)
        -- /qtr navlog 10: 최근 10번만 (기본. 넘는 기록은 다음 내비게이션 시작 때 지운다) / /qtr navlog: 지금 상태
        local arg = (msg:match("^%S+%s+(%S+)") or ""):lower()
        if arg == "all" then
            DB.settings.navLogAll = true
        elseif arg == "10" then
            DB.settings.navLogAll = nil
        end
        Print(L["내비게이션 기록 %d번 보관 중 (%s)"]:format(#(DB.navLog or {}),
            DB.settings.navLogAll and L["모두 남김"] or L["최근 10번만 남김"]))
    elseif cmd == "list" then
        for key, c in pairs(DB.chars) do
            Print(key .. " : " .. FormatGold(c.money))
        end
        Print(L["전투부대 은행 : "] .. FormatGold(DB.warbandMoney)
            .. (QTR.WarbandCounted() and "" or L[" (이 계정 보유량에 넣지 않음)"]))
    else
        Print(L["/qtr : 창 열기/닫기"])
        Print(L["/qtr gq : 골드퀘 탭 열기"])
        Print(L["/qtr rich : 부자되기 탭 열기"])
        Print(L["/qtr stats : 획득량 탭 열기"])
        Print(L["/qtr hold : 보유량 탭 열기"])
        Print(L["/qtr set : 설정창 열기/닫기"])
        Print(L["/qtr list : 캐릭터별 저장된 보유 골드 출력"])
        Print(L["/qtr ban (퀘스트 Shift+클릭) : 추적 제외 / /qtr unban : 제외 해제"])
        Print(L["/qtr route : 남은 골드퀘 내비게이션 / /qtr route clear : 경로안내 중지"])
        Print(L["/qtr hearth : 귀환석 상태 (귀환 지점, 쿨타임, 쓸 수 있는 충전 수)"])
        Print(L["/qtr pos [메모] : 지금 위치의 지도 ID와 좌표 저장 (/qtr pos list : 목록, /qtr pos clear : 지우기)"])
        Print(L["창 위에 마우스를 올리고 숫자키 1~4 : 탭 전환"])
        Print(L["골드퀘 탭 창 위에 마우스를 올리고 R : 내비게이션 시작"])
    end
end
