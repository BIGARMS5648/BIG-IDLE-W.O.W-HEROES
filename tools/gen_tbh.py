# Builds BigIdleHeroes/Data/TBH.lua from the TBH datamine (taskbarhero.wiki/data).
import json, glob, os, re, sys
D = sys.argv[1]
OUT = sys.argv[2]
GRADES = ['COMMON','UNCOMMON','RARE','LEGENDARY','IMMORTAL','ARCANA','BEYOND','CELESTIAL','DIVINE','COSMIC']
GI = {g: i + 1 for i, g in enumerate(GRADES)}
DIFF = {'NORMAL': 1, 'NIGHTMARE': 2, 'HELL': 3, 'TORMENT': 4}
FAMILY = {'Helmet': 'armor', 'Sword': 'weapon', 'Shield': 'offhand', 'Amulet': 'neck', 'Ring': 'ring', 'Earing': 'trinket', 'Bracer': 'wrist'}
def matkind(item_id):
    p = item_id // 10000
    return {11: 'gem', 12: 'dust', 13: 'scroll', 14: 'craft', 16: 'seal', 19: 'soul'}.get(p)

stages = json.load(open(D + 'data_t_stages.json'))
levels = json.load(open(D + 'data_t_levels.json'))
mult = json.load(open(D + 'data_t_stage_levels.json'))
grades = json.load(open(D + 'data_grades.json'))
items = {r['id']: r for r in json.load(open(D + 'data_items.json'))}

def boxdata(key):
    b = json.load(open(D + 'boxes/%d.json' % key))
    out = []
    for e in b['table']['entries']:
        w = e['pcts']['base'] if e.get('pcts') else e['pct']
        if w <= 0: continue
        g = e.get('group')
        if g:
            name = g['name']
            m = re.search(r'Lv(\d+)', name)
            words = name.split(' ')
            if m:
                fam = FAMILY.get(' '.join(words[1:-1]))
                if not fam: raise SystemExit('unknown family ' + name)
                out.append(('gear', fam, GI[g['grade']], int(m.group(1)), w))
            else:
                # "<Grade> Material": its items say which kind
                kinds = {matkind(i) for i in g['items']}
                if len(kinds) != 1: raise SystemExit('mixed material group %s %s' % (name, kinds))
                out.append(('mat', kinds.pop(), GI[g['grade']], w))
        elif e.get('item'):
            iid = e['item']['id']
            k = matkind(iid)
            r = items.get(iid)
            grade = GI.get(r['grade'], 1) if r else 1
            if k in ('seal', 'soul'):
                # coins 160001.. and soulstones 190001..: by their number
                grade = iid % 1000
            if not k: raise SystemExit('unknown material %d in %d' % (iid, key))
            out.append(('mat', k, grade, w))
        else:
            raise SystemExit('entry without group or item in %d' % key)
    return out

L = []
L.append('-- TBH (Task Bar Hero) data, from the community datamine at taskbarhero.wiki')
L.append('-- (tools/gen_tbh.py): stage levels and boxes, box contents,')
L.append('-- experience, monster growth by stage level and the ten grades.')
L.append('-- Generated: do not edit by hand.')
L.append('local _, ns = ...')
L.append('local T = {}')
L.append('ns.TBH = T')
L.append('')
L.append('-- the item levels gear comes in (an item is worn from its own level)')
L.append('T.ITEM_LEVELS = { 1, 5, 10, 15, 20, 30, 40, 50, 65, 80, 100 }')
L.append('')
L.append('-- experience from level L to L + 1')
xp = {r['Level']: r['ExpForLevelUp'] for r in levels}
L.append('T.XP = { ' + ', '.join(str(xp[i]) for i in range(1, 101)) + ' }')
L.append('')
L.append('-- monsters at stage level L: attack, health, gold and experience, times')
L.append('-- those at level 1')
mm = {r['StageLevel']: r for r in mult}
rows = []
for lv in range(1, 101):
    r = mm[lv]
    rows.append('{ %g, %g, %g, %g }' % (r['MonsterAtkDmgMultiplier'] / 100, r['MonsterHpMultiplier'] / 100, r['MonsterGoldMultiplier'] / 100, r['MonsterExpMultiplier'] / 100))
