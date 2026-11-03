# 화면 문구 번역 확인 (2026-10-31): QuestsToRiches.lua의 L["한국어 원문"]과 Locales\enUS.lua의 UI 키를 맞춰 본다
#   1) 코드에 있는데 번역이 없는 키  2) 번역에만 있고 코드에서 안 쓰는 키
#   3) %d, %s 같은 서식 문자의 순서와 개수가 원문과 다른 번역 (Lua string.format은 순서를 바꿀 수 없다)
#   4) |c 색 코드와 |r 개수가 원문과 다른 번역
#   5) 번역(영어)에 ASCII가 아닌 글자
# 모두 맞으면 "locale OK"
import os as _os, re
TD = _os.path.dirname(_os.path.abspath(__file__)) + '/'
SRC = TD + '../src/QuestsToRiches/QuestsToRiches.lua'
ENUS = TD + '../src/QuestsToRiches/Locales/enUS.lua'
LIT = r'"((?:[^"\\]|\\.)*)"'


def code_part(l):
    # 문자열 밖의 -- 부터는 주석
    i, n, q = 0, len(l), None
    while i < n:
        c = l[i]
        if q:
            if c == '\\':
                i += 2
                continue
            if c == q:
                q = None
        else:
            if c in '"\'':
                q = c
            elif l.startswith('--', i):
                return l[:i]
        i += 1
    return l


used = []
for l in open(SRC, encoding='utf-8').read().split('\n'):
    for m in re.finditer(r'L\[' + LIT + r'\]', code_part(l)):
        if m.group(1) not in used:
            used.append(m.group(1))

trans = {}
in_ui = False
for l in open(ENUS, encoding='utf-8').read().split('\n'):
    s = l.strip()
    if s.startswith('UI = {'):
        in_ui = True
        continue
    if in_ui:
        m = re.match(r'\[' + LIT + r'\]\s*=\s*' + LIT + r',\s*$', s)
        if m:
            trans[m.group(1)] = m.group(2)

problems = []
for k in used:
    if k not in trans:
        problems.append('missing: ' + k)
for k in trans:
    if k not in used:
        problems.append('unused: ' + k)
fmt = re.compile(r'%[-0-9.]*[a-zA-Z%]')
for k, v in trans.items():
    if fmt.findall(k) != fmt.findall(v):
        problems.append('format: ' + k + ' | ' + v)
    if len(re.findall(r'\|c', k)) != len(re.findall(r'\|c', v)) or k.count('|r') != v.count('|r'):
        problems.append('color: ' + k + ' | ' + v)
    if any(ord(c) > 127 for c in v):
        problems.append('non-ascii: ' + v)
print('keys used', len(used), 'translated', len(trans))
for p in problems:
    print(p)
print('locale OK' if not problems else 'locale PROBLEMS %d' % len(problems))
