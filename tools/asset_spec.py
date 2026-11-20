"""Every piece of art the add-on can use, in one place.

This file is the single source of truth for
  * the prompt document the artist uses with an image model (tools/make_prompts.py
    writes docs/ASSET_PROMPTS.md from it), and
  * the importer that turns the artist's PNG files into game textures and the
    Lua manifest the add-on reads (tools/import_art.py).

Nothing here is drawn by code: the add-on falls back to its built-in look for
any asset that has not been supplied yet.

Terms
  asset   one game texture (a character's packed sprite sheet, one UI frame, ...)
  sheet   one image the artist makes; an asset is built from one or more sheets
  rows    the animation rows inside a sheet: (animation name, frame count)
"""

# ---------------------------------------------------------------------------
# Shared prompt text
# ---------------------------------------------------------------------------
STYLE = (
    "하이 판타지 MMORPG 분위기의 모바일 게임 그림체. SD 비율(머리가 큰 2.5등신), "
    "또렷하고 두꺼운 어두운 외곽선, 손으로 칠한 듯한 따뜻한 질감(hand-painted), 과장된 어깨 갑옷과 큰 무기, "
    "채도가 높은 선명한 색, 위쪽에서 오는 부드러운 빛."
)
CLEAN = (
    "글자, 숫자, 서명, 워터마크, 테두리, 격자선, 바닥 그림자, 배경 소품은 넣지 마세요."
)
BG_TRANSPARENT = (
    "배경은 완전히 투명하게(투명 PNG). 투명 배경이 안 되면 배경 전체를 단색 마젠타(#FF00FF)로 칠하고, "
    "그림 안에는 마젠타 색을 쓰지 마세요."
)
SHEET_RULES = (
    "모든 프레임은 같은 캐릭터, 같은 크기, 같은 발 높이로 그리고, 프레임끼리 겹치지 않게 넉넉한 간격을 두세요. "
    "각 줄은 왼쪽에서 오른쪽 순서로 동작이 이어집니다."
)

FACING = {
    "right": "캐릭터는 오른쪽을 바라보는 측면(살짝 비스듬한 3/4 측면) 모습입니다.",
    "left": "캐릭터는 왼쪽을 바라보는 측면(살짝 비스듬한 3/4 측면) 모습입니다.",
}

# Animations: name -> (Korean label, how to draw it)
ANIM = {
    "idle": ("대기", "제자리에서 숨 쉬듯 몸이 살짝 오르내리는 전투 대기 자세"),
    "walk": ("걷기", "한 걸음 주기(왼발-오른발)로 앞으로 걷는 동작"),
    "attack": ("공격", "기본 공격 한 번(무기를 뒤로 젖혔다가 앞으로 휘두르거나 쏘는 동작)"),
    "cast": ("기술", "기술을 쓰는 동작(무기나 손을 높이 들고 힘을 모았다가 앞으로 내뻗음, 손이나 무기에 빛이 남)"),
    "hit": ("피격", "공격을 맞고 몸이 뒤로 움찔하는 동작"),
    "death": ("사망", "쓰러지는 동작(무릎을 꿇고 옆으로 쓰러져 바닥에 눕는 것까지, 마지막 프레임은 누운 자세)"),
}

HERO_ROWS_A = [("idle", 4), ("walk", 6)]
HERO_ROWS_B = [("attack", 4), ("cast", 4), ("hit", 2), ("death", 4)]
MOB_ROWS = [("idle", 4), ("walk", 4), ("attack", 4), ("hit", 2), ("death", 4)]
SUMMON_ROWS = [("idle", 4), ("attack", 4)]
CRITTER_ROWS = [("idle", 4), ("walk", 4)]

# Output cell sizes (pixels per frame in the packed game texture)
CELL_UNIT = 170   # square cells (6 x 6 fit a 1024 x 1024 texture)
# Characters get wide cells so a big weapon swung forward does not force the
# whole character to be drawn smaller: 4 columns x 6 rows of 256 x 170 fit
# 1024 x 1024 (24 frames: idle 4, walk 6, attack 4, cast 4, hit 2, death 4).
CELL_WIDE = (256, 170)
WIDE_COLS = 4
CELL_SMALL = 128

# ---------------------------------------------------------------------------
# Factions, races, classes
# ---------------------------------------------------------------------------
FACTIONS = {
    "alliance": ("얼라이언스", "파란색과 금색이 들어간 장식(얼라이언스 쪽 색)"),
    "horde": ("호드", "붉은색과 검은색, 거친 가죽과 뼈 장식(호드 쪽 색)"),
}

RACE = {
    # id: (Korean name, male look, female look, size note)
    "human": ("인간", "건장한 인간 남성, 짧은 갈색 머리", "인간 여성, 묶은 금발", "보통 키"),
    "dwarf": ("드워프", "키가 작고 다부진 드워프 남성, 땋은 덥수룩한 붉은 수염", "키가 작고 다부진 드워프 여성, 양 갈래로 땋은 머리", "작고 넓적한 체형"),
    "nightelf": ("나이트 엘프", "연보라색 피부에 길고 뾰족한 귀, 눈동자 없이 은빛으로 빛나는 눈, 청록색 긴 머리의 엘프 남성",
                 "연보라색 피부에 길고 뾰족한 귀, 은빛으로 빛나는 눈, 남색 긴 머리의 엘프 여성", "늘씬하고 큰 키"),
    "gnome": ("노움", "아주 작은 키에 머리가 크고 눈이 큰 노움 남성, 삐죽삐죽한 분홍색 머리와 콧수염", "아주 작은 키에 머리가 크고 눈이 큰 노움 여성, 양 갈래로 묶은 보라색 머리", "가장 작은 체형"),
    "draenei": ("드레나이", "푸른 피부, 이마의 뿔, 얼굴 아래로 늘어진 촉수 수염, 발굽 달린 다리와 꼬리를 가진 드레나이 남성",
                "옅은 푸른 피부, 작은 뿔, 발굽 달린 다리와 꼬리를 가진 드레나이 여성", "큰 키"),
    "worgen": ("늑대인간", "두 발로 선 늑대 머리의 늑대인간 남성, 회갈색 털, 날카로운 이빨", "두 발로 선 늑대 머리의 늑대인간 여성, 갈색 털과 긴 갈기", "구부정하지만 큰 체형"),
    "orc": ("오크", "녹색 피부, 아래턱에서 솟은 엄니, 근육질의 오크 남성, 검은 머리를 묶음", "녹색 피부, 작은 엄니, 탄탄한 체형의 오크 여성, 높게 묶은 검은 머리", "넓고 큰 체형"),
    "undead": ("언데드", "창백한 회녹색 피부, 군데군데 뼈가 드러난 마른 언데드 남성, 노랗게 빛나는 눈", "창백한 회녹색 피부, 뼈가 살짝 드러난 마른 언데드 여성, 노랗게 빛나는 눈, 헝클어진 머리", "마른 체형"),
    "tauren": ("타우렌", "황소 머리와 큰 뿔, 털로 덮인 거대한 몸, 발굽, 코뚜레를 한 타우렌 남성", "암소 머리와 작은 뿔, 털로 덮인 큰 몸, 땋은 머리의 타우렌 여성", "가장 크고 육중한 체형"),
    "troll": ("트롤", "푸른 피부, 긴 엄니와 긴 귀, 붉은 모히칸 머리를 한 길쭉한 트롤 남성", "푸른 피부, 작은 엄니와 긴 귀, 긴 붉은 머리를 한 날씬한 트롤 여성", "길쭉하고 구부정한 체형"),
    "bloodelf": ("블러드 엘프", "흰 피부, 길고 뾰족한 귀, 초록빛으로 빛나는 눈, 금발의 우아한 엘프 남성", "흰 피부, 길고 뾰족한 귀, 초록빛으로 빛나는 눈, 긴 붉은 머리의 우아한 엘프 여성", "늘씬한 체형"),
    "goblin": ("고블린", "초록 피부, 아주 큰 귀, 긴 매부리코, 뾰족한 이빨의 작은 고블린 남성", "초록 피부, 큰 귀, 큰 눈의 작은 고블린 여성, 묶은 검은 머리", "작은 체형"),
}

