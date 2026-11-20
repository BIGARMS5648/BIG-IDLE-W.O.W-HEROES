# 그림 원본 폴더

챗지피티 등으로 만든 그림(PNG)을 이 폴더에 넣습니다.

- 파일 이름은 `docs/ASSET_PROMPTS.md`(또는 그림 작업표 페이지)에 적힌 이름을 **그대로** 씁니다. 예: `hero_warrior_alliance_m_A.png`
- 배경은 투명이거나 단색 마젠타(#FF00FF)여야 합니다.
- 넣은 뒤 `python3 tools/import_art.py --check`로 빠진 파일을, `python3 tools/import_art.py`로 게임용 텍스처를 만듭니다.

이 폴더의 파일은 게임에 직접 들어가지 않습니다. 가져오기 도구가 만든 `BigIdleWoWHeroes/Media/Art/`만 애드온에 포함됩니다.
