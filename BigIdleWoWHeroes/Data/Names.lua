-- Random hero names. A name is built from a head and a tail syllable group;
-- every group has a Korean and a Latin spelling, so a hero keeps the same name
-- whichever language the interface is shown in.
local _, ns = ...

local HEAD = {
	{ "아르", "Ar" }, { "벨", "Bel" }, { "카", "Ka" }, { "다르", "Dar" }, { "엘", "El" }, { "가", "Ga" },
	{ "로", "Ro" }, { "마", "Ma" }, { "세", "Se" }, { "타", "Ta" }, { "발", "Val" }, { "린", "Lin" },
	{ "소", "So" }, { "티", "Ti" }, { "우", "U" }, { "이", "I" }, { "제", "Je" }, { "케", "Ke" },
	{ "페", "Fe" }, { "하", "Ha" }, { "브리", "Bri" }, { "그롬", "Grom" }, { "토르", "Thor" }, { "실", "Syl" },
	{ "말", "Mal" }, { "제이", "Jai" }, { "안", "An" }, { "바", "Ba" }, { "쿠", "Ku" }, { "나", "Na" },
	{ "오르", "Or" }, { "레", "Re" }, { "모", "Mo" }, { "드라", "Dra" }, { "알", "Al" }, { "비", "Vi" },
	{ "크", "Kr" }, { "셀", "Sel" }, { "테", "Te" }, { "유", "Yu" }, { "자", "Za" }, { "헬", "Hel" },
}

local TAIL = {
	{ "단", "dan" }, { "로스", "los" }, { "리아", "ria" }, { "미르", "mir" }, { "벤", "ven" }, { "드릭", "dric" },
	{ "라", "ra" }, { "린", "lyn" }, { "스", "s" }, { "온", "on" }, { "엘", "el" }, { "나", "na" },
	{ "토르", "tor" }, { "윈", "wyn" }, { "가르", "gar" }, { "다스", "das" }, { "렌", "ren" }, { "시아", "sia" },
	{ "무르", "mur" }, { "란", "lan" }, { "디아", "dia" }, { "릭", "rik" }, { "투스", "thus" }, { "바나", "vana" },
	{ "론", "ron" }, { "쉬", "sh" }, { "카", "ka" }, { "딘", "din" }, { "레스", "less" }, { "미아", "mia" },
	{ "고르", "gor" }, { "잔", "zan" }, { "하르", "har" }, { "노스", "nos" }, { "에라", "era" }, { "두인", "duin" },
}

ns.Names = {}

-- taken: optional set of Korean names already in use
function ns.Names.Roll(taken)
	for _ = 1, 30 do
		local h = HEAD[math.random(1, #HEAD)]
		local t = TAIL[math.random(1, #TAIL)]
		local ko = h[1] .. t[1]
		if not (taken and taken[ko]) then
			return { ko, h[2] .. t[2] }
		end
	end
	local h = HEAD[math.random(1, #HEAD)]
	local t = TAIL[math.random(1, #TAIL)]
	return { h[1] .. t[1], h[2] .. t[2] }
end