# class id -> (Korean name, outfit and weapon, what its attack and skill look like)
CLASS = {
    "warrior": ("전사", "두꺼운 판금 갑옷, 거대한 어깨 갑옷, 양손으로 드는 큰 도끼",
                "공격: 도끼를 크게 내려찍음 / 기술: 도끼를 치켜들고 붉은 기운을 뿜으며 함성"),
    "paladin": ("성기사", "금빛 장식의 판금 갑옷, 흰 망토, 양손 전쟁 망치",
                "공격: 망치를 내려침 / 기술: 망치를 높이 들어 황금빛 성스러운 빛을 모음"),
    "hunter": ("사냥꾼", "가죽과 사슬 갑옷, 깃털 달린 망토, 큰 활과 등 뒤의 화살통",
               "공격: 활시위를 당겨 화살 발사 / 기술: 빛나는 화살 여러 발을 겨눔"),
    "rogue": ("도적", "어두운 가죽 갑옷, 두건과 얼굴 가리개, 양손에 단검",
              "공격: 단검 두 자루로 빠르게 찌름 / 기술: 몸을 숙였다가 회전하며 연속 베기, 초록 독 기운"),
    "priest": ("사제", "흰색과 금색의 긴 로브, 머리 장식, 끝에 빛나는 보석이 달린 지팡이",
               "공격: 지팡이 끝에서 빛 덩어리를 쏨 / 기술: 두 손을 들어 머리 위로 성스러운 빛(또는 보랏빛 암흑 기운)을 모음"),
    "shaman": ("주술사", "사슬 갑옷과 털가죽, 토템 장식, 한손 둔기와 작은 방패",
               "공격: 둔기로 내려침 / 기술: 손에서 파란 번개를 뿜음"),
    "mage": ("마법사", "높은 깃의 화려한 마법사 로브, 끝에 수정이 달린 긴 지팡이, 마법서",
             "공격: 지팡이로 작은 마법탄 발사 / 기술: 두 손 사이에 불덩이(또는 얼음 덩이)를 크게 모아 던짐"),
    "warlock": ("흑마법사", "해골과 뿔 장식이 달린 어두운 보라색 로브, 녹색 불꽃이 타는 지팡이",
                "공격: 손에서 어둠의 화살 발사 / 기술: 녹색 지옥불을 두 손에 모아 내던짐"),
    "druid": ("드루이드", "나뭇잎과 가죽으로 만든 옷, 사슴뿔 장식, 나무 지팡이",
              "공격: 지팡이로 자연의 빛 구슬을 쏨 / 기술: 지팡이를 들어 초록 잎사귀 소용돌이를 일으킴"),
    "tinker": ("땜장이", "커다란 고글, 작업복 위 가죽 앞치마, 공구가 잔뜩 달린 벨트, 김이 나는 기계 배낭, 큰 렌치와 소총",
               "공격: 소총을 쏨(총구 불꽃) / 기술: 렌치를 휘둘러 작은 기계 장치를 던지거나 설치함"),
}

# class -> race per faction (matches Data/Races.lua)
CLASS_RACE = {
    "warrior": {"alliance": "dwarf", "horde": "orc"},
    "paladin": {"alliance": "human", "horde": "bloodelf"},
    "hunter": {"alliance": "nightelf", "horde": "troll"},
    "rogue": {"alliance": "worgen", "horde": "undead"},
    "priest": {"alliance": "draenei", "horde": "undead"},
    "shaman": {"alliance": "draenei", "horde": "tauren"},
    "mage": {"alliance": "human", "horde": "bloodelf"},
    "warlock": {"alliance": "human", "horde": "orc"},
    "druid": {"alliance": "nightelf", "horde": "tauren"},
    "tinker": {"alliance": "gnome", "horde": "goblin"},
}
CLASS_ORDER = ["warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid", "tinker"]

# ---------------------------------------------------------------------------
# Asset list
# ---------------------------------------------------------------------------
ASSETS = []


def asset(id, group, priority, title, kind, sheets, **kw):
    a = dict(id=id, group=group, priority=priority, title=title, kind=kind, sheets=sheets)
    a.update(kw)
    ASSETS.append(a)
    return a


def sheet(name, prompt, canvas="1536x1024", rows=None, note=None):
    return dict(file=name + ".png", prompt=prompt, canvas=canvas, rows=rows, note=note)


def rows_text(rows):
    parts = []
    for i, (anim, n) in enumerate(rows, 1):
        label, how = ANIM[anim]
        parts.append(f"{i}번째 줄 = {label} {n}프레임({how})")
    return ", ".join(parts)


