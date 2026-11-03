# 영어 클라이언트 (2026-10-31): GetLocale enUS, Locales 불러오기. 탭, 내비게이션 창, 설정창 문구, 명령어가 오류 없이 영어로 나오는지
#   화면 글자 중 한글이 남은 것을 모아 찍는다 (시험 데이터의 캐릭터, 퀘스트, 지역 이름은 한글이라 그것만 남아야 한다)
import os as _os, re
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness2.lua', encoding='utf-8').read())
lua.execute('''
CHARNAME = "봄이간다"
function GetLocale() return "enUS" end
LATER = {}
C_Timer = { After = function(sec, fn) table.insert(LATER, fn) end }
function RunLater() for k = 1, 3 do local l = LATER; LATER = {}; for _, fn in ipairs(l) do fn() end end end
Enum = { QuestTagType = { Capstone = 99 } }
C_Map = { GetMapInfo = function(id) return { name = "Silvermoon City" } end, GetBestMapForUnit = function() return 9999 end }
C_TaskQuest = { GetQuestsOnMap = function() return {} end, GetQuestInfoByQuestID = function() return nil end,
  GetQuestTimeLeftSeconds = function() return nil end, GetQuestZoneID = function() return 2405 end }
C_QuestLog.IsQuestFlaggedCompleted = function() return false end
C_QuestLog.GetQuestTagInfo = function() return {} end
C_QuestLog.GetTitleForQuestID = function(id) return "Quest Title " .. id end
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Junk" }, { leftText = "Sell Price" } } } end }
C_Container = { UseContainerItem = function() end, GetContainerNumSlots = function(b) return 0 end, GetContainerItemID = function() return nil end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return 5555 end,
           GetItemNameByID = function(id) return "Item " .. id end, RequestLoadItemDataByID = function() end }
function hooksecurefunc() end
C_EventUtils = { IsEventValid = function() return false end }
MerchantFrame = { IsShown = function() return false end }
function GetBindLocation() return "Wayfarer Inn" end
function GetQuestID() return 0 end
function GetTitleText() return "" end
function GetNumQuestRewards() return 0 end
function UnitGUID(u) return "Player-205-0ABCDEF1" end
''')
NS = lua.eval('{}')
for fn in ['Locales/enUS.lua', 'Locales/Locale.lua']:
    s = open(TD + '../src/QuestsToRiches/' + fn, encoding='utf-8').read()
    lua.eval('function(s) local f, e = load(s, "loc"); if not f then error(e) end; return f end')(s)("QuestsToRiches", NS)
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches", NS)
lua.eval(r'''function(QTR, out)
  local now = time()
  local G = 10000
  QuestsToRichesDB = {
    chars = {
      ["봄이간다-데스윙"] = { money = 100 * G, class = "WARRIOR", level = 90 },
      ["여름이간다-데스윙"] = { money = 900 * G, class = "WARRIOR", level = 90 },
    },
    days = {
      ["2026-10-15"] = { ["여름이간다-데스윙"] = { count = 1, money = 1000 * G, quests = { { id = 11, name = "Old Quest", zone = "Voidstorm", money = 1000 * G, t = now - 86400 } },
        caches = { { id = 279520, money = 4500 * G, t = now - 86000 } }, cacheCount = 1, cacheMoney = 4500 * G } },
    },
    holdDays = { ["2026-10-15"] = { chars = { ["여름이간다-데스윙"] = 800 * G }, warband = 10 * G } },
    snapshots = { ["2026-10-15"] = 810 * G },
    turnIns = {},
    activeGQ = {
      [11] = { name = "퀘스트 한국어 이름", zone = "공허폭풍", mapID = 2405, money = 10000000, expire = now + 86400, seen = now,
               seenBy = { ["여름이간다-데스윙"] = now } },
    },
    cacheSources = {
      q92145 = { kind = "quest", questID = 92145, title = "특별 과제: 무리와 맞서라", zone = "영원노래 숲", itemID = 279520, onMap = true, lastSeen = now, learned = now },
    },
    settings = { tab = "dash", pos = { "TOPLEFT", "BOTTOMLEFT", 300, 900 }, routePopPos = { 750, 900 }, chatNotify = true },
  }
  local TIP = {}
  GameTooltip = { SetOwner = function() end, SetText = function(self, t) table.insert(TIP, t) end,
    AddLine = function(self, t) table.insert(TIP, t) end, AddDoubleLine = function(self, a, b) table.insert(TIP, a .. " | " .. b) end,
    Show = function() end, Hide = function() end, SetItemByID = function() end }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()

  print("== 1) 탭")
  for _, cmd in ipairs({ "gq", "rich", "stats", "hold" }) do
    SlashCmdList.QUESTSTORICHES(cmd)
    QTR:Refresh()
  end
  print("== 2) 명령어")
  for _, cmd in ipairs({ "hearth", "ban", "help", "locale" }) do
    SlashCmdList.QUESTSTORICHES(cmd)
  end
  print("== 3) 내비게이션 대기 화면과 완료 추천")
  QTR.RoutePopupIdle()
  print("  " .. QTR.RecommendText())
  print("== 4) 정점 보관함 출처 이름 (한국어로 저장된 이름은 게임에서 읽은 이름으로)")
  local src = QuestsToRichesDB.cacheSources.q92145
  print("  " .. QTR.SourceLabel(src))
  print("  저장 이름 언어가 다름: " .. tostring(QTR.WrongLang(src.title)) .. ", 영어 이름: " .. tostring(QTR.WrongLang("Old Quest")))
  print("== 5) 설정창 문구 (함수는 불러서)")
  local texts = {}
  local function walk(node)
    for _, field in ipairs({ "name", "desc", "confirmText" }) do
      local v = node[field]
      if type(v) == "function" then
        local ok, r = pcall(v, {})
        v = ok and r or ("ERROR " .. tostring(r))
      end
      if type(v) == "string" then
        table.insert(texts, v)
      end
    end
    if type(node.args) == "table" then
      for _, child in pairs(node.args) do
        walk(child)
      end
    end
  end
  walk(OPTIONS)
  local errors = 0
  for _, t in ipairs(texts) do
    if t:find("ERROR") then
      errors = errors + 1
      print("  " .. t)
    end
  end
  print("  문구 " .. #texts .. "개, 오류 " .. errors .. "개")
  -- 한글이 남은 문구 (설정창)
  for _, t in ipairs(texts) do
    if t:find("[\234-\237][\128-\191][\128-\191]") then
      print("  한글: " .. t)
    end
  end
  print("== 6) 화면 글자 중 한글이 남은 것 (시험 데이터 이름 말고는 없어야 한다)")
  local seen = {}
  for _, fs in ipairs(out) do
    local t = rawget(fs, "_text")
    if type(t) == "string" and t:find("[\234-\237][\128-\191][\128-\191]") and not seen[t] then
      seen[t] = true
      print("  " .. t)
    end
  end
  for _, t in ipairs(TIP) do
    if type(t) == "string" and t:find("[\234-\237][\128-\191][\128-\191]") and not seen[t] then
      seen[t] = true
      print("  tip: " .. t)
    end
  end
end''')(addon, out)
