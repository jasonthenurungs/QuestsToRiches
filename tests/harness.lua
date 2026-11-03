-- 최소 WoW API 흉내 (로직 검증용)
function GetTime() return 0 end
local out = {}
local function mkstub(name)
  local s = { _name = name, _text = nil, _shown = false }
  return setmetatable(s, { __index = function(t, k)
    if k == "Text" or k == "TitleText" then return nil end
    if k == "IsShown" then return function(self) return self._shown end end
    if k == "Show" then return function(self) self._shown = true end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "SetText" then return function(self, v) self._text = v end end
    if k == "SetPoint" then return function(self, p, rel, rp, x, y) if type(y) == "number" then rawset(self, "_x", x); rawset(self, "_y", y) end end end
    if k == "SetScript" then return function(self, n, fn) rawset(self, "_scr_" .. n, fn) end end
    if k == "GetFont" then return function() return "font", 12, "" end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
    if k == "GetChecked" then return function() return true end end
    if k == "CreateFontString" or k == "CreateTexture" then
      return function(self) local c = mkstub("fs"); table.insert(out, c); return c end
    end
    return function() return nil end
  end })
end
ALLFRAMES = {}
function CreateFrame(t, name, parent) local s = mkstub(name or t); rawset(s, "_pf", parent); if name then _G[name] = s end; table.insert(ALLFRAMES, s); return s end
SlashCmdList = {}
C_AreaPoiInfo = { GetAreaPOIForMap = function() return {} end, GetAreaPOIInfo = function() return nil end }
C_UIWidgetManager = { GetTextWithStateWidgetVisualizationInfo = function() return nil end }
function GetQuestLogRewardMoney() return 0 end
function GetLocale() return "koKR" end
UIParent = mkstub("UIParent"); UISpecialFrames = {}; tinsert = table.insert
GameFontHighlight = mkstub("gfh")
RAID_CLASS_COLORS = { WARRIOR = { colorStr = "ffc79c6e" }, SHAMAN = { colorStr = "ff0070dd" } }
function BreakUpLargeNumbers(n) local s = tostring(n); local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse(); return (r:gsub("^,", "")) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local NOW = os.time({year=2026, month=10, day=16, hour=21})
time = function(t) if t then return os.time(t) end return NOW end
date = os.date
C_DateAndTime = { GetSecondsUntilDailyReset = function() return 9*3600 end, GetSecondsUntilWeeklyReset = function() return 9*3600 + 6*86400 end }
C_QuestLog = { IsWorldQuest = function() return true end, GetTitleForQuestID = function(id) return "퀘" .. id end }
C_TaskQuest = { GetQuestZoneID = function() return 1 end, GetQuestsOnMap = function() return {} end }
C_Map = { GetMapInfo = function() return { name = "학살자의 오름길" } end, GetBestMapForUnit = function() return 1 end }
C_Timer = { After = function(_, fn) fn() end }
C_Bank = nil
MONEY = 2000000000
function GetMoney() return MONEY end
function UnitName() return CHARNAME end
function GetRealmName() return "데스윙" end
function UnitClass() return "전사", "WARRIOR" end
function UnitLevel() return UNITLEVEL or 90 end
function UnitIsAFK() return false end
function GetMaxLevelForPlayerExpansion() return 90 end
function InCombatLockdown() return false end
BINDS = {}
function GetBindingKey(cmd) return OLDBIND and OLDBIND[cmd] end
function ClearOverrideBindings() BINDS = {} end
function SetOverrideBinding(_, _, key, cmd) BINDS[key] = cmd end
local printed = {}
print = function(...) local t = {...}; for i=1,#t do t[i]=tostring(t[i]) end; table.insert(printed, table.concat(t, " ")) ; io.write(table.concat(t," "), "\n") end
-- LibStub 흉내
local addonObj = { RegisterEvent = function() end }
local ACD = { OpenFrames = {}, SetDefaultSize = function() end, AddToBlizOptions = function() end, Open = function() end, Close = function() end }
OPTIONS = nil
function LibStub(name)
  if name == "AceAddon-3.0" then return { NewAddon = function() return addonObj end } end
  if name == "AceConfig-3.0" then return { RegisterOptionsTable = function(_, _, o) OPTIONS = o end } end
  if name == "AceConfigDialog-3.0" then return ACD end
  return { NotifyChange = function() end }
end
return addonObj, out