# 0. Style reference ---------------------------------------------------------
asset("style_reference", "기준", 1, "그림체 기준 이미지", "reference", [
    sheet("style_reference",
          f"{STYLE} 게임 캐릭터 그림체 기준표. 서로 다른 여섯 판타지 영웅(판금 갑옷 드워프 전사, 로브를 입은 엘프 마법사, "
          f"녹색 피부의 오크 주술사, 고글을 쓴 작은 노움 기술자, 황소 머리의 거대한 타우렌 드루이드, 후드를 쓴 언데드 도적)이 "
          f"한 줄로 나란히 서 있는 전신 그림. 모두 오른쪽을 바라봅니다. {BG_TRANSPARENT} {CLEAN}",
          note="이후 모든 프롬프트에 이 그림을 '그림체 참고 이미지'로 함께 첨부하면 그림체가 일정해집니다. 게임에는 들어가지 않습니다."),
])

# 1. Heroes: 10 classes x 2 factions x 2 genders ----------------------------
for cls in CLASS_ORDER:
    cname, outfit, moves = CLASS[cls]
    for fac in ("alliance", "horde"):
        fname, fcol = FACTIONS[fac]
        race = CLASS_RACE[cls][fac]
        rname, male, female, size = RACE[race]
        for sex, look in (("m", male), ("f", female)):
            sexname = "남성" if sex == "m" else "여성"
            who = f"{look}. 직업은 {cname}: {outfit}. {fcol}. 체형: {size}"
            aid = f"hero_{cls}_{fac}_{sex}"
            title = f"{cname} · {fname} {rname} {sexname}"
            if cls == "druid":
                # druids fight in animal form; the caster form is only seen in menus and while walking
                sheets = [sheet(aid + "_A",
                                f"{STYLE} 게임 캐릭터 스프라이트 시트. {who}. {FACING['right']} "
                                f"가로로 넓은 캔버스에 {len(HERO_ROWS_A)}줄로 배치: {rows_text(HERO_ROWS_A)}. "
                                f"{SHEET_RULES} {BG_TRANSPARENT} {CLEAN}", rows=HERO_ROWS_A)]
            else:
                sheets = [
                    sheet(aid + "_A",
                          f"{STYLE} 게임 캐릭터 스프라이트 시트. {who}. {FACING['right']} "
                          f"가로로 넓은 캔버스에 {len(HERO_ROWS_A)}줄로 배치: {rows_text(HERO_ROWS_A)}. "
                          f"{SHEET_RULES} {BG_TRANSPARENT} {CLEAN}", rows=HERO_ROWS_A),
                    sheet(aid + "_B",
                          f"첨부한 이미지와 똑같은 캐릭터({title})의 전투 동작 스프라이트 시트. {STYLE} {who}. {moves}. "
                          f"{FACING['right']} 가로로 넓은 캔버스에 {len(HERO_ROWS_B)}줄로 배치: {rows_text(HERO_ROWS_B)}. "
                          f"{SHEET_RULES} {BG_TRANSPARENT} {CLEAN}", rows=HERO_ROWS_B,
                          note=f"{aid}_A.png 를 함께 첨부하세요(같은 캐릭터로 그리게 하려고)."),
                ]
            asset(aid, "영웅", 1, title, "sprite", sheets, cell=CELL_WIDE, cols=WIDE_COLS, facing="right",
                  game={"class": cls.upper(), "faction": fac.upper(), "sex": sex.upper(), "race": race.upper()})

# 2. Druid forms ----------------------------------------------------------------
FORMS = {
    "bear": ("곰 변신(수호)", {
        "alliance": "짙은 남보라색 털에 은빛 갈기, 이마에 초승달 무늬가 있는 거대한 곰",
        "horde": "갈색 털에 작은 뿔과 깃털 장식, 부족 문양 물감을 칠한 거대한 곰"},
        "공격: 앞발로 후려침 / 기술: 일어서서 포효하며 앞발로 땅을 내려침"),
    "cat": ("표범 변신(야성)", {
        "alliance": "보라빛이 도는 검은 털에 은색 줄무늬가 있는 날렵한 표범",
        "horde": "황갈색 털에 갈기가 살짝 있고 부족 문양을 칠한 날렵한 큰 고양이"},
        "공격: 발톱으로 할퀴며 덮침 / 기술: 뛰어올라 연속으로 할퀴고 물어뜯음"),
    "moonkin": ("달빛야수 변신(조화)", {
        "alliance": "사슴뿔이 달린 올빼미와 곰을 섞은 듯한 통통한 달빛야수, 푸른 깃털과 은빛 별 무늬",
        "horde": "사슴뿔이 달린 올빼미와 곰을 섞은 듯한 통통한 달빛야수, 갈색과 금색 깃털, 부족 장식"},
        "공격: 날개 같은 팔로 보라빛 별빛 구슬을 쏨 / 기술: 두 팔을 하늘로 들어 달빛 기둥을 내리게 함"),
    "treant": ("나무정령 변신(회복)", {
        "alliance": "걸어 다니는 작은 나무 정령, 푸른빛이 도는 잎사귀와 빛나는 꽃, 이끼 낀 몸",
        "horde": "걸어 다니는 작은 나무 정령, 가을빛 주황 잎사귀와 덩굴, 부족 장식이 걸린 몸"},
        "공격: 나뭇가지 팔로 초록 빛 구슬을 던짐 / 기술: 팔을 벌려 몸 주위로 치유의 잎사귀와 빛을 흩뿌림"),
}
for form, (ftitle, looks, moves) in FORMS.items():
    for fac in ("alliance", "horde"):
        aid = f"form_{form}_{fac}"
        look = looks[fac]
        title = f"드루이드 {ftitle} · {FACTIONS[fac][0]}"
        asset(aid, "드루이드 변신", 2, title, "sprite", [
            sheet(aid + "_A", f"{STYLE} 게임 캐릭터 스프라이트 시트. {look}. {FACING['right']} "
                  f"가로로 넓은 캔버스에 2줄로 배치: {rows_text(HERO_ROWS_A)}. {SHEET_RULES} {BG_TRANSPARENT} {CLEAN}",
                  rows=HERO_ROWS_A),
            sheet(aid + "_B", f"첨부한 이미지와 똑같은 {look}의 전투 동작 스프라이트 시트. {STYLE} {moves}. {FACING['right']} "
                  f"가로로 넓은 캔버스에 4줄로 배치: {rows_text(HERO_ROWS_B)}. {SHEET_RULES} {BG_TRANSPARENT} {CLEAN}",
                  rows=HERO_ROWS_B, note=f"{aid}_A.png 를 함께 첨부하세요."),
        ], cell=CELL_WIDE, cols=WIDE_COLS, facing="right", game={"form": form.upper(), "faction": fac.upper()})