L.append('T.MULT = {')
for i in range(0, 100, 5): L.append('\t' + ', '.join(rows[i:i + 5]) + ',')
L.append('}')
L.append('')
L.append('-- every stage (difficulty, then 1..30 = act and stage): level, its')
L.append('-- monsters (waves x per wave = kills), the monster box (key, per mille')
L.append('-- each kill) and the boss box (key, per mille; an act boss always drops)')
L.append('T.STAGES = { {}, {}, {}, {} }')
for s in sorted(stages, key=lambda r: (DIFF[r['STAGEDIFFICULITY']], r['Act'], r['StageNo'])):
    d = DIFF[s['STAGEDIFFICULITY']]
    idx = (s['Act'] - 1) * 10 + s['StageNo']
    waves = s['WaveAmount'] or 0
    per = s['WaveMonsterAmount'] or 0
    mb = s['MonsterDropItemKey']; mr = s['MonsterDropItemRate']
    bb = s['BossDropItemKey']; br = s['BossDropItemRate']
    act = s['STAGETYPE'] == 'ACTBOSS'
    L.append('T.STAGES[%d][%d] = { lv = %d, waves = %d, per = %d, mbox = %s, mrate = %s, bbox = %d, brate = %d%s }' % (
        d, idx, s['StageLevel'], waves, per, mb or 'nil', mr or 'nil', bb, br if br else 1000, ', act = true' if act else ''))
L.append('')
L.append('-- every box: what an opening rolls, by weight (percent):')
L.append('--   { "gear", family, grade, item level, weight }  family: armor (head,')
L.append('--     chest, hands or feet), weapon, offhand, neck, ring, trinket, wrist')
L.append('--   { "mat", kind, grade, weight }  kind: gem (장식), dust (세공),')
L.append('--     scroll (각인), craft, seal (coins), soul (soulstones; grade = number)')
# only the boxes the stages drop
used = set()
for s in stages:
    for k in (s['MonsterDropItemKey'], s['BossDropItemKey']):
        if k: used.add(k)
keys = sorted(k for k in (int(os.path.basename(p)[:-5]) for p in glob.glob(D + 'boxes/*.json')) if k in used)
missing = used - set(keys)
if missing: raise SystemExit('boxes not downloaded: %s' % sorted(missing))
L.append('T.BOXES = {')
for k in keys:
    ent = boxdata(k)
    if not ent: continue
    lv = max((e[3] for e in ent if e[0] == 'gear'), default=0)
    kind = 'monster' if k // 10000 == 91 else ('boss' if k // 10000 == 92 else 'act')
    parts = []
    for e in ent:
        if e[0] == 'gear': parts.append('{ "gear", "%s", %d, %d, %.4g }' % (e[1], e[2], e[3], e[4]))
        else: parts.append('{ "mat", "%s", %d, %.4g }' % (e[1], e[2], e[3]))
    L.append('\t[%d] = { kind = "%s", lv = %d, e = {' % (k, kind, lv))
    for i in range(0, len(parts), 4): L.append('\t\t' + ', '.join(parts[i:i + 4]) + ',')
    L.append('\t} },')
L.append('}')
L.append('')
L.append('-- the ten grades: random stats, sockets (장식, 세공, 각인), what breaking')
L.append('-- one down gives (gold, forge experience) and fusion (9 of a grade): the')
L.append('-- weights of two grades lower .. two grades higher')
L.append('T.GRADES = {')
for r in grades:
    L.append('\t{ key = "%s", affix = %d, gem = %d, ench = %d, insc = %d, gold = %d, cube = %d, fuse = { %d, %d, %d, %d, %d } },' % (
        r['GRADE'].lower(), r['InherentSlotAmount'], r['ExtraSlotAmount_Decoration'], r['ExtraSlotAmount_Engraving'], r['ExtraSlotAmount_Inscription'],
        r['BaseAlchemyGold'], r['BaseCubeExp'], r['Lower2GradeWeight'], r['Lower1GradeWeight'], r['SameGradeWeight'], r['Higher1GradeWeight'], r['Higher2GradeWeight']))
L.append('}')
open(OUT, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
print('wrote', OUT, len(L), 'lines')
