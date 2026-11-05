# 내비게이션 중 전쟁 모드 변경 (2026-11-05 사용자 결정, 인벤 나이샤님 질문): 전쟁 모드에서 보상이 골드가 아니게 되는 퀘스트가 있다
#   전쟁 모드가 바뀌면 1초 뒤 남은 경로를 다시 짠다. 골드가 아니게 된 퀘스트는 notGoldFor라 기다리지 않고 바로 빠진다.
#   다시 끄면 골드로 돌아온 퀘스트가 바로 들어간다. 다른 플래그 변화(자리비움 등), 내비게이션이 없을 때는 다시 짜지 않는다
#   (준비 부분은 run70과 같다)
import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
addon, out = lua.execute(open(TD + 'harness2.lua', encoding='utf-8').read())
setup = open(TD + 'run70.py', encoding='utf-8-sig').read()
lua.execute(setup.split("lua.execute('''")[1].split("''')")[0])
src = open(TD + '../src/QuestsToRiches/QuestsToRiches.lua', encoding='utf-8').read()
chunk = lua.eval('function(s) local f, e = load(s, "QTR"); if not f then error(e) end; return f end')(src)
chunk("QuestsToRiches")
prep = setup.split("lua.eval(r'''function(QTR, out)")[1].split("  local DB = QuestsToRichesDB\n  DB.hearthBinds")[0]
lua.eval("function(QTR, out)\n" + prep + r'''
  local DB = QuestsToRichesDB
  DB.hearthBinds = { ["실버문"] = { c = 0, x = 8519.4, y = -4324.6, t = 1 } }
  WAR = false
  C_PvP = { IsWarModeDesired = function() return WAR end, GetWarModeRewardBonus = function() return 10 end }
  C_QuestLog.QuestCanHaveWarModeBonus = function() return true end
  Q[71] = { map = 2437, title = "Z1 줄아만", money = 10000000, t = 86400, x = 0.50, y = 0.45 }
  Q[72] = { map = 2437, title = "Z2 줄아만", money = 10000000, t = 86400, x = 0.55, y = 0.50 }
  Q[73] = { map = 2437, title = "Z3 줄아만", money = 10000000, t = 86400, x = 0.60, y = 0.55 }
  local function clean(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local function show(title)
    local labels = {}
    for _, r in ipairs(QTR.route or {}) do table.insert(labels, clean(r.label)) end
    print("==T " .. title)
    print("  route: " .. table.concat(labels, " / "))
  end
  QTR:PLAYER_ENTERING_WORLD(); LATER = {}
  PMAP, PX, PY = 2413, 0.95, 0.95
  QTR.forceScan = true
  QTR.RouteStart()
  show("1) 전쟁 모드 끔으로 시작 -> 3곳")
  LATER = {}
  QTR:PLAYER_FLAGS_CHANGED(nil, "player")
  RunLater()
  show("2) 다른 플래그 변화(전쟁 모드 그대로) -> 다시 짜지 않음")
  WAR = true
  Q[72].money = 0 -- 전쟁 모드에서는 보상이 골드가 아님
  QTR:PLAYER_FLAGS_CHANGED(nil, "target")
  show("3) 다른 유닛 이벤트 -> 무시")
  LATER = {}
  QTR:PLAYER_FLAGS_CHANGED(nil, "player")
  RunLater()
  show("4) 전쟁 모드 켬 -> Z2 바로 빠짐 (기다리지 않음)")
  print("  notGoldFor Z2: " .. tostring(DB.activeGQ[72] and DB.activeGQ[72].notGoldFor and DB.activeGQ[72].notGoldFor["봄이간다-데스윙"]) .. " / retry " .. tostring(QTR.routeRetry))
  WAR = false
  Q[72].money = 10000000
  LATER = {}
  QTR:PLAYER_FLAGS_CHANGED(nil, "player")
  RunLater()
  show("5) 전쟁 모드 끔 -> Z2 다시 들어감")
  print("  notGoldFor Z2: " .. tostring(DB.activeGQ[72] and DB.activeGQ[72].notGoldFor and DB.activeGQ[72].notGoldFor["봄이간다-데스윙"]))
  QTR.RouteClear()
  WAR = true
  LATER = {}
  QTR:PLAYER_FLAGS_CHANGED(nil, "player")
  RunLater()
  show("6) 내비게이션 없을 때 전쟁 모드 변경 -> 경로 만들지 않음")
  print("==T end")
end''')(addon, out)