# 3. Tinker battle mechs (the mech tank spec rides one) -------------------------
MECHS = {
    "alliance": "작은 노움 조종사가 유리 조종석에 타고 있는 두 발 달린 둥근 증기 기계(전투기계), 파란색과 은색 철판, "
                "한쪽 팔은 큰 집게, 다른 팔은 로켓 주먹, 등에 굴뚝",
    "horde": "작은 고블린 조종사가 열린 조종석에 타고 있는 두 발 달린 고철 전투기계(벌목기 같은 모양), 녹슨 빨간색과 노란 경고 줄무늬, "
             "한쪽 팔은 회전 톱날, 다른 팔은 화염 방사기, 연기 나는 굴뚝",
}
for fac, look in MECHS.items():
    aid = f"mech_{fac}"
    asset(aid, "땜장이 전투기계", 2, f"땜장이 기갑 전투기계 · {FACTIONS[fac][0]}", "sprite", [
        sheet(aid + "_A", f"{STYLE} 게임 캐릭터 스프라이트 시트. {look}. {FACING['right']} "
              f"가로로 넓은 캔버스에 2줄로 배치: {rows_text(HERO_ROWS_A)}(쿵쿵 걷는 무거운 걸음). {SHEET_RULES} {BG_TRANSPARENT} {CLEAN}",
              rows=HERO_ROWS_A),
        sheet(aid + "_B", f"첨부한 이미지와 똑같은 전투기계의 전투 동작 스프라이트 시트. {STYLE} {look}. "
              f"공격: 집게나 톱날 팔로 내려침 / 기술: 로켓 주먹을 발사하거나 화염을 뿜음. {FACING['right']} "
              f"가로로 넓은 캔버스에 4줄로 배치: {rows_text(HERO_ROWS_B)}(사망은 불꽃과 연기를 내며 주저앉음). "
              f"{SHEET_RULES} {BG_TRANSPARENT} {CLEAN}", rows=HERO_ROWS_B, note=f"{aid}_A.png 를 함께 첨부하세요."),
    ], cell=CELL_WIDE, cols=WIDE_COLS, facing="right", game={"mech": fac.upper()})

# 4. Summons (skills that call something onto the battlefield) ------------------
SUMMONS = [
    ("summon_wolf", "사냥꾼 야수 동료(늑대)", "회색 털의 커다란 늑대, 가죽 목줄", "hunters_pet"),
    ("summon_felguard", "흑마법사 지옥수호병", "녹색 불꽃 눈, 큰 뿔, 거대한 도끼를 든 근육질 악마 전사", "felguard"),
    ("summon_shadowfiend", "사제 어둠의 마귀", "보라색 그림자로 된 떠다니는 작은 악령, 빛나는 눈", "shadowfiend"),
    ("summon_water_elemental", "마법사 물의 정령", "푸른 물과 얼음 조각으로 이루어진 떠 있는 정령", "water_elemental"),
    ("summon_infernal", "흑마법사 지옥불정령", "녹색 불꽃이 타오르는 바위로 된 거대한 골렘", "summon_infernal"),
    ("summon_spirit_wolf", "주술사 야수 정령", "반투명한 푸른 빛으로 된 유령 늑대", "feral_spirit"),
    ("summon_boar", "사냥꾼 쇄도(멧돼지 떼)", "엄니가 큰 갈색 멧돼지", "stampede"),
    ("turret_gun", "땜장이 기관총 포탑", "삼각대 위에 올린 작은 기관총 포탑, 탄띠, 놋쇠와 강철", "gun_turret"),
    ("turret_rocket", "땜장이 로켓 포탑", "로켓 발사관 네 개가 달린 회전 포탑, 빨간 로켓", "rocket_turret"),
    ("turret_heal", "땜장이 치유 포탑", "초록 십자 무늬와 초록 빛 수정이 달린 땅에 박힌 기계 기둥, 치유 광선을 뿜음", "heal_turret"),
    ("drone_heal", "땜장이 치유 드론", "프로펠러로 떠 있는 작고 둥근 드론, 초록 렌즈와 집게 팔", "heal_drone"),
]
for aid, title, look, skill in SUMMONS:
    act = "공격" if not aid.endswith("heal") else "치유"
    rows = SUMMON_ROWS
    asset(aid, "소환수·포탑", 2, title, "sprite", [
        sheet(aid, f"{STYLE} 게임 소환수 스프라이트 시트. {look}. {FACING['right']} "
              f"가로로 넓은 캔버스에 2줄로 배치: 1번째 줄 = 대기 4프레임(살짝 움직이는 대기 동작), "
              f"2번째 줄 = {act} 4프레임({'광선이나 빛을 뿜는' if act == '치유' else '공격하는'} 동작). "
              f"{SHEET_RULES} {BG_TRANSPARENT} {CLEAN}", rows=rows),
    ], cell=CELL_SMALL, facing="right", game={"skill": skill})

# 5. Companions (account pets that walk with the party) -------------------------
CRITTERS = [
    ("pet_cat", "얼룩 고양이", "주황 얼룩무늬의 작은 고양이"),
    ("pet_chicken", "기계 닭", "태엽과 철판으로 만든 작은 기계 닭"),
    ("pet_skull", "떠도는 해골", "푸른 불꽃이 눈에서 타는 떠다니는 작은 해골"),
    ("pet_ember", "꼬마 불씨", "웃는 얼굴의 작은 불꽃 정령"),
    ("pet_imp", "말썽쟁이 임프", "장난스러운 표정의 작은 빨간 임프"),
    ("pet_whelp", "진홍 새끼용", "통통한 빨간 새끼 용"),
    ("pet_squirrel", "기계 다람쥐", "태엽 꼬리가 달린 작은 기계 다람쥐"),
    ("pet_bigglesworth", "비글스워스 씨", "통통하고 새침한 회색 고양이"),
]
for aid, title, look in CRITTERS:
    asset(aid, "동료", 3, f"동료 · {title}", "sprite", [
        sheet(aid, f"{STYLE} 아주 작은 애완동물 스프라이트 시트. {look}. {FACING['right']} "
              f"가로로 넓은 캔버스에 2줄로 배치: {rows_text(CRITTER_ROWS)}. {SHEET_RULES} {BG_TRANSPARENT} {CLEAN}",
              rows=CRITTER_ROWS),
    ], cell=CELL_SMALL, facing="right", game={"pet": aid[4:]})

