# 내비게이션 기록의 자리비움 구간 (2026-11-02 사용자 요청): PLAYER_FLAGS_CHANGED 때 UnitIsAFK를 보고 run.afk에 { s, e }
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
exec(open(TD + 'run72.py', encoding='utf-8-sig').read().split("lua.eval(r'''function(QTR, out)")[0])
lua.eval(r'''function(QTR, out)
  QuestsToRichesDB = {
    chars = { ["봄이간다-데스윙"] = { money = 1, class = "WARRIOR", level = 90 } },
    days = {}, turnIns = {}, settings = { tab = "dash" },
  }
  QTR:OnInitialize(); QTR:OnEnable(); QTR:PLAYER_ENTERING_WORLD(); RunLater()
  local DB = QuestsToRichesDB
  AFK = false
  UnitIsAFK = function(unit) return unit == "player" and AFK end
  local T0 = time()
  local function show(title)
    local run = DB.navLog and DB.navLog[#DB.navLog]
    local parts = {}
    for _, a in ipairs(run and run.afk or {}) do table.insert(parts, (a.s - T0) .. "~" .. (a.e and (a.e - T0) or "")) end
    print(title .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "(none)"))
  end
  local function flags(unit) QTR:PLAYER_FLAGS_CHANGED("PLAYER_FLAGS_CHANGED", unit or "player") end
  print("== 1) 내비게이션 없을 때 자리비움 -> 기록 없음, 오류 없음")
  AFK = true; flags(); AFK = false; flags()
  print("  navLog " .. #(DB.navLog or {}))
  QTR.NavLogStart()
  show("== 2) 시작 직후")
  print("== 3) 다른 유닛, 자리비움 아닌 플래그 변화(전쟁 모드 등) -> 그대로")
  AFK = true; flags("party1"); AFK = false; flags()
  show("  ")
  print("== 4) 켬(+100) 켬 다시(+150, 중복 아님) 끔(+400)")
  local base = T0
  NOW_OFFSET = 0
  local realtime = time
  time = function(t) if t then return realtime(t) end return base + NOW_OFFSET end
  NOW_OFFSET = 100; AFK = true; flags()
  NOW_OFFSET = 150; flags()
  NOW_OFFSET = 400; AFK = false; flags()
  show("  ")
  print("== 5) 두 번째 켬(+900), 끄지 않고 끝 -> e 없음")
  NOW_OFFSET = 900; AFK = true; flags()
  show("  ")
  print("== 6) 경로안내 중지 뒤 -> 새 기록 없음")
  AFK = false
  QTR.RouteClear()
  NOW_OFFSET = 1000; flags()
  show("  ")
  time = realtime
  print("== end")
end''')(addon, out)
