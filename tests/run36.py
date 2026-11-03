import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
exec(open(TD + 'run35.py',encoding='utf-8').read().split('lua.eval("""function(out, QTR)\n  local L = {}')[0])
lua.eval("""function(out, QTR)
  local L = {}
  GameTooltip = { SetOwner = function() end, SetText = function(self, t) L = { "[제목] " .. tostring(t) } end,
    AddLine = function(self, t) table.insert(L, tostring(t)) end,
    AddDoubleLine = function(self, l, r) table.insert(L, tostring(l) .. " | " .. tostring(r)) end,
    Show = function() end, Hide = function() end, IsShown = function() return true end, SetItemByID = function() end }
  local function clean(s) return (s:gsub("|TInterface[^|]*|t", "(금화)"):gsub("|T%d+:0|t", "(아이콘)"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  function HaveQuestData() return true end
  C_QuestLog.GetQuestObjectives = function(id)
    return { { text = "1/1 하라니르 꽃잎날개 타기", type = "event", finished = true },
             { text = "빛만개 루타니 처치", type = "progressbar", finished = false } }
  end
  function GetQuestProgressBarPercent() return 37.6 end
  C_QuestLog.GetQuestRewardCurrencies = function(id)
    return { { name = "공허불빛 이회토", texture = 7001, totalRewardAmount = 45 }, { name = "모험가 안개문장", texture = 7002, totalRewardAmount = 5 } }
  end
  local function hover()
    for _, fr in ipairs(ALLFRAMES) do
      if fr._shown and rawget(fr, "tipQuest") and rawget(fr, "tipQuest") and rawget(fr, "_scr_OnEnter") then
        rawget(fr, "_scr_OnEnter")(fr); return
      end
    end
  end
  hover()
  print("== 퀘스트 줄 툴팁"); for _, l in ipairs(L) do print("  " .. clean(l)) end
  -- 보상 정보 미수신
  local orig = HaveQuestRewardData
  HaveQuestRewardData = function() return false end
  C_QuestLog.GetQuestRewardCurrencies = function() return {} end
  local origN = GetNumQuestLogRewards
  GetNumQuestLogRewards = function() return 0 end
  local origM = GetQuestLogRewardMoney
  GetQuestLogRewardMoney = function() return 0 end
  hover()
  print("== 보상 정보 미수신"); for _, l in ipairs(L) do print("  " .. clean(l)) end
  HaveQuestRewardData, GetNumQuestLogRewards, GetQuestLogRewardMoney = orig, origN, origM
  -- 목표 함수가 오류를 내도 툴팁은 나온다
  C_QuestLog.GetQuestObjectives = function() error("secret") end
  hover()
  print("== 목표 읽기 실패 시"); for _, l in ipairs(L) do print("  " .. clean(l)) end
end""")(out, addon)