# 6. Monsters: archetypes, tinted per monster in the game ----------------------
MONSTERS = [
    # id, title, look, which game monsters use it
    ("mob_wolf", "늑대·하이에나", "회색 털의 사나운 늑대", "wolf hyena fjord_worg warp_stalker"),
    ("mob_bigcat", "큰 고양이", "줄무늬가 있는 호랑이", "tiger frostsaber amani_lynx"),
    ("mob_bear", "곰", "커다란 회색 곰", "grizzly"),
    ("mob_boar", "멧돼지", "엄니가 큰 멧돼지", "boar helboar"),
    ("mob_raptor", "랩터·공룡", "날카로운 발톱의 두 발 공룡 랩터", "raptor deviate_raptor devilsaur thunder_lizard ravager basilisk croc"),
    ("mob_spider", "거미", "다리가 긴 거대한 독거미", "spider crypt_fiend nerubian"),
    ("mob_scorpion", "전갈·곤충", "갑각에 덮인 거대한 전갈", "scorpid silithid mantid amber_shaper"),
    ("mob_bat", "박쥐", "날개를 편 거대한 박쥐", "plaguebat sporebat fel_bat"),
    ("mob_serpent", "뱀·벌레", "똬리를 튼 거대한 독사", "serpent sandworm"),
    ("mob_crab", "게", "집게가 큰 거대한 게", "marsh_crab"),
    ("mob_beast_big", "덩치 큰 초식 짐승", "털이 덥수룩한 거대한 매머드", "clefthoof talbuk rhino mammoth"),
    ("mob_kobold", "작은 인간형(코볼트·멀록)", "머리에 양초를 꽂은 작은 쥐 얼굴의 코볼트", "kobold gnoll murloc goblin hozen virmen wolvar"),
    ("mob_bandit", "인간 도적·병사", "붉은 두건을 쓴 인간 도적", "defias crusader pirate darkiron darkiron_guard blackhand technician cultist twilight_zealot cult_adherent iron_dwarf mage_hunter"),
    ("mob_caster", "인간형 마법사", "두건 달린 로브를 입고 지팡이를 든 사악한 마법사", "defias_mage acolyte necromancer twilight_shaper ahnkahet_cultist cabal_cultist hellfire_channeler fel_orc_warlock dark_shaman"),
    ("mob_orc", "오크 전사", "녹색 피부의 오크 전사, 큰 도끼", "orc fel_orc shattered_hand korkron korkron_warbringer frostwolf ashtongue"),
    ("mob_troll", "트롤", "푸른 피부의 트롤 전사, 창", "troll sand_troll ice_troll drakkari drakkari_shaman amani_axe scourge_troll"),
    ("mob_naga", "나가", "뱀 꼬리를 가진 나가 전사, 삼지창", "naga_myrmidon naga_siren deep_naga deep_seer"),
    ("mob_elf", "엘프 마법사·기사", "붉은 로브의 엘프 마법사", "sunfury_mage sunfury_guard sunblade_knight sunblade_mage nightborne_mage nightborne_guard withered"),
    ("mob_beastman", "짐승 인간(켄타우로스·가시멧돼지족)", "멧돼지 머리의 가시멧돼지 인간 사냥꾼", "quilboar centaur furbolg yeti saurok yaungol"),
    ("mob_birdfolk", "새 인간(하피·아라코아)", "깃털 날개 팔을 가진 하피", "harpy arakkoa sethekk"),
    ("mob_skeleton", "해골", "녹슨 칼과 방패를 든 해골 전사", "skeleton skeleton_mage bone_construct"),
    ("mob_ghoul", "구울", "구부정하게 기어 다니는 구울", "ghoul geist"),
    ("mob_ghost", "유령", "반투명한 푸른 유령", "ghost banshee phantom_guest frozen_wraith raging_spirit valkyr spectral_steed"),
    ("mob_abomination", "누더기골렘", "꿰맨 살덩이로 된 거대한 누더기골렘, 갈고리", "abomination flesh_giant"),
    ("mob_dk", "죽음의 기사", "어두운 판금 갑옷과 푸른 빛 룬검의 죽음의 기사", "death_knight scourge_champion"),
    ("mob_gargoyle", "가고일", "돌 날개의 가고일", "gargoyle"),
    ("mob_fire_elemental", "불의 정령", "불꽃으로 된 정령", "fire_elemental lava_elemental son_of_flame ember_lord flamewaker phoenix"),
    ("mob_water_elemental", "물·얼음 정령", "얼음 조각으로 된 정령", "frost_elemental steam_surger crystalline"),
    ("mob_earth_elemental", "바위 정령", "바위와 수정으로 된 거인 정령", "stone_giant"),
    ("mob_air_elemental", "바람·번개 정령", "소용돌이 바람과 번개로 된 정령", "lightning_ele sand_djinn"),
    ("mob_ooze", "수액괴물", "끈적한 초록 젤리 괴물", "ooze"),
    ("mob_plant", "식물 괴물", "덩굴과 이끼로 된 걸어 다니는 식물 괴물", "mutate_lasher bog_lord nightmare_treant"),
    ("mob_imp", "작은 악마", "작은 빨간 임프", "imp"),
    ("mob_voidwalker", "공허방랑자", "푸른 연기로 된 거대한 공허 악마", "voidwalker"),
    ("mob_felhound", "지옥사냥개", "등에 촉수가 달린 녹색 지옥사냥개", "felhound antoran_hound core_hound"),
    ("mob_demon", "큰 악마", "뿔과 날개가 달린 거대한 악마 전사", "felguard doomguard wrathguard eredar illidari shadowsword satyr infernal shield_orb"),
    ("mob_whelp", "새끼 용", "검은 새끼 용", "whelp infinite_whelp frost_whelp mana_wyrm"),
    ("mob_drake", "비룡", "날개를 편 비룡", "drake proto_drake nether_drake storm_drake stone_drake twilight_drake frost_wyrm"),
    ("mob_dragonkin", "용혈족", "용 머리를 가진 인간형 전사", "dragonkin infinite_slayer azure_invader azure_mage nexus_lord"),
    ("mob_golem", "골렘·기계", "증기와 철판으로 된 기계 골렘", "golem iron_golem fel_sentry mechanar_drone fel_annihilator reorigination_module"),
    ("mob_ogre", "오우거", "머리가 두 개인 오우거, 큰 몽둥이", "ogre boulderfist gronnling"),
    ("mob_giant", "거인", "투구를 쓴 거인 전사", "storm_giant magnataur vrykul vrykul_seer valarjar ymirjar molten_giant anubisath qiraji neferset mogu mogu_sorcerer drogbar"),
    ("mob_tentacle", "촉수", "땅에서 솟은 눈 달린 거대한 촉수", "eye_tentacle corruption_tentacle"),
    ("mob_faceless", "얼굴 없는 자·공허 괴물", "얼굴 대신 촉수가 달린 공허 괴물", "faceless guardian_of_yogg sha nightmare_stalker"),
    ("mob_humanoid_misc", "기타 인간형", "온몸에 붕대를 감고 보랏빛 눈만 빛나는 신비한 떠돌이", "ethereal worgen jinyu"),
]
for aid, title, look, users in MONSTERS:
    asset(aid, "몬스터", 3, f"몬스터 · {title}", "sprite", [
        sheet(aid, f"{STYLE} 게임 몬스터 스프라이트 시트. {look}. 무섭기보다 귀엽고 개성 있게. {FACING['left']} "
              f"가로로 넓은 캔버스에 {len(MOB_ROWS)}줄로 배치: {rows_text(MOB_ROWS)}. {SHEET_RULES} {BG_TRANSPARENT} {CLEAN}",
              rows=MOB_ROWS, note="게임 안에서 색을 입혀 비슷한 몬스터 여럿에 함께 씁니다."),
    ], cell=CELL_WIDE, cols=WIDE_COLS, facing="left", game={"monsters": users.split()})

