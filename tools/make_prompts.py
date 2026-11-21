#!/usr/bin/env python3
"""Write docs/ASSET_PROMPTS.md: every image the add-on can use, with a prompt to
paste into an image model, grouped by priority. Generated from tools/asset_spec.py.

    python3 tools/make_prompts.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_spec as S  # noqa: E402

OUT = os.path.join(HERE, "..", "docs", "ASSET_PROMPTS.md")

PRIORITY = {
    1: ("1단계 · 먼저 만들 것", "그림체 기준, 인터페이스, 아이콘, 모든 영웅, 기본 전투 배경 6종. 이것만 있어도 게임 화면이 완전히 바뀝니다."),
    2: ("2단계 · 다음에 만들 것", "드루이드 변신, 땜장이 전투기계, 소환수와 포탑, 스킬 이펙트, 나머지 전투 배경."),
    3: ("3단계 · 여유가 있을 때", "몬스터, 공격대 우두머리, 동료. 없는 동안은 지금처럼 아이콘으로 표시됩니다."),
}

CANVAS = {
    "1536x1024": "가로로 긴 3:2 (1536×1024)",
    "1024x1024": "정사각형 1:1 (1024×1024)",
    "1024x1536": "세로로 긴 2:3 (1024×1536)",
}

GUIDE = """# 그림 에셋 프롬프트 목록

게임에 들어갈 그림을 챗지피티(이미지 생성)로 만들 때 쓰는 프롬프트 모음입니다.
이 문서는 `tools/make_prompts.py`가 `tools/asset_spec.py`에서 자동으로 만듭니다. 파일 이름, 프레임 수, 크기는 게임 코드와 가져오기 도구(`tools/import_art.py`)가 그대로 읽는 값이니 바꾸지 마세요.

전체 {total_assets}개 에셋, 그림 {total_images}장
{priority_lines}

## 작업 순서

1. **그림체 기준 이미지부터** 만드세요(맨 처음 항목). 마음에 들 때까지 다시 뽑고, 고른 그림을 `style_reference.png`로 저장합니다.
2. 그다음부터는 **모든 요청에 기준 이미지를 같이 첨부**하고 프롬프트를 붙여 넣으세요. 그림체가 일정해집니다.
3. 영웅·변신·전투기계는 **시트 A(대기·걷기)를 먼저** 만들고, 같은 대화에서 **시트 A를 첨부한 채로 시트 B(공격·기술·피격·사망)**를 요청하세요. 같은 캐릭터로 그려집니다.
4. 결과를 **표에 적힌 파일 이름 그대로** PNG로 저장하세요(예: `hero_warrior_alliance_m_A.png`).
5. 다 만든 파일은 이 대화에 첨부하거나, GitHub 저장소의 `art_src/` 폴더에 올려 주세요(웹에서 *Add file → Upload files*). 그러면 제가 게임에 넣습니다.

## 잘 뽑는 요령

