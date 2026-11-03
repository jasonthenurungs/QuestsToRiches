local _, ns = ...

-- 언어 고르기 (2026-10-31 영어 클라이언트 지원, HDT의 Locales 구조를 따른다)
-- 이 파일은 언어 파일(enUS.lua)을 모두 불러온 뒤, QuestsToRiches.lua보다 먼저 불러야 한다 (TOC 순서)
--   화면 문구 ns.L: 한국어 클라이언트는 코드의 한국어 원문 그대로, 그 밖의 클라이언트는 영어(enUS)
--     번역이 없거나 비어 있으면 한국어 원문을 보여 준다. 원문 뒤의 "##..." 꼬리표는 떼고 보여 준다
--   게임 글자 ns.GameText(키): 클라이언트 언어 값만 돌려준다. 없으면 nil (부르는 곳이 한국어 값을 쓴다)
--     게임 글자는 클라이언트 언어로만 나오므로 다른 언어 값으로 대신하지 않는다
ns.Locales = ns.Locales or {}

local client = GetLocale()
if client == "enGB" then
    client = "enUS"
end

local display = (client == "koKR") and "koKR" or "enUS"
local ui = (display ~= "koKR" and ns.Locales[display] and ns.Locales[display].UI) or {}

ns.L = setmetatable({}, {
    __index = function(_, key)
        local value = ui[key]
        if type(value) == "string" and value ~= "" then
            return value
        end
        return (key:gsub("##.*$", ""))
    end,
})

local game = (ns.Locales[client] and ns.Locales[client].Game) or {}

function ns.GameText(key)
    local value = game[key]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end