# 7. Raid bosses (the last zone of each act) ------------------------------------
BOSSES = [
    ("boss_ragnaros", "라그나로스(화산 심장부)", "용암과 불꽃으로 된 거대한 불의 군주, 큰 망치"),
    ("boss_cthun", "쑨(안퀴라즈)", "땅에서 솟은 거대한 눈알 촉수 괴물"),
    ("boss_kelthuzad", "켈투자드(낙스라마스)", "푸른 서리 기운을 두른 해골 리치 마법사"),
    ("boss_magtheridon", "마그테리돈", "쇠사슬에 묶였던 거대한 붉은 뿔 악마"),
    ("boss_kaelthas", "캘타스", "불사조 날개를 펼친 화려한 엘프 마법사 왕자"),
    ("boss_kiljaeden", "킬제덴", "거대한 뿔과 날개의 붉은 악마 군주"),
    ("boss_malygos", "말리고스", "푸른 마력으로 빛나는 거대한 푸른 용"),
    ("boss_yoggsaron", "요그사론", "촉수와 눈알로 뒤덮인 고대의 공허 괴물"),
    ("boss_lichking", "리치 왕", "얼음 왕관과 룬검을 든 어둠의 판금 왕"),
    ("boss_deathwing", "데스윙", "용암이 흐르는 철판을 덧댄 거대한 검은 용"),
    ("boss_garrosh", "가로쉬", "어두운 기운이 흐르는 갑옷의 거대한 오크 대족장, 큰 도끼"),
    ("boss_argus", "아르거스", "별의 기운을 두른 거대한 티탄 거인"),
]
for aid, title, look in BOSSES:
    asset(aid, "공격대 우두머리", 3, f"공격대 우두머리 · {title}", "sprite", [
        sheet(aid, f"{STYLE} 게임 보스 몬스터 스프라이트 시트. {look}. 위압감 있게 크게. {FACING['left']} "
              f"가로로 넓은 캔버스에 {len(MOB_ROWS)}줄로 배치: {rows_text(MOB_ROWS)}. {SHEET_RULES} {BG_TRANSPARENT} {CLEAN}",
              rows=MOB_ROWS),
    ], cell=CELL_WIDE, cols=WIDE_COLS, facing="left", game={"boss": aid[5:]})

# 8. Effects -------------------------------------------------------------------
FX_SETS = [
    ("fx_projectiles_1", "투사체 1", [
        ("proj_arrow", "날아가는 화살(깃털 꼬리)"), ("proj_bullet", "총알과 노란 궤적"),
        ("proj_fire", "불덩이와 불꽃 꼬리"), ("proj_frost", "얼음 화살과 서리 꼬리"),
    ], 4, "오른쪽으로 날아가는 투사체"),
    ("fx_projectiles_2", "투사체 2", [
        ("proj_shadow", "보라·검은 어둠의 화살"), ("proj_arcane", "분홍·보라 비전 구슬"),
        ("proj_holy", "금빛 성스러운 빛 구슬"), ("proj_nature", "초록 자연의 빛 구슬과 번개"),
    ], 4, "오른쪽으로 날아가는 투사체"),
    ("fx_impacts_1", "타격 효과 1", [
        ("hit_phys", "흰 베기 자국과 불똥"), ("hit_fire", "불꽃 폭발"),
        ("hit_frost", "얼음 조각이 튀는 폭발"), ("hit_nature", "초록 번개 폭발"),
    ], 6, "가운데에서 터지는 폭발"),
    ("fx_impacts_2", "타격 효과 2", [
        ("hit_shadow", "보라색 어둠의 폭발"), ("hit_holy", "금빛 빛의 폭발"),
        ("hit_arcane", "분홍색 비전 폭발"), ("hit_poison", "초록 독 방울이 튐"),
    ], 6, "가운데에서 터지는 폭발"),
    ("fx_support", "지원 효과", [
        ("fx_heal", "아래에서 위로 솟는 초록·금빛 치유 반짝임"), ("fx_shield", "캐릭터를 감싸는 반투명 푸른 보호막 구체(반복)"),
        ("fx_buff", "발밑에서 솟아오르는 금빛 강화 기운"), ("fx_revive", "하늘에서 내려오는 금빛 부활의 빛기둥"),
        ("fx_stun", "머리 위에서 빙빙 도는 노란 별(반복)"),
    ], 6, "캐릭터 크기에 맞춘 효과"),
    ("fx_fields_1", "광역 장판 1", [
        ("field_fire", "땅 위로 쏟아지는 불의 비와 불타는 바닥"), ("field_frost", "눈보라와 얼어붙는 바닥"),
        ("field_holy", "금빛 문양이 빛나는 신성한 바닥"), ("field_shadow", "보라색 어둠이 끓는 웅덩이"),
    ], 6, "가로로 넓은 바닥 장판(반복)"),
    ("fx_fields_2", "광역 장판 2", [
        ("field_nature", "초록 회오리바람과 번개"), ("field_arcane", "하늘에서 떨어지는 보라 별똥별"),
        ("field_arrows", "하늘에서 쏟아지는 화살 비"), ("field_whirl", "회전하는 칼날 바람"),
    ], 6, "가로로 넓은 바닥 장판(반복)"),
]
for aid, title, effects, n, how in FX_SETS:
    lines = ", ".join(f"{i}번째 줄 = {desc} {n}프레임" for i, (_, desc) in enumerate(effects, 1))
    asset(aid, "스킬 이펙트", 2, f"스킬 이펙트 · {title}", "fx", [
        sheet(aid, f"게임 스킬 이펙트 스프라이트 시트, 손으로 칠한 판타지 모바일 게임 스타일, 밝고 선명한 빛. "
              f"{how}를 줄마다 하나씩, 시간 순서대로 {n}프레임씩 그립니다: {lines}. "
              f"프레임끼리 겹치지 않게 간격을 두세요. {BG_TRANSPARENT} {CLEAN}",
              rows=[(e, n) for e, _ in effects]),
    ], cell=256 if aid.startswith("fx_fields") else CELL_SMALL, effects=[e for e, _ in effects])

