import json, math
d=json.load(open('runs.json'))
names=d['names']
# portal departure world coords (from posLog measurements), index = PORTALS order
DEP={1:(0,8534.7,-4326.5),2:(2771,890.0,-441.2),3:(0,8498.9,-4371.8),4:(2694,-270.0,-460.6),
     5:(2771,883.3,-456.1),6:(2694,-285.2,-433.9),7:(0,8553.3,-4900.9),8:(0,5950.7,-12070.1)}
legs=[]
def afk_overlap(r,t0,t1):
    # seconds of the leg [t0,t1] spent AFK (2026-11-02). Auto-AFK only starts after some idle minutes,
    # so any overlap marks the whole leg as unusable rather than subtracting
    n=0
    for a in r.get('afk',[]):
        e=a['e'] if a['e'] is not None else float('inf')
        n+=max(0,min(t1,e)-max(t0,a['s']))
    return n
for ri,r in enumerate(d['runs']):
    prev=dict(r['start']); prev['kind']='start'
    for s in r['stops']:
        dt=s['t']-prev['t']
        afk=afk_overlap(r,prev['t'],s['t'])
        if isinstance(s.get('portal'),str):
            # recall-type travel (hearth, mage, astral, arcantina, maisara; 2026-11-01): cast anywhere,
            # so dt is the whole cost (cast + loading + any delay). kind stays 'hearth', portal holds the key
            legs.append(dict(run=ri+1,kind='hearth',frm=prev['kind'],dist=None,dt=dt,portal=s['portal'],afk=afk))
            prev=dict(s); prev['kind']='hearth'
        elif s.get('portal'):
            c,px,py=DEP[s['portal']]
            dist=math.hypot(prev['x']-px,prev['y']-py) if prev['c']==c else None
            legs.append(dict(run=ri+1,kind='to_portal',frm=prev['kind'],dist=dist,dt=dt,portal=s['portal'],afk=afk))
            prev=dict(s); prev['kind']='portal'
        else:
            dist=math.hypot(prev['x']-s['x'],prev['y']-s['y']) if prev['c']==s['c'] else None
            legs.append(dict(run=ri+1,kind='to_quest',frm=prev['kind'],dist=dist,dt=dt,q=names.get(str(s['q']),s['q']),afk=afk))
            prev=dict(s); prev['kind']='quest'
for l in legs:
    print(l['run'], l['kind'].ljust(9), ('from '+l['frm']).ljust(12), ('%7.0f yd'%l['dist']) if l['dist'] is not None else '   ?    ', '%5d s'%l['dt'], l.get('q',''), l.get('portal',''), ('AFK %ds'%l['afk']) if l['afk'] else '')
json.dump(legs,open('legs.json','w'),ensure_ascii=False)
