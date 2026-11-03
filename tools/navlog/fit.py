import json, numpy as np
alllegs=json.load(open('legs.json'))
# legs that touch an AFK interval are left out (2026-11-02, old logs have no afk field)
afkn=sum(1 for l in alllegs if l.get('afk'))
alllegs=[l for l in alllegs if not l.get('afk')]
print('AFK legs excluded:',afkn)
# recall-type travel by key (addon costs: hearth 20, mage 20, astral 20, arcantina 30, maisara 20 s)
for key in sorted({l['portal'] for l in alllegs if l['kind']=='hearth'}):
    hs_dt=[l['dt'] for l in alllegs if l['kind']=='hearth' and l['portal']==key]
    print("%s: %d uses, mean %.0f s"%(key,len(hs_dt),np.mean(hs_dt)))
legs=[l for l in alllegs if l['dist'] is not None]
quests=sorted({l['q'] for l in legs if l['kind']=='to_quest'})
cols=['inv_v','portal']+quests
A=[];b=[]
for l in legs:
    row=[0]*len(cols); row[0]=l['dist']
    if l['kind']=='to_portal': row[1]=1
    else: row[cols.index(l['q'])]=1
    A.append(row); b.append(l['dt'])
A=np.array(A,float); b=np.array(b,float)
from scipy.optimize import lsq_linear
res=lsq_linear(A,b,bounds=(0,np.inf))
x=res.x
print("speed %.1f yd/s (1/v=%.4f)"%(1/x[0],x[0]))
print("portal overhead (from leaving last stop to standing at arrival, minus flight) %.0f s"%x[1])
pred=A@x
for q in quests: print("  %-22s handle %4.0f s"%(q, x[cols.index(q)]))
hs=[x[cols.index(q)] for q in quests]
print("median handle %.0f s, mean %.0f s"%(np.median(hs),np.mean(hs)))
err=b-pred
print("residual: mean abs %.0f s, max %.0f s"%(np.mean(abs(err)),max(abs(err))))
# simple 2-param model: one handle for all quests
A2=np.array([[l['dist'], 1 if l['kind']=='to_quest' else 0, 1 if l['kind']=='to_portal' else 0] for l in legs],float)
r2=lsq_linear(A2,b,bounds=(0,np.inf)).x
p2=A2@r2
print("2-param: speed %.1f yd/s, handle %.0f s, portal %.0f s, mean abs err %.0f s"%(1/r2[0],r2[1],r2[2],np.mean(abs(b-p2))))
# current defaults 40 yd/s, 120 s, portal ~ 300yd-equivalent at 40 => 7.5s
p0=np.array([l['dist']/40+(120 if l['kind']=='to_quest' else 7.5) for l in legs])
print("current defaults (40yd/s,120s): mean abs err %.0f s, mean bias %.0f s"%(np.mean(abs(b-p0)),np.mean(p0-b)))