# 9. Battle backgrounds: 16 zone themes, two layers each ------------------------
THEMES = [
    ("forest", "숲", "울창한 초록 숲과 먼 산, 맑은 하늘"),
    ("plains", "평원", "노란 들판과 풍차, 완만한 언덕"),
    ("jungle", "밀림", "덩굴과 거대한 잎사귀의 열대 밀림, 폭포"),
    ("swamp", "늪지", "안개 낀 늪, 버섯과 썩은 나무"),
    ("desert", "사막", "모래 언덕과 사암 절벽, 뜨거운 하늘"),
    ("snow", "설원", "눈 덮인 침엽수와 하얀 산"),
    ("ice", "얼음 동굴", "푸른 얼음 기둥과 얼어붙은 성채"),
    ("lava", "화산", "용암이 흐르는 검은 바위와 붉은 하늘"),
    ("fel", "지옥 황무지", "녹색 지옥불이 타는 붉은 황무지, 부서진 하늘"),
    ("shadow", "어둠의 땅", "보랏빛 안개와 죽은 나무, 음산한 달"),
    ("arcane", "비전 도시", "떠 있는 수정과 마법 탑, 보라빛 하늘"),
    ("cave", "동굴", "종유석과 빛나는 수정이 있는 어두운 동굴"),
    ("ruins", "고대 유적", "무너진 석조 기둥과 신전 유적"),
    ("sea", "바닷가", "파도치는 해안, 부서진 배, 등대"),
    ("storm", "폭풍 고원", "번개 치는 먹구름과 바위 고원"),
    ("holy", "성역", "금빛 빛줄기가 내리는 하얀 성당과 정원"),
]
for tid, tname, look in THEMES:
    aid = f"bg_{tid}"
    asset(aid, "전투 배경", 1 if tid in ("forest", "desert", "snow", "lava", "shadow", "ruins") else 2,
          f"전투 배경 · {tname}", "background", [
              sheet(aid + "_far", f"가로로 매우 긴 횡스크롤 게임의 먼 배경, 손으로 칠한 판타지 모바일 게임 스타일. {look}. "
                    f"땅바닥은 그리지 말고 하늘과 먼 풍경만. 지평선과 먼 산·건물은 그림 높이의 가운데(위에서 40%~70% 사이)에 오게 하고, "
                    f"그 위는 하늘, 아래는 비슷한 색의 먼 풍경으로 자연스럽게 채움. "
                    f"왼쪽 끝과 오른쪽 끝이 자연스럽게 이어지도록(이어 붙여도 경계가 안 보이게, seamless). 캐릭터 없음. {CLEAN}",
                    canvas="1536x1024"),
              sheet(aid + "_near", f"가로로 매우 긴 횡스크롤 게임의 가까운 바닥 층, 손으로 칠한 판타지 모바일 게임 스타일. {look}의 땅바닥: "
                    f"그림 아래쪽 1/3에 캐릭터가 걸어 다닐 평평한 길과 풀·돌·소품, 그 위는 전부 투명. "
                    f"왼쪽 끝과 오른쪽 끝이 자연스럽게 이어지도록(seamless). 캐릭터 없음. {BG_TRANSPARENT} {CLEAN}",
                    canvas="1536x1024"),
          ], game={"theme": tid})

# 10. Interface ---------------------------------------------------------------
UI_STYLE = ("판타지 모바일 RPG 인터페이스 에셋, 정면에서 본 평면 그림, 손으로 칠한 질감, 금속 테두리와 보석 장식, "
            "어두운 남색 바탕에 금색 테두리가 기본 색. 가운데는 단순하고 균일하게(늘리거나 반복해도 어색하지 않게).")
