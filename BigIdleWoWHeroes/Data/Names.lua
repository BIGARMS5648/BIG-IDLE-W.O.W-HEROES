-- Random hero names, built from a head and a tail syllable group.
local _, ns = ...

local HEAD = {
	"아르", "벨", "카", "다르", "엘", "가",
	"로", "마", "세", "타", "발", "린",
	"소", "티", "우", "이", "제", "케",
	"페", "하", "브리", "그롬", "토르", "실",
	"말", "제이", "안", "바", "쿠", "나",
	"오르", "레", "모", "드라", "알", "비",
	"크", "셀", "테", "유", "자", "헬",
}

local TAIL = {
	"단", "로스", "리아", "미르", "벤", "드릭",
	"라", "린", "스", "온", "엘", "나",
	"토르", "윈", "가르", "다스", "렌", "시아",
	"무르", "란", "디아", "릭", "투스", "바나",
	"론", "쉬", "카", "딘", "레스", "미아",
	"고르", "잔", "하르", "노스", "에라", "두인",
}

ns.Names = {}

-- taken: optional set of names already in use
function ns.Names.Roll(taken)
	local name
	for _ = 1, 30 do
		name = HEAD[math.random(1, #HEAD)] .. TAIL[math.random(1, #TAIL)]
		if not (taken and taken[name]) then return name end
	end
	return name
end
