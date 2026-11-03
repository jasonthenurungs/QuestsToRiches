import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
exec(open(TD + 'run25.py',encoding='utf-8').read().split('lua.eval("""function(QTR, out)\n  local labels')[0])
lua.eval("""function(out, QTR)
  local L = {}
  GameTooltip = { SetOwner = function() end, SetText = function(self, t) L = { "[제목] " .. tostring(t) } end,
    AddLine = function(self, t) table.insert(L, tostring(t)) end,
    AddDoubleLine = function(self, l, r) table.insert(L, tostring(l) .. " | " .. tostring(r)) end,
    Show = function() end, Hide = function() end, IsShown = function() return true end, SetItemByID = function() end }
  local function clean(s) return (s:gsub("|TInterface[^|]*|t", "(금화)"):gsub("|T%d+:0|t", "(아이콘)"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  for _, fr in ipairs(ALLFRAMES) do
    if fr._shown and rawget(fr, "tipQuest") and rawget(fr, "_scr_OnEnter") then
      rawget(fr, "_scr_OnEnter")(fr)
      print("== 퀘스트 줄 툴팁"); for _, l in ipairs(L) do print("  " .. clean(l)) end
      break
    end
  end
  for _, fr in ipairs(ALLFRAMES) do
    if fr._shown and rawget(fr, "tipPOI") and rawget(fr, "_scr_OnEnter") then
      rawget(fr, "_scr_OnEnter")(fr)
      print("== 잠긴 특별 과제 지역 줄 툴팁"); for _, l in ipairs(L) do print("  " .. clean(l)) end
      break
    end
  end
end""")(out, addon)
