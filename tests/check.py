import os as _os
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
import sys
from lupa.lua51 import LuaRuntime
L=LuaRuntime(encoding=None)
f=L.eval('function(s) local f,e=loadstring(s); if f then return "OK" else return e end end')
b=open(TD + '../src/QuestsToRiches/QuestsToRiches.lua','rb').read()
r=f(b)
print(r.decode('utf-8','replace'))
if r==b'OK':
    for n in range(0,120):
        if f(b+b'\n'+b''.join(b'local zz%d = 1\n'%i for i in range(n)))!=b'OK':
            print('headroom', n-1); break
s=b.decode('utf-8')
# 언어 파일도 같은 규칙 (한글과 ASCII만, 2026-10-31)
for fn in ('Locales/enUS.lua', 'Locales/Locale.lua'):
    lb=open(TD + '../src/QuestsToRiches/' + fn,'rb').read()
    if f(lb)!=b'OK':
        print(fn, f(lb).decode('utf-8','replace'))
    s+=lb.decode('utf-8')
print('bad chars', sorted({c for c in s if ord(c)>127 and not ('가'<=c<='힣' or 'ㄱ'<=c<='ㆎ')}))
