import sys, re, json
from lupa.lua51 import LuaRuntime
L=LuaRuntime(unpack_returned_tuples=True)
src=open(sys.argv[1],encoding='utf-8').read()
L.execute(src)
db=L.globals().QuestsToRichesDB
def tolist(t): return [t[i] for i in range(1,len(t)+1)]
runs=[]
for r in tolist(db.navLog):
    st=r.start
    run={'start':dict(t=st.t,c=st.c,x=st.x,y=st.y),'stops':[]}
    for s in tolist(r.stops):
        run['stops'].append(dict(q=s.q,portal=s.portal,t=s.t,c=s.c,x=s.x,y=s.y))
    # AFK intervals (2026-11-02): e is None while still AFK at the end of the run
    run['afk']=[dict(s=a.s,e=a.e) for a in tolist(r.afk)] if r.afk else []
    runs.append(run)
# quest names
names={}
for k,v in db.activeGQ.items(): names[k]=v.name
for k,v in db.cacheSources.items():
    if v.questID: names[v.questID]=v.title
json.dump({'runs':runs,'names':{str(k):v for k,v in names.items()}},open('runs.json','w'),ensure_ascii=False,indent=1)
print(len(runs),'runs', [len(r['stops']) for r in runs])