UI = [
    # id, title, what to draw, target (w, h), 9-slice margin in target pixels (None = icon)
    ("ui_window", "메뉴 창 큰 테두리", "큰 메뉴 창의 테두리 틀. 두꺼운 금속 테두리, 네 귀퉁이에 큰 보석 장식, 가운데는 어두운 남색 단색", (512, 512), 96),
    ("ui_header", "창 제목 띠", "창 맨 위에 붙는 가로로 긴 제목 띠(리본처럼 양 끝이 장식된 금속 판)", (512, 128), 48),
    ("ui_panel", "안쪽 패널", "창 안의 구역을 나누는 어두운 패널, 얇은 금색 테두리, 둥근 모서리", (256, 256), 32),
    ("ui_card", "카드", "밝은 남색 카드(조금 떠 보이는 판), 얇은 은색 테두리, 둥근 모서리", (256, 256), 32),
    ("ui_inset", "움푹한 칸", "안으로 움푹 들어간 어두운 칸(목록이나 숫자 뒤 배경), 안쪽 그림자", (128, 128), 24),
    ("ui_tooltip", "툴팁 배경", "작은 설명 창 배경, 검은 반투명 바탕과 얇은 금색 테두리", (128, 128), 20),
    ("ui_btn_primary", "주요 버튼(금색)", "가로로 긴 금색·주황색 버튼, 위쪽이 밝은 광택, 둥근 모서리, 글자 없음", (256, 64), 24),
    ("ui_btn_secondary", "보조 버튼(파란색)", "가로로 긴 파란색 버튼, 위쪽 광택, 둥근 모서리, 글자 없음", (256, 64), 24),
    ("ui_btn_neutral", "일반 버튼(회색)", "가로로 긴 회청색 버튼, 둥근 모서리, 글자 없음", (256, 64), 24),
    ("ui_btn_danger", "위험 버튼(빨간색)", "가로로 긴 빨간색 버튼, 둥근 모서리, 글자 없음", (256, 64), 24),
    ("ui_btn_confirm", "확인 버튼(초록색)", "가로로 긴 초록색 버튼, 둥근 모서리, 글자 없음", (256, 64), 24),
    ("ui_tab", "아래 메뉴 탭(보통)", "화면 아래 메뉴 줄의 사각 탭 버튼, 어두운 남색, 글자 없음", (128, 128), 28),
    ("ui_tab_on", "아래 메뉴 탭(선택됨)", "같은 탭 버튼이 선택된 모습, 금색 테두리와 은은한 빛, 글자 없음", (128, 128), 28),
    ("ui_slot", "아이템 칸", "아이템을 넣는 정사각형 칸, 어두운 바탕과 금속 테두리", (128, 128), 24),
    ("ui_portrait_ring", "초상화 테두리", "둥근 초상화를 감싸는 금속 원형 테두리(가운데는 투명)", (256, 256), None),
    ("ui_bar_frame", "막대 틀", "생명력·경험치 막대를 담는 가로로 긴 틀(가운데는 투명)", (256, 32), 12),
    ("ui_bar_fill", "막대 채움", "막대 안을 채우는 흰색 광택 띠(게임에서 색을 입힘)", (256, 32), 8),
    ("ui_boss_bar", "우두머리 체력 막대 틀", "해골과 날개 장식이 달린 화려한 가로 막대 틀(가운데는 투명)", (512, 64), 40),
    ("ui_pill", "알약 모양 칸", "숫자를 넣는 가로로 긴 알약 모양 칸, 어두운 바탕과 얇은 테두리", (128, 64), 28),
    ("ui_battle_frame", "전투 창 테두리", "가로로 아주 긴 전투 화면을 감싸는 금속 테두리, 위쪽 가운데에 작은 장식(가운데는 투명)", (512, 128), 40),
]
for aid, title, what, size, margin in UI:
    asset(aid, "인터페이스", 1, f"인터페이스 · {title}", "ui", [
        sheet(aid, f"{UI_STYLE} {what}. 한 장에 하나만, 화면을 가득 채우게. {BG_TRANSPARENT} 글자, 숫자, 워터마크는 넣지 마세요.",
              canvas="1024x1024" if size[0] == size[1] else "1536x1024"),
    ], size=size, slice=margin)

ICON_STYLE = ("판타지 모바일 RPG 아이콘, 손으로 칠한 질감, 굵은 외곽선, 정면, 선명한 색. "
              "아이콘끼리 겹치지 않게 넉넉한 간격, 모두 같은 크기.")
ICON_SETS = [
    ("icons_menu", "메뉴 아이콘", [
        ("icon_party", "어깨동무한 세 영웅의 실루엣과 깃발(편성)"), ("icon_hero", "날개 달린 투구(영웅)"),
        ("icon_bag", "가죽 배낭(가방)"), ("icon_forge", "모루와 망치, 불꽃(용광로)"),
        ("icon_runes", "빛나는 룬 문양이 새겨진 돌(룬)"), ("icon_map", "펼쳐진 양피지 지도와 나침반(지도)"),
        ("icon_settings", "톱니바퀴(설정)"), ("icon_goal", "빛나는 별과 깃발(다음 목표)"),
    ]),
    ("icons_role", "역할·진영 아이콘", [
        ("icon_tank", "파란 방패(탱커)"), ("icon_dps", "빨간 교차한 두 칼(딜러)"),
        ("icon_heal", "초록 십자와 잎사귀(힐러)"), ("icon_alliance", "파란 바탕에 금색 사자 머리 문장(얼라이언스)"),
        ("icon_horde", "붉은 바탕에 검은 늑대 머리와 도끼 문장(호드)"), ("icon_tinker", "렌치와 톱니바퀴(땜장이 직업)"),
        ("icon_male", "남성 기호"), ("icon_female", "여성 기호"),
    ]),
    ("icons_misc", "기타 아이콘", [
        ("icon_chest_common", "낡은 나무 상자"), ("icon_chest_boss", "철테를 두른 궤짝"),
        ("icon_chest_raid", "금으로 장식한 보물 상자"), ("icon_gold", "금화 더미"),
        ("icon_lock", "자물쇠"), ("icon_skull", "해골(우두머리)"),
        ("icon_auto", "둥근 화살표 두 개(자동)"), ("icon_crown", "작은 금관"),
    ]),
    ("icons_map", "지도 표시", [
        ("node_normal", "둥근 돌 표지(보통 지역)"), ("node_boss", "해골이 새겨진 붉은 큰 표지(공격대 지역)"),
        ("node_cleared", "초록 체크가 새겨진 표지(공략 완료)"), ("node_locked", "회색 자물쇠 표지(잠김)"),
        ("node_current", "금빛으로 빛나는 표지(현재 위치)"), ("icon_star", "금색 별"),
        ("icon_close", "빨간 X 닫기 단추"), ("icon_arrow", "오른쪽을 가리키는 금색 화살표"),
    ]),
]
for aid, title, icons in ICON_SETS:
    lines = ", ".join(f"{i}. {desc}" for i, (_, desc) in enumerate(icons, 1))
    asset(aid, "아이콘", 1, f"아이콘 · {title}", "icons", [
        sheet(aid, f"{ICON_STYLE} 4개씩 2줄, 모두 {len(icons)}개를 왼쪽 위부터 순서대로: {lines}. {BG_TRANSPARENT} 글자, 숫자, 워터마크는 넣지 마세요.",
              canvas="1536x1024"),
    ], size=(128, 128), icons=[i for i, _ in icons])


def by_priority():
    return sorted(ASSETS, key=lambda a: (a["priority"], ASSETS.index(a)))


def sheet_files():
    for a in ASSETS:
        for s in a["sheets"]:
            yield a, s


if __name__ == "__main__":
    n = sum(len(a["sheets"]) for a in ASSETS)
    print("%d assets, %d images to make" % (len(ASSETS), n))
    for p in (1, 2, 3):
        sel = [a for a in ASSETS if a["priority"] == p]
        print("  priority %d: %d assets, %d images" % (p, len(sel), sum(len(a["sheets"]) for a in sel)))