- **캔버스 비율**을 함께 말하세요. 각 항목의 "캔버스"에 적힌 비율(예: "가로로 긴 3:2")을 프롬프트 앞에 붙이면 됩니다.
- **배경은 투명**이어야 합니다. 투명이 안 되면 단색 마젠타(분홍 보라, #FF00FF) 배경이면 됩니다. 가져오기 도구가 지웁니다.
- **프레임 수가 틀리면** "2번째 줄은 정확히 6개로 다시"처럼 고쳐 달라고 하세요. 프레임 크기나 간격이 조금씩 달라도 도구가 맞춰 줍니다.
- 한 장에 줄이 많아 어려우면 **줄을 나눠서 따로** 만들어도 됩니다. 이때는 파일 이름 뒤에 `_1`, `_2`를 붙이고(예: `hero_mage_horde_f_B_1.png`) 줄 순서를 지켜 주세요.
- 게임 이름이나 실제 캐릭터 이름은 프롬프트에 넣지 않았습니다(거절당하지 않게). 원하는 모습이 안 나오면 생김새 설명을 더 자세히 덧붙이세요.
- 영웅은 전투 화면에서 높이 60~90픽셀 정도로 작게 보입니다. 얼굴보다 **실루엣, 무기, 색**이 잘 구분되는 쪽이 좋습니다.

## 인터페이스 그림이 들어가는 자리 (새 화면 배치)

모든 메뉴 화면은 같은 틀입니다. 각 자리에 들어가는 그림 파일은 다음과 같습니다(괄호 안은 파일 이름에서 .png를 뺀 것).

```
┌ 메뉴 창 테두리 (ui_window) ───────────────────────────────────────────┐
│ 제목 띠 (ui_header): 화면 아이콘(icons_menu) · 화면 이름 · 골드(ui_pill)  [X](icon_close) │
│ [위쪽 탭 ui_chip / 고른 탭 ui_chip_on] ...                                    │
│ ┌ 왼쪽 목록 판 (ui_inset) ─────────────┐ ┌ 오른쪽 카드 (ui_card) ─────────┐ │
│ │ 머리줄 [작은 버튼 ui_btn_neutral/secondary] │ 머리 띠(ui_band) 아이콘 이름 │ │
│ │ 영웅 카드(ui_card) + 초상화 테두리     │ │                                  │ │
│ │ (ui_portrait_ring), 역할(icons_role)  │ │ 능력치 줄(icons_stats*)          │ │
│ │ 아이템 칸(ui_slot / icons_quality)    │ │ 막대(ui_bar_frame, ui_bar_fill)  │ │
│ │ 고른 것: 금색 테두리 (ui_select)      │ │                                  │ │
│ │ "+ 영웅 만들기" 카드(ui_card, icon_plus) │ │ [보조 ui_btn_neutral][실행 ui_btn_primary] │
│ └───────────────────────────────────────┘ └──────────────────────────────────┘ │
│ [아래 탭 ui_tab / 지금 화면 ui_tab_on] × 6 (icons_menu)                       │
└───────────────────────────────────────────────────────────────────────┘
알림 (ui_toast): 메뉴 창 위쪽 테두리에 잠깐   설명 창 (ui_tooltip): 마우스를 올리면
잃는 행동 버튼 (ui_btn_danger) · 켜짐 버튼 (ui_btn_confirm) · 빨간 알림 점 (icon_badge)
확인 창: 창 (ui_window) · [취소 ui_btn_neutral] [실행 ui_btn_danger 또는 ui_btn_primary]
선택 버튼: 버튼 (ui_chip) + 아래 화살표 (icon_arrow를 돌려 씀) → 펼친 목록 (ui_card), 고른 줄 (icon_check)
룬 화면: 트리 바탕 (ui_inset) · 룬 칸 (ui_slot, 아이콘) · 이어 주는 줄 (색만) · 아래 정보 줄 (ui_card)
전투 창: 테두리 (ui_battle_frame) · 우두머리 막대 (ui_boss_bar, 맨 위 가운데) · 상자 (icons_misc)
```

{ui_table}

## 화면 어디에 쓰이나

| 묶음 | 쓰이는 곳 |
| --- | --- |
| 영웅 | 전투 창의 캐릭터 애니메이션, 메뉴의 초상화(대기 첫 프레임에서 얼굴 부분을 잘라 씀) |
| 드루이드 변신 | 드루이드는 전투 중 전문화에 맞는 모습으로 변신해 싸웁니다(수호=곰, 야성=표범, 조화=달빛야수, 회복=나무정령) |
| 땜장이 전투기계 | 기갑(탱커) 땜장이는 전투기계에 탄 모습으로 싸웁니다 |
| 소환수·포탑 | 소환 기술을 쓰면 전투 창에 나타납니다 |
| 스킬 이펙트 | 투사체, 타격, 치유·보호막, 광역 장판 |
| 전투 배경 | 지역 분위기마다 다른 배경. 먼 배경과 가까운 바닥이 다른 속도로 흘러 움직이는 느낌을 줍니다 |
| 인터페이스·아이콘 | 메뉴 창 테두리, 버튼, 칸, 막대, 아래 메뉴 아이콘 등 |
| 몬스터·우두머리 | 비슷한 몬스터 여럿이 한 그림을 색만 바꿔 함께 씁니다 |
"""


def main():
    total_images = sum(len(a["sheets"]) for a in S.ASSETS)
    lines = []
    for p in (1, 2, 3):
        sel = [a for a in S.ASSETS if a["priority"] == p]
        n = sum(len(a["sheets"]) for a in sel)
        lines.append(f"- **{PRIORITY[p][0]}**: 그림 {n}장. {PRIORITY[p][1]}")
    rows = ["| 파일 | 그림 | 쓰이는 곳 |", "| --- | --- | --- |"]
    for a in S.ASSETS:
        if a["kind"] in ("ui", "icons") and a.get("where"):
            what = a["title"].split(" · ", 1)[-1]
            if a["kind"] == "icons":
                what += " (%d개: %s)" % (len(a["icons"]), ", ".join(a["icons"]))
            rows.append("| `%s` | %s | %s |" % (a["sheets"][0]["file"], what, a["where"]))
    out = [GUIDE.format(total_assets=len(S.ASSETS), total_images=total_images, priority_lines="\n".join(lines),
                        ui_table="\n".join(rows))]

    for p in (1, 2, 3):
        out.append(f"\n---\n\n# {PRIORITY[p][0]}\n")
        groups = []
        for a in S.ASSETS:
            if a["priority"] == p and a["group"] not in groups:
                groups.append(a["group"])
        for g in groups:
            sel = [a for a in S.ASSETS if a["priority"] == p and a["group"] == g]
            out.append(f"\n## {g} ({sum(len(a['sheets']) for a in sel)}장)\n")
            for a in sel:
                out.append(f"\n### {a['title']}\n")
                for s in a["sheets"]:
                    canvas = CANVAS.get(s["canvas"], s["canvas"])
                    out.append(f"- 파일 이름: `{s['file']}`  ·  캔버스: {canvas}")
                    if s.get("note"):
                        out.append(f"- 참고: {s['note']}")
                    out.append("")
                    out.append("```text")
                    out.append(f"[{canvas} 캔버스] {s['prompt']}")
                    out.append("```")
                    out.append("")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out).rstrip() + "\n")
    print("wrote %s (%d assets, %d images)" % (os.path.normpath(OUT), len(S.ASSETS), total_images))


def write_json(path):
    """The same list as data (used by the interactive prompt page)."""
    import json
    out = []
    for p in (1, 2, 3):
        for a in S.ASSETS:
            if a["priority"] != p:
                continue
            out.append({
                "id": a["id"], "group": a["group"], "priority": a["priority"], "title": a["title"],
                "sheets": [{"file": s["file"], "canvas": CANVAS.get(s["canvas"], s["canvas"]), "note": s.get("note") or "",
                            "prompt": "[%s 캔버스] %s" % (CANVAS.get(s["canvas"], s["canvas"]), s["prompt"])} for s in a["sheets"]],
            })
    with open(path, "w", encoding="utf-8") as f:
        f.write("[\n" + ",\n".join(json.dumps(e, ensure_ascii=False) for e in out) + "\n]\n")
    print("wrote %s" % path)


if __name__ == "__main__":
    main()
    if len(sys.argv) > 2 and sys.argv[1] == "--json":
        write_json(sys.argv[2])
