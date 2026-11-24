-- TBH (Task Bar Hero) data, from the community datamine at taskbarhero.wiki
-- (tools/gen_tbh.py): stage levels and boxes, box contents,
-- experience, monster growth by stage level and the ten grades.
-- Generated: do not edit by hand.
local _, ns = ...
local T = {}
ns.TBH = T

-- the item levels gear comes in (an item is worn from its own level)
T.ITEM_LEVELS = { 1, 5, 10, 15, 20, 30, 40, 50, 65, 80, 100 }

-- experience from level L to L + 1
T.XP = { 30, 150, 500, 1000, 2600, 6500, 13000, 23400, 37440, 74880, 134784, 229133, 366613, 513258, 718561, 970057, 1309577, 1702450, 2042940, 3064410, 3615531, 4157861, 4739962, 5356157, 6266704, 7708046, 9866299, 12135548, 14198591, 15618450, 17180295, 18709341, 20170728, 21528801, 22748528, 23796986, 24644829, 25267650, 25647149, 25772024, 25638532, 25250674, 24619997, 28490088, 32968530, 38150952, 44148014, 51653176, 63533406, 81322760, 100026995, 117031584, 125223795, 133989461, 143368723, 153404534, 164142851, 175632851, 187927151, 201082052, 215157796, 230218842, 241729784, 253816273, 266507087, 279832441, 293824063, 308515266, 323941029, 340138080, 357144984, 375002233, 393752345, 413439962, 434111960, 455817558, 478608436, 559971870, 688765400, 881619712, 1084392246, 1268738928, 1306801096, 1346005129, 1386385283, 1427976841, 1470816146, 1514940630, 1560388849, 1607200514, 1655416529, 1705079025, 1739180606, 1773964218, 1809443502, 1845632372, 1882545019, 1920195919, 1958599837, 1997771834 }

-- monsters at stage level L: attack, health, gold and experience, times
-- those at level 1
T.MULT = {
	{ 1, 1, 1, 1 }, { 1.3, 1.8, 1.5, 1.3 }, { 1.6, 2.2, 2, 1.6 }, { 1.9, 2.7, 3, 3 }, { 2.2, 3.2, 3.5, 4.5 },
	{ 2.6, 4.4, 3.8, 6.5 }, { 3.1, 5.9, 4.1, 9.5 }, { 3.5, 7.2, 4.4, 13.5 }, { 3.8, 8.2, 4.7, 18 }, { 4.1, 9.7, 5.5, 23 },
	{ 4.4, 10.7, 6, 29 }, { 4.7, 14.7, 6.5, 37 }, { 5, 19.7, 7.1, 47 }, { 5.3, 25.7, 7.8, 59 }, { 5.6, 32.7, 8.6, 73 },
	{ 5.9, 40.7, 9.5, 89 }, { 6.2, 49.7, 10.5, 107 }, { 6.5, 59.7, 11.6, 127 }, { 6.8, 70.7, 12.8, 150 }, { 7.1, 82.7, 14.1, 176 },
	{ 7.4, 95.7, 15.5, 204 }, { 7.7, 109.7, 17, 234 }, { 8, 124.7, 18.6, 266 }, { 8.3, 140.7, 20.3, 300 }, { 8.6, 157.7, 22.1, 336 },
	{ 8.9, 175.7, 24, 374 }, { 9.2, 194.7, 26, 414 }, { 9.5, 214.7, 28.1, 456 }, { 9.8, 235.7, 30.3, 500 }, { 10.1, 257.7, 32.6, 546 },
	{ 10.45, 280.7, 35, 594 }, { 10.85, 304.7, 37.5, 644 }, { 11.3, 329.7, 40.1, 696 }, { 11.8, 355.7, 42.8, 750 }, { 12.35, 382.7, 45.6, 806 },
	{ 12.95, 410.7, 48.5, 864 }, { 13.6, 439.7, 51.5, 924 }, { 14.3, 469.7, 54.6, 986 }, { 15.1, 500.7, 57.8, 1050 }, { 16, 532.7, 61.1, 1116 },
	{ 17, 565.7, 64.5, 1184 }, { 18.1, 599.7, 68, 1254 }, { 19.3, 634.7, 71.6, 1326 }, { 20.6, 670.7, 75.3, 1400 }, { 22, 707.7, 79.1, 1476 },
	{ 23.5, 745.7, 83, 1554 }, { 25.1, 784.7, 87, 1634 }, { 26.8, 824.7, 91.1, 1716 }, { 28.55, 865.7, 95.3, 1800 }, { 30.5, 907.7, 99.6, 1886 },
	{ 32.65, 950.7, 104, 1974 }, { 35, 994.7, 108.5, 2064 }, { 37.55, 1039.7, 113.1, 2156 }, { 40.3, 1085.7, 117.8, 2250 }, { 43.25, 1132.7, 122.6, 2346 },
	{ 46.4, 1180.7, 127.5, 2444 }, { 49.75, 1229.7, 132.5, 2544 }, { 53.3, 1279.7, 137.6, 2646 }, { 57.05, 1330.7, 142.8, 2750 }, { 60.85, 1382.7, 148.1, 2856 },
	{ 65.15, 1435.7, 153.5, 2964 }, { 69.95, 1489.7, 159, 3074 }, { 75.25, 1544.7, 164.6, 3186 }, { 81.05, 1600.7, 170.3, 3300 }, { 87.35, 1657.7, 176.1, 3416 },
	{ 94.15, 1715.7, 182, 3534 }, { 101.45, 1774.7, 188, 3654 }, { 109.25, 1834.7, 194.1, 3776 }, { 117.55, 1895.7, 200.3, 3900 }, { 126.35, 1957.7, 206.6, 4026 },
	{ 135.65, 2020.7, 213, 4154 }, { 145.45, 2084.7, 219.5, 4284 }, { 156.25, 2149.7, 226.1, 4416 }, { 168.05, 2215.7, 232.8, 4550 }, { 180.85, 2282.7, 239.6, 4686 },
	{ 194.65, 2350.7, 246.5, 4824 }, { 209.45, 2419.7, 253.5, 4964 }, { 225.25, 2489.7, 260.6, 5106 }, { 242.05, 2560.7, 267.8, 5250 }, { 263.85, 2632.7, 275.1, 5396 },
	{ 290.65, 2705.7, 282.5, 5544 }, { 322.45, 2779.7, 290, 5694 }, { 359.25, 2854.7, 297.6, 5846 }, { 401.05, 2930.7, 305.3, 6000 }, { 447.85, 3007.7, 313.1, 6156 },
	{ 504.65, 3085.7, 321, 6314 }, { 571.45, 3164.7, 329, 6474 }, { 648.25, 3244.7, 337.1, 6636 }, { 735.05, 3325.7, 345.3, 6800 }, { 871.85, 3407.7, 353.6, 6966 },
	{ 1058.65, 3490.7, 362, 7134 }, { 1295.45, 3574.7, 370.5, 7304 }, { 1582.25, 3659.7, 379.1, 7476 }, { 1969.05, 3745.7, 387.8, 7650 }, { 2455.85, 3832.7, 396.6, 7826 },
	{ 3042.65, 3920.7, 405.5, 8004 }, { 3729.45, 4009.7, 414.5, 8184 }, { 4516.25, 4099.7, 423.6, 8366 }, { 5403.05, 4190.7, 432.8, 8550 }, { 6389.85, 4282.7, 442.1, 8736 },
}

-- every stage (difficulty, then 1..30 = act and stage): level, its
-- monsters (waves x per wave = kills), the monster box (key, per mille
-- each kill) and the boss box (key, per mille; an act boss always drops)
T.STAGES = { {}, {}, {}, {} }
T.STAGES[1][1] = { lv = 1, waves = 10, per = 1, mbox = 910011, mrate = 160, bbox = 920011, brate = 1000 }
T.STAGES[1][2] = { lv = 2, waves = 11, per = 2, mbox = 910011, mrate = 160, bbox = 920011, brate = 1000 }
T.STAGES[1][3] = { lv = 3, waves = 11, per = 3, mbox = 910011, mrate = 160, bbox = 920011, brate = 1000 }
T.STAGES[1][4] = { lv = 5, waves = 12, per = 3, mbox = 910051, mrate = 120, bbox = 920051, brate = 1000 }
T.STAGES[1][5] = { lv = 6, waves = 12, per = 4, mbox = 910051, mrate = 120, bbox = 920051, brate = 800 }
T.STAGES[1][6] = { lv = 7, waves = 12, per = 5, mbox = 910051, mrate = 80, bbox = 920051, brate = 800 }
T.STAGES[1][7] = { lv = 8, waves = 12, per = 6, mbox = 910051, mrate = 80, bbox = 920051, brate = 600 }
T.STAGES[1][8] = { lv = 10, waves = 13, per = 6, mbox = 910101, mrate = 30, bbox = 920101, brate = 400 }
T.STAGES[1][9] = { lv = 11, waves = 13, per = 7, mbox = 910101, mrate = 30, bbox = 920101, brate = 400 }
T.STAGES[1][10] = { lv = 12, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930101, brate = 1000, act = true }
T.STAGES[1][11] = { lv = 13, waves = 14, per = 7, mbox = 910101, mrate = 30, bbox = 920101, brate = 400 }
T.STAGES[1][12] = { lv = 14, waves = 14, per = 7, mbox = 910101, mrate = 30, bbox = 920101, brate = 400 }
T.STAGES[1][13] = { lv = 15, waves = 14, per = 7, mbox = 910151, mrate = 25, bbox = 920151, brate = 300 }
T.STAGES[1][14] = { lv = 16, waves = 15, per = 7, mbox = 910151, mrate = 25, bbox = 920151, brate = 300 }
T.STAGES[1][15] = { lv = 17, waves = 15, per = 7, mbox = 910151, mrate = 25, bbox = 920151, brate = 300 }
T.STAGES[1][16] = { lv = 18, waves = 15, per = 8, mbox = 910151, mrate = 25, bbox = 920151, brate = 300 }
T.STAGES[1][17] = { lv = 19, waves = 15, per = 8, mbox = 910151, mrate = 25, bbox = 920151, brate = 300 }
T.STAGES[1][18] = { lv = 20, waves = 16, per = 8, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][19] = { lv = 21, waves = 16, per = 8, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][20] = { lv = 22, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930201, brate = 1000, act = true }
T.STAGES[1][21] = { lv = 23, waves = 16, per = 8, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][22] = { lv = 24, waves = 16, per = 8, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][23] = { lv = 25, waves = 17, per = 9, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][24] = { lv = 26, waves = 17, per = 9, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][25] = { lv = 27, waves = 17, per = 9, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][26] = { lv = 28, waves = 17, per = 9, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][27] = { lv = 29, waves = 17, per = 10, mbox = 910201, mrate = 20, bbox = 920201, brate = 200 }
T.STAGES[1][28] = { lv = 30, waves = 18, per = 10, mbox = 910301, mrate = 20, bbox = 920301, brate = 200 }
T.STAGES[1][29] = { lv = 31, waves = 18, per = 11, mbox = 910301, mrate = 20, bbox = 920301, brate = 200 }
T.STAGES[1][30] = { lv = 32, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930301, brate = 1000, act = true }
T.STAGES[2][1] = { lv = 33, waves = 20, per = 10, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][2] = { lv = 34, waves = 20, per = 10, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][3] = { lv = 35, waves = 20, per = 11, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][4] = { lv = 35, waves = 21, per = 11, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][5] = { lv = 36, waves = 21, per = 12, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][6] = { lv = 37, waves = 21, per = 12, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][7] = { lv = 38, waves = 21, per = 13, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][8] = { lv = 39, waves = 21, per = 13, mbox = 910301, mrate = 15, bbox = 920301, brate = 150 }
T.STAGES[2][9] = { lv = 40, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][10] = { lv = 40, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930401, brate = 1000, act = true }
T.STAGES[2][11] = { lv = 41, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][12] = { lv = 41, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][13] = { lv = 42, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][14] = { lv = 42, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][15] = { lv = 43, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][16] = { lv = 43, waves = 22, per = 13, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][17] = { lv = 44, waves = 22, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][18] = { lv = 44, waves = 22, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][19] = { lv = 45, waves = 23, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][20] = { lv = 45, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930451, brate = 1000, act = true }
T.STAGES[2][21] = { lv = 46, waves = 23, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][22] = { lv = 47, waves = 23, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][23] = { lv = 48, waves = 23, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][24] = { lv = 49, waves = 23, per = 14, mbox = 910401, mrate = 15, bbox = 920401, brate = 150 }
T.STAGES[2][25] = { lv = 50, waves = 23, per = 14, mbox = 910501, mrate = 15, bbox = 920501, brate = 150 }
T.STAGES[2][26] = { lv = 50, waves = 23, per = 14, mbox = 910501, mrate = 15, bbox = 920501, brate = 150 }
T.STAGES[2][27] = { lv = 51, waves = 23, per = 15, mbox = 910501, mrate = 15, bbox = 920501, brate = 150 }
T.STAGES[2][28] = { lv = 51, waves = 23, per = 15, mbox = 910501, mrate = 15, bbox = 920501, brate = 150 }
T.STAGES[2][29] = { lv = 52, waves = 23, per = 15, mbox = 910501, mrate = 15, bbox = 920501, brate = 150 }
T.STAGES[2][30] = { lv = 52, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930501, brate = 1000, act = true }
T.STAGES[3][1] = { lv = 53, waves = 24, per = 15, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][2] = { lv = 54, waves = 24, per = 15, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][3] = { lv = 55, waves = 25, per = 15, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][4] = { lv = 56, waves = 25, per = 15, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][5] = { lv = 57, waves = 25, per = 15, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][6] = { lv = 58, waves = 25, per = 15, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][7] = { lv = 59, waves = 25, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][8] = { lv = 59, waves = 25, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][9] = { lv = 60, waves = 25, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][10] = { lv = 60, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930601, brate = 1000, act = true }
T.STAGES[3][11] = { lv = 61, waves = 26, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][12] = { lv = 62, waves = 26, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][13] = { lv = 63, waves = 26, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][14] = { lv = 64, waves = 26, per = 16, mbox = 910501, mrate = 10, bbox = 920501, brate = 100 }
T.STAGES[3][15] = { lv = 65, waves = 26, per = 16, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][16] = { lv = 66, waves = 26, per = 16, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][17] = { lv = 67, waves = 26, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][18] = { lv = 68, waves = 26, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][19] = { lv = 69, waves = 26, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][20] = { lv = 69, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930651, brate = 1000, act = true }
T.STAGES[3][21] = { lv = 70, waves = 27, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][22] = { lv = 71, waves = 27, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][23] = { lv = 72, waves = 27, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][24] = { lv = 73, waves = 27, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][25] = { lv = 74, waves = 27, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][26] = { lv = 75, waves = 27, per = 17, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][27] = { lv = 76, waves = 27, per = 18, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][28] = { lv = 76, waves = 27, per = 18, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][29] = { lv = 77, waves = 27, per = 18, mbox = 910651, mrate = 10, bbox = 920651, brate = 100 }
T.STAGES[3][30] = { lv = 77, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930701, brate = 1000, act = true }
T.STAGES[4][1] = { lv = 78, waves = 29, per = 18, mbox = 910651, mrate = 8, bbox = 920651, brate = 80 }
T.STAGES[4][2] = { lv = 79, waves = 29, per = 18, mbox = 910651, mrate = 8, bbox = 920651, brate = 80 }
T.STAGES[4][3] = { lv = 80, waves = 29, per = 18, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][4] = { lv = 81, waves = 29, per = 18, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][5] = { lv = 82, waves = 29, per = 18, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][6] = { lv = 83, waves = 29, per = 18, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][7] = { lv = 84, waves = 29, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][8] = { lv = 84, waves = 29, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][9] = { lv = 85, waves = 29, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][10] = { lv = 85, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930851, brate = 1000, act = true }
T.STAGES[4][11] = { lv = 86, waves = 30, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][12] = { lv = 86, waves = 30, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][13] = { lv = 87, waves = 30, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][14] = { lv = 87, waves = 30, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][15] = { lv = 88, waves = 30, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][16] = { lv = 88, waves = 30, per = 19, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][17] = { lv = 89, waves = 30, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][18] = { lv = 89, waves = 30, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][19] = { lv = 90, waves = 30, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][20] = { lv = 90, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930901, brate = 1000, act = true }
T.STAGES[4][21] = { lv = 91, waves = 31, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][22] = { lv = 91, waves = 31, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][23] = { lv = 92, waves = 31, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][24] = { lv = 92, waves = 31, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][25] = { lv = 93, waves = 31, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][26] = { lv = 93, waves = 31, per = 20, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][27] = { lv = 94, waves = 31, per = 21, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][28] = { lv = 94, waves = 31, per = 21, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][29] = { lv = 95, waves = 31, per = 21, mbox = 910801, mrate = 8, bbox = 920801, brate = 80 }
T.STAGES[4][30] = { lv = 95, waves = 0, per = 0, mbox = nil, mrate = nil, bbox = 930901, brate = 1000, act = true }

-- every box: what an opening rolls, by weight (percent):
--   { "gear", family, grade, item level, weight }  family: armor (head,
--     chest, hands or feet), weapon, offhand, neck, ring, trinket, wrist
--   { "mat", kind, grade, weight }  kind: gem (장식), dust (세공),
--     scroll (각인), craft, seal (coins), soul (soulstones; grade = number)
T.BOXES = {
	[910011] = { kind = "monster", lv = 1, e = {
		{ "gear", "armor", 1, 1, 38.91 }, { "gear", "weapon", 1, 1, 31.83 }, { "gear", "armor", 2, 1, 10.18 }, { "gear", "weapon", 2, 1, 8.907 },
		{ "gear", "offhand", 1, 1, 4.549 }, { "mat", "craft", 1, 3 }, { "gear", "offhand", 2, 1, 1.272 }, { "gear", "armor", 3, 1, 0.675 },
		{ "gear", "weapon", 3, 1, 0.591 }, { "gear", "offhand", 3, 1, 0.084 },
	} },
	[910051] = { kind = "monster", lv = 5, e = {
		{ "gear", "armor", 1, 5, 36.48 }, { "gear", "weapon", 1, 5, 29.85 }, { "gear", "armor", 2, 5, 10.29 }, { "gear", "weapon", 2, 5, 9.006 },
		{ "mat", "craft", 1, 5 }, { "gear", "offhand", 1, 5, 4.265 }, { "mat", "gem", 1, 2.449 }, { "gear", "offhand", 2, 5, 1.287 },
		{ "gear", "armor", 3, 5, 0.683 }, { "gear", "weapon", 3, 5, 0.598 }, { "gear", "offhand", 3, 5, 0.085 },
	} },
	[910101] = { kind = "monster", lv = 10, e = {
		{ "gear", "armor", 1, 10, 34.99 }, { "gear", "weapon", 1, 10, 28.63 }, { "gear", "armor", 2, 10, 10.34 }, { "gear", "weapon", 2, 10, 9.043 },
		{ "mat", "craft", 1, 5 }, { "mat", "gem", 1, 4.27 }, { "gear", "offhand", 1, 10, 4.091 }, { "gear", "offhand", 2, 10, 1.292 },
		{ "gear", "armor", 3, 10, 1.176 }, { "gear", "weapon", 3, 10, 1.029 }, { "gear", "offhand", 3, 10, 0.147 },
	} },
	[910151] = { kind = "monster", lv = 15, e = {
		{ "gear", "armor", 1, 15, 21.89 }, { "gear", "weapon", 1, 15, 18.24 }, { "gear", "armor", 1, 10, 10.94 }, { "gear", "weapon", 1, 10, 9.12 },
		{ "gear", "armor", 2, 15, 6.882 }, { "gear", "weapon", 2, 15, 5.736 }, { "mat", "craft", 1, 5 }, { "mat", "gem", 1, 4.865 },
		{ "gear", "armor", 2, 10, 3.441 }, { "gear", "weapon", 2, 10, 2.867 }, { "gear", "offhand", 1, 15, 2.736 }, { "gear", "offhand", 1, 10, 1.368 },
		{ "mat", "dust", 1, 1.216 }, { "gear", "armor", 3, 15, 1.108 }, { "gear", "weapon", 3, 15, 0.924 }, { "gear", "offhand", 2, 15, 0.859 },
		{ "gear", "armor", 3, 10, 0.554 }, { "gear", "weapon", 3, 10, 0.46 }, { "gear", "offhand", 2, 10, 0.43 }, { "gear", "armor", 4, 15, 0.335 },
		{ "gear", "weapon", 4, 15, 0.279 }, { "gear", "armor", 4, 10, 0.168 }, { "gear", "offhand", 3, 15, 0.14 }, { "gear", "weapon", 4, 10, 0.14 },
		{ "gear", "offhand", 3, 10, 0.071 }, { "gear", "armor", 5, 15, 0.056 }, { "gear", "weapon", 5, 15, 0.047 }, { "gear", "offhand", 4, 15, 0.041 },
		{ "gear", "armor", 5, 10, 0.028 }, { "gear", "weapon", 5, 10, 0.023 }, { "gear", "offhand", 4, 10, 0.022 }, { "gear", "offhand", 5, 15, 0.007 },
		{ "gear", "offhand", 5, 10, 0.004 },
	} },
	[910201] = { kind = "monster", lv = 20, e = {
		{ "gear", "armor", 1, 20, 21.73 }, { "gear", "weapon", 1, 20, 18.11 }, { "gear", "armor", 1, 15, 10.87 }, { "gear", "weapon", 1, 15, 9.053 },
		{ "gear", "armor", 2, 20, 6.586 }, { "gear", "weapon", 2, 20, 5.489 }, { "mat", "craft", 1, 3.75 }, { "mat", "gem", 1, 3.648 },
		{ "gear", "armor", 2, 15, 3.293 }, { "gear", "weapon", 2, 15, 2.744 }, { "gear", "offhand", 1, 20, 2.716 }, { "gear", "armor", 3, 20, 1.438 },
		{ "gear", "offhand", 1, 15, 1.359 }, { "mat", "craft", 2, 1.25 }, { "mat", "gem", 2, 1.216 }, { "gear", "weapon", 3, 20, 1.2 },
		{ "mat", "dust", 1, 0.912 }, { "gear", "offhand", 2, 20, 0.822 }, { "gear", "armor", 3, 15, 0.719 }, { "gear", "weapon", 3, 15, 0.6 },
		{ "gear", "armor", 4, 20, 0.423 }, { "gear", "offhand", 2, 15, 0.412 }, { "gear", "weapon", 4, 20, 0.352 }, { "mat", "dust", 2, 0.304 },
		{ "gear", "armor", 4, 15, 0.212 }, { "gear", "offhand", 3, 20, 0.18 }, { "gear", "weapon", 4, 15, 0.176 }, { "gear", "offhand", 3, 15, 0.089 },
		{ "gear", "armor", 5, 20, 0.07 }, { "gear", "weapon", 5, 20, 0.059 }, { "gear", "offhand", 4, 20, 0.053 }, { "mat", "seal", 1, 0.038 },
		{ "gear", "armor", 5, 15, 0.035 }, { "gear", "weapon", 5, 15, 0.029 }, { "gear", "offhand", 4, 15, 0.028 }, { "gear", "offhand", 5, 20, 0.009 },
		{ "gear", "armor", 6, 20, 0.008 }, { "gear", "weapon", 6, 20, 0.006 }, { "gear", "offhand", 5, 15, 0.005 }, { "gear", "weapon", 6, 15, 0.003 },
		{ "gear", "armor", 6, 15, 0.004 }, { "gear", "offhand", 6, 20, 0.001 },
	} },
	[910301] = { kind = "monster", lv = 30, e = {
		{ "gear", "armor", 1, 30, 29.34 }, { "gear", "weapon", 1, 30, 24.45 }, { "gear", "armor", 2, 30, 9.249 }, { "gear", "weapon", 2, 30, 7.709 },
		{ "mat", "craft", 1, 4.499 }, { "mat", "gem", 1, 4.377 }, { "gear", "offhand", 1, 30, 3.667 }, { "gear", "armor", 3, 30, 2.942 },
		{ "mat", "craft", 2, 2.812 }, { "mat", "gem", 2, 2.735 }, { "gear", "weapon", 3, 30, 2.452 }, { "gear", "offhand", 2, 30, 1.155 },
		{ "mat", "dust", 1, 1.094 }, { "gear", "armor", 4, 30, 0.837 }, { "gear", "weapon", 4, 30, 0.698 }, { "mat", "dust", 2, 0.693 },
		{ "gear", "offhand", 3, 30, 0.368 }, { "mat", "craft", 3, 0.187 }, { "mat", "gem", 3, 0.182 }, { "gear", "armor", 5, 30, 0.14 },
		{ "gear", "weapon", 5, 30, 0.116 }, { "gear", "offhand", 4, 30, 0.106 }, { "mat", "seal", 1, 0.057 }, { "mat", "scroll", 1, 0.057 },
		{ "mat", "dust", 3, 0.036 }, { "gear", "offhand", 5, 30, 0.018 }, { "gear", "armor", 6, 30, 0.016 }, { "gear", "weapon", 6, 30, 0.013 },
		{ "gear", "offhand", 6, 30, 0.002 },
	} },
	[910401] = { kind = "monster", lv = 40, e = {
		{ "gear", "armor", 1, 40, 23.58 }, { "gear", "weapon", 1, 40, 19.65 }, { "gear", "armor", 2, 40, 7.752 }, { "gear", "weapon", 2, 40, 6.461 },
		{ "gear", "armor", 1, 30, 4.717 }, { "gear", "weapon", 1, 30, 3.931 }, { "mat", "craft", 1, 3.345 }, { "mat", "gem", 1, 3.254 },
		{ "gear", "armor", 3, 40, 3.087 }, { "mat", "craft", 2, 3.066 }, { "mat", "gem", 2, 2.983 }, { "gear", "offhand", 1, 40, 2.948 },
		{ "gear", "weapon", 3, 40, 2.57 }, { "gear", "armor", 2, 30, 1.55 }, { "gear", "weapon", 2, 30, 1.292 }, { "gear", "offhand", 2, 40, 0.968 },
		{ "gear", "armor", 4, 40, 0.904 }, { "mat", "craft", 3, 0.836 }, { "mat", "gem", 3, 0.813 }, { "mat", "dust", 1, 0.813 },
		{ "gear", "weapon", 4, 40, 0.754 }, { "mat", "dust", 2, 0.741 }, { "gear", "armor", 3, 30, 0.617 }, { "gear", "offhand", 1, 30, 0.591 },
		{ "gear", "weapon", 3, 30, 0.515 }, { "gear", "offhand", 3, 40, 0.386 }, { "mat", "dust", 3, 0.199 }, { "gear", "offhand", 2, 30, 0.193 },
		{ "mat", "craft", 4, 0.186 }, { "gear", "armor", 4, 30, 0.181 }, { "mat", "gem", 4, 0.181 }, { "gear", "weapon", 4, 30, 0.151 },
		{ "gear", "armor", 5, 40, 0.151 }, { "gear", "weapon", 5, 40, 0.126 }, { "gear", "offhand", 4, 40, 0.113 }, { "gear", "offhand", 3, 30, 0.078 },
		{ "mat", "seal", 1, 0.056 }, { "mat", "scroll", 1, 0.056 }, { "mat", "dust", 4, 0.054 }, { "gear", "armor", 5, 30, 0.03 },
		{ "gear", "weapon", 5, 30, 0.025 }, { "gear", "offhand", 4, 30, 0.024 }, { "gear", "offhand", 5, 40, 0.019 }, { "gear", "armor", 6, 40, 0.017 },
		{ "gear", "weapon", 6, 40, 0.014 }, { "gear", "offhand", 5, 30, 0.004 }, { "gear", "armor", 6, 30, 0.003 }, { "gear", "offhand", 6, 40, 0.002 },
		{ "gear", "weapon", 6, 30, 0.003 },
	} },
	[910501] = { kind = "monster", lv = 50, e = {
		{ "gear", "armor", 1, 50, 21.06 }, { "gear", "weapon", 1, 50, 17.55 }, { "gear", "armor", 2, 50, 7.129 }, { "gear", "armor", 1, 40, 6.317 },
		{ "gear", "weapon", 2, 50, 5.942 }, { "gear", "weapon", 1, 40, 5.263 }, { "gear", "armor", 3, 50, 3.514 }, { "mat", "craft", 2, 3.084 },
		{ "mat", "gem", 2, 3 }, { "gear", "weapon", 3, 50, 2.928 }, { "gear", "offhand", 1, 50, 2.633 }, { "mat", "craft", 1, 2.54 },
		{ "mat", "gem", 1, 2.471 }, { "gear", "armor", 2, 40, 2.139 }, { "gear", "weapon", 2, 40, 1.783 }, { "mat", "craft", 3, 1.27 },
		{ "mat", "gem", 3, 1.235 }, { "gear", "armor", 3, 40, 1.054 }, { "gear", "armor", 4, 50, 1.029 }, { "gear", "offhand", 2, 50, 0.89 },
		{ "gear", "weapon", 3, 40, 0.877 }, { "gear", "weapon", 4, 50, 0.859 }, { "gear", "offhand", 1, 40, 0.789 }, { "mat", "dust", 2, 0.759 },
		{ "mat", "dust", 1, 0.618 }, { "gear", "offhand", 3, 50, 0.439 }, { "mat", "craft", 4, 0.363 }, { "mat", "gem", 4, 0.353 },
		{ "gear", "armor", 4, 40, 0.309 }, { "mat", "dust", 3, 0.3 }, { "gear", "offhand", 2, 40, 0.267 }, { "gear", "weapon", 4, 40, 0.259 },
		{ "gear", "armor", 5, 50, 0.172 }, { "gear", "weapon", 5, 50, 0.143 }, { "gear", "offhand", 3, 40, 0.134 }, { "gear", "offhand", 4, 50, 0.129 },
		{ "mat", "dust", 4, 0.088 }, { "mat", "scroll", 1, 0.055 }, { "gear", "armor", 5, 40, 0.051 }, { "gear", "weapon", 5, 40, 0.043 },
		{ "gear", "offhand", 4, 40, 0.04 }, { "mat", "seal", 1, 0.04 }, { "gear", "offhand", 5, 50, 0.022 }, { "gear", "armor", 6, 50, 0.019 },
		{ "gear", "weapon", 6, 50, 0.016 }, { "mat", "seal", 2, 0.015 }, { "gear", "offhand", 5, 40, 0.006 }, { "gear", "armor", 6, 40, 0.006 },
		{ "gear", "weapon", 6, 40, 0.005 }, { "gear", "offhand", 6, 50, 0.002 }, { "gear", "offhand", 6, 40, 0.001 },
	} },
	[910651] = { kind = "monster", lv = 65, e = {
		{ "gear", "armor", 1, 65, 24.11 }, { "gear", "weapon", 1, 65, 20.09 }, { "gear", "armor", 2, 65, 8.738 }, { "gear", "weapon", 2, 65, 7.283 },
		{ "gear", "armor", 3, 65, 5.54 }, { "gear", "weapon", 3, 65, 4.616 }, { "mat", "craft", 2, 3.573 }, { "mat", "gem", 2, 3.476 },
		{ "gear", "offhand", 1, 65, 3.013 }, { "mat", "craft", 1, 2.62 }, { "mat", "gem", 1, 2.549 }, { "mat", "craft", 3, 2.382 },
		{ "mat", "gem", 3, 2.317 }, { "gear", "armor", 4, 65, 1.524 }, { "gear", "weapon", 4, 65, 1.272 }, { "gear", "offhand", 2, 65, 1.091 },
		{ "mat", "dust", 2, 0.881 }, { "mat", "craft", 4, 0.834 }, { "mat", "gem", 4, 0.811 }, { "gear", "offhand", 3, 65, 0.694 },
		{ "mat", "dust", 1, 0.626 }, { "mat", "dust", 3, 0.579 }, { "gear", "armor", 5, 65, 0.268 }, { "gear", "weapon", 5, 65, 0.223 },
		{ "mat", "dust", 4, 0.209 }, { "gear", "offhand", 4, 65, 0.191 }, { "mat", "craft", 5, 0.119 }, { "mat", "gem", 5, 0.116 },
		{ "mat", "seal", 1, 0.043 }, { "mat", "scroll", 1, 0.043 }, { "gear", "offhand", 5, 65, 0.034 }, { "gear", "armor", 6, 65, 0.03 },
		{ "gear", "weapon", 6, 65, 0.025 }, { "mat", "dust", 5, 0.023 }, { "mat", "scroll", 2, 0.018 }, { "mat", "seal", 2, 0.017 },
		{ "mat", "seal", 3, 0.013 }, { "mat", "scroll", 3, 0.011 }, { "gear", "offhand", 6, 65, 0.004 }, { "gear", "armor", 7, 65, 0.001 },
	} },
	[910801] = { kind = "monster", lv = 80, e = {
		{ "gear", "armor", 1, 80, 20.82 }, { "gear", "weapon", 1, 80, 17.35 }, { "gear", "armor", 2, 80, 8.128 }, { "gear", "weapon", 2, 80, 6.775 },
		{ "gear", "armor", 3, 80, 6.318 }, { "gear", "weapon", 3, 80, 5.265 }, { "mat", "craft", 2, 3.623 }, { "mat", "gem", 2, 3.525 },
		{ "mat", "craft", 3, 3.472 }, { "mat", "gem", 3, 3.378 }, { "mat", "craft", 1, 3.08 }, { "mat", "gem", 1, 2.996 },
		{ "gear", "offhand", 1, 80, 2.602 }, { "gear", "armor", 4, 80, 1.719 }, { "mat", "craft", 4, 1.51 }, { "mat", "gem", 4, 1.469 },
		{ "gear", "weapon", 4, 80, 1.432 }, { "gear", "offhand", 2, 80, 1.015 }, { "mat", "dust", 2, 0.881 }, { "mat", "dust", 3, 0.852 },
		{ "gear", "offhand", 3, 80, 0.789 }, { "mat", "dust", 1, 0.734 }, { "mat", "dust", 4, 0.382 }, { "mat", "craft", 5, 0.302 },
		{ "mat", "gem", 5, 0.294 }, { "gear", "armor", 5, 80, 0.286 }, { "gear", "weapon", 5, 80, 0.238 }, { "gear", "offhand", 4, 80, 0.215 },
		{ "mat", "craft", 6, 0.091 }, { "mat", "gem", 6, 0.088 }, { "mat", "dust", 5, 0.059 }, { "mat", "seal", 1, 0.041 },
		{ "mat", "scroll", 1, 0.041 }, { "gear", "offhand", 5, 80, 0.036 }, { "gear", "armor", 6, 80, 0.032 }, { "mat", "dust", 6, 0.029 },
		{ "gear", "weapon", 6, 80, 0.026 }, { "mat", "scroll", 2, 0.02 }, { "mat", "seal", 2, 0.018 }, { "mat", "scroll", 3, 0.015 },
		{ "mat", "seal", 3, 0.014 }, { "mat", "seal", 4, 0.009 }, { "mat", "seal", 5, 0.009 }, { "mat", "scroll", 4, 0.008 },
		{ "mat", "scroll", 5, 0.007 }, { "gear", "offhand", 6, 80, 0.004 }, { "gear", "armor", 7, 80, 0.001 }, { "gear", "weapon", 7, 80, 0.001 },
	} },
	[920011] = { kind = "boss", lv = 1, e = {
		{ "gear", "weapon", 2, 1, 23.91 }, { "gear", "armor", 2, 1, 23.91 }, { "gear", "weapon", 1, 1, 13.29 }, { "gear", "armor", 1, 1, 13.29 },
		{ "gear", "weapon", 3, 1, 8.035 }, { "gear", "armor", 3, 1, 8.035 }, { "gear", "offhand", 1, 1, 3.189 }, { "gear", "offhand", 2, 1, 2.87 },
		{ "gear", "offhand", 3, 1, 0.964 }, { "gear", "weapon", 4, 1, 0.945 }, { "gear", "armor", 4, 1, 0.945 }, { "gear", "weapon", 5, 1, 0.189 },
		{ "gear", "armor", 5, 1, 0.189 }, { "gear", "offhand", 4, 1, 0.113 }, { "mat", "soul", 1, 0.1 }, { "gear", "offhand", 5, 1, 0.023 },
	} },
	[920051] = { kind = "boss", lv = 5, e = {
		{ "gear", "weapon", 2, 5, 22.14 }, { "gear", "armor", 2, 5, 22.14 }, { "gear", "weapon", 1, 5, 10.2 }, { "gear", "armor", 1, 5, 10.2 },
		{ "gear", "weapon", 3, 5, 7.386 }, { "gear", "armor", 3, 5, 7.386 }, { "mat", "craft", 1, 7 }, { "mat", "soul", 1, 2.737 },
		{ "gear", "offhand", 2, 5, 2.657 }, { "gear", "offhand", 1, 5, 2.448 }, { "mat", "gem", 1, 2.172 }, { "gear", "weapon", 4, 5, 1.012 },
		{ "gear", "armor", 4, 5, 1.012 }, { "gear", "offhand", 3, 5, 0.886 }, { "gear", "weapon", 5, 5, 0.235 }, { "gear", "armor", 5, 5, 0.235 },
		{ "gear", "offhand", 4, 5, 0.122 }, { "gear", "offhand", 5, 5, 0.028 },
	} },
	[920101] = { kind = "boss", lv = 10, e = {
		{ "gear", "weapon", 2, 10, 25 }, { "gear", "armor", 2, 10, 25 }, { "mat", "soul", 1, 13.06 }, { "gear", "weapon", 3, 10, 8.282 },
		{ "gear", "armor", 3, 10, 8.282 }, { "mat", "craft", 1, 7 }, { "mat", "gem", 1, 5.331 }, { "gear", "offhand", 2, 10, 2.999 },
		{ "gear", "weapon", 4, 10, 1.301 }, { "gear", "armor", 4, 10, 1.301 }, { "gear", "offhand", 3, 10, 0.994 }, { "mat", "gem", 2, 0.592 },
		{ "gear", "weapon", 5, 10, 0.336 }, { "gear", "armor", 5, 10, 0.336 }, { "gear", "offhand", 4, 10, 0.156 }, { "gear", "offhand", 5, 10, 0.041 },
	} },
	[920151] = { kind = "boss", lv = 15, e = {
		{ "gear", "armor", 2, 15, 13.36 }, { "mat", "soul", 1, 11.36 }, { "gear", "weapon", 2, 15, 11.13 }, { "gear", "armor", 2, 10, 6.677 },
		{ "gear", "armor", 1, 15, 5.686 }, { "gear", "weapon", 2, 10, 5.565 }, { "gear", "armor", 3, 15, 4.967 }, { "gear", "weapon", 1, 15, 4.738 },
		{ "mat", "craft", 2, 4.2 }, { "gear", "weapon", 3, 15, 4.14 }, { "mat", "gem", 2, 3.506 }, { "gear", "armor", 1, 10, 2.843 },
		{ "mat", "craft", 1, 2.8 }, { "gear", "armor", 3, 10, 2.483 }, { "gear", "weapon", 1, 10, 2.369 }, { "mat", "gem", 1, 2.338 },
		{ "gear", "weapon", 3, 10, 2.071 }, { "gear", "offhand", 2, 15, 1.668 }, { "mat", "dust", 2, 1.286 }, { "gear", "offhand", 2, 10, 0.835 },
		{ "gear", "armor", 4, 15, 0.827 }, { "mat", "dust", 1, 0.818 }, { "gear", "offhand", 1, 15, 0.711 }, { "gear", "weapon", 4, 15, 0.689 },
		{ "gear", "offhand", 3, 15, 0.62 }, { "gear", "armor", 4, 10, 0.413 }, { "gear", "offhand", 1, 10, 0.355 }, { "gear", "weapon", 4, 10, 0.344 },
		{ "gear", "offhand", 3, 10, 0.305 }, { "gear", "armor", 5, 15, 0.229 }, { "gear", "weapon", 5, 15, 0.191 }, { "gear", "armor", 5, 10, 0.114 },
		{ "gear", "offhand", 4, 15, 0.104 }, { "gear", "weapon", 5, 10, 0.095 }, { "gear", "offhand", 4, 10, 0.051 }, { "gear", "armor", 6, 15, 0.038 },
		{ "gear", "weapon", 6, 15, 0.032 }, { "gear", "offhand", 5, 15, 0.029 }, { "gear", "offhand", 5, 10, 0.014 }, { "gear", "offhand", 6, 15, 0.005 },
	} },
	[920201] = { kind = "boss", lv = 20, e = {
		{ "gear", "armor", 2, 20, 13.12 }, { "mat", "soul", 1, 11.34 }, { "gear", "weapon", 2, 20, 10.94 }, { "gear", "armor", 2, 15, 6.561 },
		{ "gear", "weapon", 2, 15, 5.468 }, { "gear", "armor", 1, 20, 5.457 }, { "gear", "armor", 3, 20, 5.233 }, { "gear", "weapon", 1, 20, 4.548 },
		{ "gear", "weapon", 3, 20, 4.357 }, { "mat", "craft", 2, 3.78 }, { "mat", "gem", 2, 3.155 }, { "gear", "armor", 1, 15, 2.729 },
		{ "gear", "armor", 3, 15, 2.616 }, { "gear", "weapon", 1, 15, 2.274 }, { "gear", "weapon", 3, 15, 2.178 }, { "mat", "craft", 1, 2.1 },
		{ "mat", "gem", 1, 1.753 }, { "gear", "offhand", 2, 20, 1.639 }, { "mat", "dust", 2, 1.169 }, { "mat", "craft", 3, 1.12 },
		{ "mat", "gem", 3, 0.935 }, { "gear", "armor", 4, 20, 0.916 }, { "gear", "offhand", 2, 15, 0.82 }, { "gear", "weapon", 4, 20, 0.763 },
		{ "gear", "offhand", 1, 20, 0.682 }, { "gear", "offhand", 3, 20, 0.654 }, { "mat", "dust", 1, 0.643 }, { "gear", "armor", 4, 15, 0.458 },
		{ "gear", "weapon", 4, 15, 0.383 }, { "gear", "offhand", 1, 15, 0.342 }, { "gear", "offhand", 3, 15, 0.322 }, { "gear", "armor", 5, 20, 0.296 },
		{ "mat", "dust", 3, 0.292 }, { "gear", "weapon", 5, 20, 0.247 }, { "gear", "armor", 5, 15, 0.148 }, { "gear", "weapon", 5, 15, 0.124 },
		{ "mat", "seal", 1, 0.12 }, { "gear", "offhand", 4, 20, 0.114 }, { "gear", "offhand", 4, 15, 0.057 }, { "gear", "offhand", 5, 20, 0.037 },
		{ "gear", "armor", 6, 20, 0.033 }, { "gear", "weapon", 6, 20, 0.027 }, { "gear", "offhand", 5, 15, 0.019 }, { "gear", "armor", 6, 15, 0.017 },
		{ "gear", "weapon", 6, 15, 0.014 }, { "gear", "offhand", 6, 20, 0.004 }, { "gear", "offhand", 6, 15, 0.002 },
	} },
	[920301] = { kind = "boss", lv = 30, e = {
		{ "gear", "armor", 2, 30, 16.34 }, { "gear", "weapon", 2, 30, 13.62 }, { "mat", "soul", 1, 8 }, { "gear", "armor", 3, 30, 7.673 },
		{ "gear", "armor", 1, 30, 6.914 }, { "gear", "weapon", 3, 30, 6.39 }, { "mat", "soul", 2, 6 }, { "gear", "weapon", 1, 30, 5.761 },
		{ "mat", "craft", 2, 4.336 }, { "mat", "gem", 2, 3.618 }, { "mat", "craft", 3, 2.562 }, { "mat", "gem", 3, 2.138 },
		{ "gear", "offhand", 2, 30, 2.041 }, { "mat", "craft", 1, 1.971 }, { "mat", "gem", 1, 1.645 }, { "gear", "armor", 4, 30, 1.458 },
		{ "mat", "dust", 2, 1.299 }, { "gear", "weapon", 4, 30, 1.215 }, { "mat", "craft", 4, 0.986 }, { "gear", "offhand", 3, 30, 0.956 },
		{ "gear", "offhand", 1, 30, 0.864 }, { "mat", "gem", 4, 0.822 }, { "mat", "dust", 3, 0.773 }, { "mat", "dust", 1, 0.592 },
		{ "gear", "armor", 5, 30, 0.549 }, { "gear", "weapon", 5, 30, 0.457 }, { "mat", "dust", 4, 0.296 }, { "gear", "offhand", 4, 30, 0.182 },
		{ "mat", "seal", 1, 0.17 }, { "mat", "scroll", 1, 0.169 }, { "gear", "offhand", 5, 30, 0.069 }, { "gear", "armor", 6, 30, 0.061 },
		{ "gear", "weapon", 6, 30, 0.051 }, { "gear", "offhand", 6, 30, 0.008 }, { "gear", "armor", 7, 30, 0.007 }, { "gear", "weapon", 7, 30, 0.006 },
	} },
	[920401] = { kind = "boss", lv = 40, e = {
		{ "mat", "soul", 2, 15.63 }, { "gear", "armor", 2, 40, 12.73 }, { "gear", "weapon", 2, 40, 10.62 }, { "gear", "armor", 3, 40, 7.124 },
		{ "gear", "weapon", 3, 40, 5.938 }, { "gear", "armor", 1, 40, 5.346 }, { "gear", "weapon", 1, 40, 4.455 }, { "mat", "craft", 2, 3.55 },
		{ "mat", "gem", 2, 2.962 }, { "mat", "craft", 3, 2.782 }, { "gear", "armor", 2, 30, 2.547 }, { "mat", "gem", 3, 2.321 },
		{ "gear", "weapon", 2, 30, 2.123 }, { "mat", "craft", 4, 1.631 }, { "gear", "offhand", 2, 40, 1.59 }, { "gear", "armor", 3, 30, 1.425 },
		{ "mat", "gem", 4, 1.361 }, { "mat", "craft", 1, 1.247 }, { "gear", "weapon", 3, 30, 1.187 }, { "gear", "armor", 4, 40, 1.181 },
		{ "mat", "dust", 2, 1.073 }, { "gear", "armor", 1, 30, 1.069 }, { "mat", "gem", 1, 1.041 }, { "gear", "weapon", 4, 40, 0.984 },
		{ "gear", "offhand", 3, 40, 0.891 }, { "gear", "weapon", 1, 30, 0.891 }, { "mat", "dust", 3, 0.833 }, { "gear", "offhand", 1, 40, 0.668 },
		{ "gear", "armor", 5, 40, 0.582 }, { "gear", "weapon", 5, 40, 0.485 }, { "mat", "dust", 4, 0.48 }, { "mat", "dust", 1, 0.384 },
		{ "mat", "craft", 5, 0.384 }, { "mat", "gem", 5, 0.32 }, { "gear", "offhand", 2, 30, 0.318 }, { "gear", "armor", 4, 30, 0.236 },
		{ "gear", "weapon", 4, 30, 0.197 }, { "gear", "offhand", 3, 30, 0.178 }, { "mat", "scroll", 1, 0.168 }, { "gear", "offhand", 4, 40, 0.148 },
		{ "gear", "offhand", 1, 30, 0.134 }, { "gear", "armor", 5, 30, 0.116 }, { "mat", "seal", 1, 0.116 }, { "mat", "dust", 5, 0.112 },
		{ "gear", "weapon", 5, 30, 0.097 }, { "gear", "offhand", 5, 40, 0.073 }, { "gear", "armor", 6, 40, 0.064 }, { "gear", "weapon", 6, 40, 0.054 },
		{ "mat", "seal", 2, 0.053 }, { "gear", "offhand", 4, 30, 0.029 }, { "gear", "offhand", 5, 30, 0.014 }, { "gear", "armor", 6, 30, 0.013 },
		{ "gear", "weapon", 6, 30, 0.011 }, { "gear", "offhand", 6, 40, 0.008 }, { "gear", "armor", 7, 40, 0.008 }, { "gear", "weapon", 7, 40, 0.006 },
		{ "gear", "weapon", 7, 30, 0.002 }, { "gear", "offhand", 7, 40, 0.001 }, { "gear", "offhand", 6, 30, 0.002 }, { "gear", "armor", 7, 30, 0.002 },
	} },
	[920501] = { kind = "boss", lv = 50, e = {
		{ "gear", "armor", 2, 50, 11.71 }, { "gear", "weapon", 2, 50, 9.763 }, { "mat", "soul", 2, 8 }, { "gear", "armor", 3, 50, 7.15 },
		{ "mat", "soul", 3, 6 }, { "gear", "weapon", 3, 50, 5.959 }, { "gear", "armor", 1, 50, 4.793 }, { "gear", "weapon", 1, 50, 3.995 },
		{ "gear", "armor", 2, 40, 3.514 }, { "mat", "craft", 2, 2.967 }, { "mat", "craft", 3, 2.967 }, { "gear", "weapon", 2, 40, 2.929 },
		{ "mat", "gem", 2, 2.475 }, { "mat", "gem", 3, 2.475 }, { "gear", "armor", 3, 40, 2.145 }, { "mat", "craft", 4, 2.01 },
		{ "gear", "weapon", 3, 40, 1.789 }, { "mat", "gem", 4, 1.677 }, { "gear", "offhand", 2, 50, 1.463 }, { "gear", "armor", 1, 40, 1.438 },
		{ "gear", "armor", 4, 50, 1.211 }, { "gear", "weapon", 1, 40, 1.199 }, { "gear", "weapon", 4, 50, 1.009 }, { "gear", "offhand", 3, 50, 0.895 },
		{ "mat", "dust", 2, 0.894 }, { "mat", "dust", 3, 0.894 }, { "mat", "craft", 1, 0.861 }, { "mat", "craft", 5, 0.766 },
		{ "mat", "gem", 1, 0.719 }, { "gear", "armor", 5, 50, 0.675 }, { "mat", "gem", 5, 0.639 }, { "mat", "dust", 4, 0.607 },
		{ "gear", "offhand", 1, 50, 0.599 }, { "gear", "weapon", 5, 50, 0.562 }, { "gear", "offhand", 2, 40, 0.438 }, { "gear", "armor", 4, 40, 0.363 },
		{ "gear", "weapon", 4, 40, 0.303 }, { "gear", "offhand", 3, 40, 0.268 }, { "mat", "dust", 1, 0.255 }, { "mat", "dust", 5, 0.224 },
		{ "gear", "armor", 5, 40, 0.202 }, { "gear", "offhand", 1, 40, 0.18 }, { "gear", "weapon", 5, 40, 0.169 }, { "gear", "offhand", 4, 50, 0.151 },
		{ "mat", "scroll", 1, 0.107 }, { "mat", "seal", 1, 0.106 }, { "gear", "offhand", 5, 50, 0.084 }, { "gear", "armor", 6, 50, 0.075 },
		{ "gear", "weapon", 6, 50, 0.062 }, { "mat", "seal", 2, 0.058 }, { "mat", "scroll", 2, 0.056 }, { "gear", "offhand", 4, 40, 0.045 },
		{ "gear", "offhand", 5, 40, 0.025 }, { "gear", "armor", 6, 40, 0.022 }, { "gear", "weapon", 6, 40, 0.019 }, { "gear", "offhand", 6, 50, 0.009 },
		{ "gear", "armor", 7, 50, 0.008 }, { "gear", "weapon", 7, 50, 0.007 }, { "gear", "weapon", 7, 40, 0.003 }, { "gear", "offhand", 6, 40, 0.003 },
		{ "gear", "armor", 7, 40, 0.002 }, { "gear", "offhand", 7, 50, 0.001 },
	} },
	[920651] = { kind = "boss", lv = 65, e = {
		{ "mat", "soul", 3, 18.8 }, { "gear", "armor", 2, 65, 12.9 }, { "gear", "weapon", 2, 65, 10.75 }, { "gear", "armor", 3, 65, 8.559 },
		{ "gear", "weapon", 3, 65, 7.133 }, { "gear", "armor", 1, 65, 4.933 }, { "gear", "weapon", 1, 65, 4.111 }, { "mat", "craft", 3, 3.803 },
		{ "mat", "gem", 3, 3.173 }, { "mat", "craft", 2, 2.766 }, { "mat", "craft", 4, 2.766 }, { "mat", "gem", 2, 2.307 },
		{ "mat", "gem", 4, 2.307 }, { "gear", "armor", 4, 65, 1.617 }, { "gear", "offhand", 2, 65, 1.611 }, { "gear", "weapon", 4, 65, 1.347 },
		{ "mat", "dust", 3, 1.134 }, { "gear", "offhand", 3, 65, 1.071 }, { "mat", "craft", 5, 1.037 }, { "mat", "gem", 5, 0.865 },
		{ "mat", "dust", 2, 0.827 }, { "mat", "dust", 4, 0.827 }, { "mat", "craft", 1, 0.692 }, { "gear", "offhand", 1, 65, 0.616 },
		{ "mat", "gem", 1, 0.577 }, { "gear", "armor", 5, 65, 0.573 }, { "gear", "weapon", 5, 65, 0.477 }, { "mat", "craft", 6, 0.461 },
		{ "mat", "gem", 6, 0.385 }, { "mat", "dust", 5, 0.308 }, { "mat", "dust", 1, 0.212 }, { "gear", "offhand", 4, 65, 0.203 },
		{ "mat", "dust", 6, 0.154 }, { "gear", "armor", 6, 65, 0.107 }, { "gear", "weapon", 6, 65, 0.089 }, { "gear", "offhand", 5, 65, 0.072 },
		{ "mat", "seal", 1, 0.07 }, { "mat", "scroll", 1, 0.069 }, { "mat", "seal", 2, 0.055 }, { "mat", "scroll", 2, 0.051 },
		{ "mat", "scroll", 3, 0.046 }, { "mat", "seal", 3, 0.045 }, { "mat", "scroll", 4, 0.031 }, { "mat", "seal", 4, 0.03 },
		{ "gear", "offhand", 6, 65, 0.013 }, { "gear", "armor", 7, 65, 0.013 }, { "gear", "weapon", 7, 65, 0.011 }, { "gear", "offhand", 7, 65, 0.001 },
	} },
	[920801] = { kind = "boss", lv = 80, e = {
		{ "mat", "soul", 4, 17.99 }, { "gear", "armor", 2, 80, 10.35 }, { "gear", "weapon", 2, 80, 8.63 }, { "gear", "armor", 3, 80, 7.445 },
		{ "mat", "soul", 3, 7.195 }, { "gear", "weapon", 3, 80, 6.203 }, { "mat", "craft", 3, 4.507 }, { "mat", "gem", 3, 3.745 },
		{ "gear", "armor", 1, 80, 3.62 }, { "mat", "craft", 4, 3.447 }, { "gear", "weapon", 1, 80, 3.017 }, { "mat", "gem", 4, 2.864 },
		{ "mat", "craft", 2, 2.519 }, { "mat", "gem", 2, 2.093 }, { "gear", "armor", 4, 80, 1.525 }, { "mat", "craft", 5, 1.458 },
		{ "mat", "dust", 3, 1.344 }, { "gear", "offhand", 2, 80, 1.293 }, { "gear", "weapon", 4, 80, 1.272 }, { "mat", "gem", 5, 1.212 },
		{ "mat", "dust", 4, 1.035 }, { "gear", "offhand", 3, 80, 0.93 }, { "mat", "craft", 6, 0.928 }, { "mat", "gem", 6, 0.771 },
		{ "mat", "dust", 2, 0.749 }, { "gear", "armor", 5, 80, 0.569 }, { "gear", "weapon", 5, 80, 0.474 }, { "gear", "offhand", 1, 80, 0.453 },
		{ "mat", "dust", 5, 0.441 }, { "mat", "craft", 1, 0.398 }, { "mat", "gem", 1, 0.33 }, { "mat", "dust", 6, 0.286 },
		{ "gear", "offhand", 4, 80, 0.191 }, { "mat", "dust", 1, 0.11 }, { "gear", "offhand", 5, 80, 0.071 }, { "mat", "seal", 3, 0.054 },
		{ "mat", "scroll", 3, 0.053 }, { "mat", "seal", 2, 0.049 }, { "mat", "scroll", 2, 0.048 }, { "mat", "seal", 1, 0.04 },
		{ "mat", "scroll", 1, 0.039 }, { "mat", "scroll", 4, 0.036 }, { "mat", "scroll", 5, 0.036 }, { "mat", "seal", 4, 0.036 },
		{ "mat", "seal", 5, 0.036 }, { "gear", "armor", 6, 80, 0.031 }, { "gear", "weapon", 6, 80, 0.026 }, { "mat", "seal", 6, 0.013 },
		{ "mat", "scroll", 6, 0.014 }, { "gear", "armor", 7, 80, 0.009 }, { "gear", "weapon", 7, 80, 0.008 }, { "gear", "offhand", 6, 80, 0.004 },
		{ "gear", "offhand", 7, 80, 0.001 },
	} },
	[930101] = { kind = "act", lv = 10, e = {
		{ "gear", "weapon", 3, 10, 21.44 }, { "gear", "armor", 3, 10, 21.44 }, { "gear", "trinket", 2, 10, 4.864 }, { "gear", "wrist", 2, 10, 4.864 },
		{ "gear", "weapon", 4, 10, 4.613 }, { "gear", "armor", 4, 10, 4.613 }, { "mat", "craft", 2, 4.5 }, { "mat", "craft", 1, 4.5 },
		{ "mat", "gem", 2, 4.39 }, { "gear", "ring", 2, 10, 3.891 }, { "mat", "gem", 1, 3.841 }, { "gear", "offhand", 3, 10, 2.572 },
		{ "gear", "neck", 2, 10, 2.432 }, { "gear", "trinket", 3, 10, 2.245 }, { "gear", "wrist", 3, 10, 2.245 }, { "gear", "ring", 3, 10, 1.796 },
		{ "gear", "neck", 3, 10, 1.123 }, { "gear", "weapon", 5, 10, 1.085 }, { "gear", "armor", 5, 10, 1.085 }, { "gear", "offhand", 4, 10, 0.554 },
		{ "mat", "gem", 3, 0.549 }, { "gear", "trinket", 4, 10, 0.374 }, { "gear", "wrist", 4, 10, 0.374 }, { "gear", "ring", 4, 10, 0.299 },
		{ "gear", "neck", 4, 10, 0.187 }, { "gear", "offhand", 5, 10, 0.13 },
	} },
	[930201] = { kind = "act", lv = 20, e = {
		{ "gear", "armor", 3, 20, 13.93 }, { "gear", "weapon", 3, 20, 11.61 }, { "gear", "armor", 3, 15, 6.967 }, { "gear", "weapon", 3, 15, 5.812 },
		{ "gear", "trinket", 2, 20, 4.489 }, { "gear", "wrist", 2, 20, 4.489 }, { "mat", "craft", 2, 3.92 }, { "gear", "ring", 2, 20, 3.591 },
		{ "gear", "armor", 4, 20, 3.281 }, { "mat", "gem", 2, 3.224 }, { "mat", "craft", 3, 3.024 }, { "mat", "gem", 3, 3.01 },
		{ "gear", "weapon", 4, 20, 2.734 }, { "mat", "gem", 4, 2.365 }, { "gear", "neck", 2, 20, 2.244 }, { "gear", "trinket", 3, 20, 2.072 },
		{ "gear", "wrist", 3, 20, 2.072 }, { "mat", "craft", 4, 2.016 }, { "gear", "offhand", 3, 20, 1.74 }, { "mat", "dust", 3, 1.72 },
		{ "mat", "dust", 2, 1.72 }, { "gear", "ring", 3, 20, 1.657 }, { "gear", "armor", 4, 15, 1.64 }, { "gear", "weapon", 4, 15, 1.365 },
		{ "mat", "dust", 4, 1.29 }, { "gear", "neck", 3, 20, 1.036 }, { "gear", "armor", 5, 20, 1.002 }, { "gear", "offhand", 3, 15, 0.878 },
		{ "gear", "weapon", 5, 20, 0.835 }, { "gear", "armor", 5, 15, 0.501 }, { "mat", "scroll", 1, 0.489 }, { "mat", "seal", 1, 0.488 },
		{ "gear", "weapon", 5, 15, 0.417 }, { "gear", "offhand", 4, 20, 0.41 }, { "gear", "trinket", 4, 20, 0.345 }, { "gear", "wrist", 4, 20, 0.345 },
		{ "gear", "ring", 4, 20, 0.276 }, { "gear", "offhand", 4, 15, 0.203 }, { "gear", "neck", 4, 20, 0.173 }, { "gear", "armor", 6, 20, 0.138 },
		{ "gear", "offhand", 5, 20, 0.125 }, { "gear", "weapon", 6, 20, 0.115 }, { "gear", "armor", 6, 15, 0.083 }, { "gear", "weapon", 6, 15, 0.069 },
		{ "gear", "offhand", 5, 15, 0.062 }, { "gear", "offhand", 6, 20, 0.017 }, { "gear", "offhand", 6, 15, 0.01 },
	} },
	[930301] = { kind = "act", lv = 30, e = {
		{ "gear", "armor", 3, 30, 15.48 }, { "gear", "weapon", 3, 30, 12.9 }, { "mat", "craft", 3, 4.93 }, { "mat", "gem", 3, 4.866 },
		{ "gear", "trinket", 2, 30, 4.785 }, { "gear", "wrist", 2, 30, 4.785 }, { "gear", "armor", 4, 30, 4.292 }, { "mat", "gem", 4, 3.919 },
		{ "gear", "ring", 2, 30, 3.828 }, { "gear", "weapon", 4, 30, 3.577 }, { "mat", "craft", 4, 3.522 }, { "gear", "trinket", 3, 30, 2.871 },
		{ "gear", "wrist", 3, 30, 2.871 }, { "mat", "craft", 2, 2.817 }, { "mat", "dust", 3, 2.703 }, { "gear", "neck", 2, 30, 2.392 },
		{ "gear", "ring", 3, 30, 2.297 }, { "mat", "dust", 4, 2.162 }, { "mat", "gem", 2, 2.027 }, { "gear", "offhand", 3, 30, 1.934 },
		{ "gear", "armor", 5, 30, 1.502 }, { "gear", "neck", 3, 30, 1.435 }, { "gear", "weapon", 5, 30, 1.252 }, { "mat", "dust", 2, 1.081 },
		{ "gear", "trinket", 4, 30, 0.957 }, { "gear", "wrist", 4, 30, 0.957 }, { "gear", "ring", 4, 30, 0.766 }, { "mat", "scroll", 1, 0.616 },
		{ "gear", "offhand", 4, 30, 0.536 }, { "gear", "neck", 4, 30, 0.478 }, { "mat", "seal", 1, 0.398 }, { "mat", "seal", 2, 0.223 },
		{ "gear", "offhand", 5, 30, 0.188 }, { "gear", "armor", 6, 30, 0.167 }, { "gear", "weapon", 6, 30, 0.139 }, { "gear", "trinket", 5, 30, 0.087 },
		{ "gear", "wrist", 5, 30, 0.087 }, { "gear", "ring", 5, 30, 0.07 }, { "gear", "neck", 5, 30, 0.043 }, { "gear", "offhand", 6, 30, 0.021 },
		{ "gear", "armor", 7, 30, 0.018 }, { "gear", "weapon", 7, 30, 0.016 }, { "gear", "offhand", 7, 30, 0.002 },
	} },
	[930401] = { kind = "act", lv = 40, e = {
		{ "gear", "armor", 3, 40, 12.5 }, { "gear", "weapon", 3, 40, 10.42 }, { "gear", "trinket", 2, 40, 4.763 }, { "gear", "wrist", 2, 40, 4.763 },
		{ "mat", "gem", 4, 3.902 }, { "gear", "ring", 2, 40, 3.81 }, { "mat", "craft", 3, 3.787 }, { "mat", "craft", 4, 3.787 },
		{ "gear", "armor", 4, 40, 3.779 }, { "mat", "gem", 3, 3.499 }, { "gear", "weapon", 4, 40, 3.15 }, { "gear", "trinket", 3, 40, 2.858 },
		{ "gear", "wrist", 3, 40, 2.858 }, { "gear", "armor", 3, 30, 2.5 }, { "gear", "neck", 2, 40, 2.381 }, { "mat", "gem", 5, 2.355 },
		{ "gear", "ring", 3, 40, 2.286 }, { "mat", "dust", 4, 2.153 }, { "mat", "craft", 5, 2.104 }, { "gear", "weapon", 3, 30, 2.08 },
		{ "mat", "dust", 3, 1.951 }, { "gear", "offhand", 3, 40, 1.562 }, { "mat", "craft", 2, 1.543 }, { "gear", "armor", 5, 40, 1.53 },
		{ "gear", "neck", 3, 40, 1.429 }, { "mat", "dust", 5, 1.278 }, { "gear", "weapon", 5, 40, 1.275 }, { "mat", "gem", 2, 1.009 },
		{ "gear", "trinket", 4, 40, 0.953 }, { "gear", "wrist", 4, 40, 0.953 }, { "gear", "ring", 4, 40, 0.762 }, { "gear", "armor", 4, 30, 0.756 },
		{ "gear", "weapon", 4, 30, 0.63 }, { "mat", "dust", 2, 0.538 }, { "gear", "neck", 4, 40, 0.476 }, { "gear", "offhand", 4, 40, 0.472 },
		{ "mat", "seal", 1, 0.329 }, { "mat", "scroll", 1, 0.325 }, { "gear", "offhand", 3, 30, 0.316 }, { "gear", "armor", 5, 30, 0.306 },
		{ "mat", "seal", 2, 0.288 }, { "mat", "scroll", 2, 0.286 }, { "gear", "weapon", 5, 30, 0.255 }, { "gear", "offhand", 5, 40, 0.191 },
		{ "gear", "armor", 6, 40, 0.17 }, { "gear", "weapon", 6, 40, 0.142 }, { "gear", "offhand", 4, 30, 0.094 }, { "gear", "trinket", 5, 40, 0.087 },
		{ "gear", "wrist", 5, 40, 0.087 }, { "gear", "ring", 5, 40, 0.069 }, { "gear", "neck", 5, 40, 0.043 }, { "gear", "offhand", 5, 30, 0.038 },
		{ "gear", "armor", 6, 30, 0.034 }, { "gear", "weapon", 6, 30, 0.028 }, { "gear", "offhand", 6, 40, 0.021 }, { "gear", "armor", 7, 40, 0.019 },
		{ "gear", "weapon", 7, 40, 0.015 }, { "gear", "offhand", 6, 30, 0.004 }, { "gear", "offhand", 7, 40, 0.003 }, { "gear", "weapon", 7, 30, 0.003 },
		{ "gear", "armor", 7, 30, 0.004 },
	} },
	[930451] = { kind = "act", lv = 40, e = {
		{ "gear", "armor", 3, 40, 11.47 }, { "gear", "weapon", 3, 40, 9.566 }, { "mat", "gem", 4, 5.179 }, { "mat", "craft", 4, 5.026 },
		{ "gear", "trinket", 2, 40, 4.763 }, { "gear", "wrist", 2, 40, 4.763 }, { "mat", "craft", 3, 4.282 }, { "mat", "gem", 3, 3.929 },
		{ "gear", "ring", 2, 40, 3.81 }, { "mat", "gem", 5, 3.572 }, { "gear", "armor", 4, 40, 3.512 }, { "mat", "craft", 5, 3.351 },
		{ "gear", "weapon", 4, 40, 2.925 }, { "mat", "dust", 4, 2.858 }, { "gear", "trinket", 3, 40, 2.858 }, { "gear", "wrist", 3, 40, 2.858 },
		{ "gear", "neck", 2, 40, 2.381 }, { "gear", "ring", 3, 40, 2.286 }, { "mat", "dust", 3, 2.143 }, { "mat", "dust", 5, 2 },
		{ "mat", "craft", 2, 1.582 }, { "gear", "armor", 5, 40, 1.547 }, { "gear", "offhand", 3, 40, 1.435 }, { "gear", "neck", 3, 40, 1.429 },
		{ "gear", "weapon", 5, 40, 1.288 }, { "mat", "gem", 2, 1.072 }, { "gear", "trinket", 4, 40, 0.953 }, { "gear", "wrist", 4, 40, 0.953 },
		{ "gear", "ring", 4, 40, 0.762 }, { "mat", "craft", 6, 0.652 }, { "mat", "dust", 2, 0.572 }, { "mat", "gem", 6, 0.536 },
		{ "gear", "neck", 4, 40, 0.476 }, { "mat", "scroll", 2, 0.447 }, { "gear", "offhand", 4, 40, 0.441 }, { "mat", "scroll", 1, 0.364 },
		{ "mat", "seal", 2, 0.301 }, { "mat", "dust", 6, 0.286 }, { "mat", "seal", 3, 0.273 }, { "mat", "seal", 1, 0.244 },
		{ "gear", "offhand", 5, 40, 0.194 }, { "gear", "armor", 6, 40, 0.172 }, { "gear", "weapon", 6, 40, 0.143 }, { "gear", "trinket", 5, 40, 0.087 },
		{ "gear", "wrist", 5, 40, 0.087 }, { "gear", "ring", 5, 40, 0.069 }, { "gear", "neck", 5, 40, 0.043 }, { "gear", "offhand", 6, 40, 0.022 },
		{ "gear", "armor", 7, 40, 0.02 }, { "gear", "weapon", 7, 40, 0.014 }, { "gear", "offhand", 7, 40, 0.003 },
	} },
	[930501] = { kind = "act", lv = 50, e = {
		{ "gear", "armor", 3, 50, 11.27 }, { "gear", "weapon", 3, 50, 9.397 }, { "gear", "trinket", 2, 50, 4.107 }, { "gear", "wrist", 2, 50, 4.107 },
		{ "mat", "craft", 4, 3.741 }, { "gear", "armor", 4, 50, 3.714 }, { "mat", "gem", 4, 3.655 }, { "gear", "armor", 3, 40, 3.382 },
		{ "gear", "ring", 2, 50, 3.286 }, { "gear", "weapon", 4, 50, 3.095 }, { "mat", "gem", 5, 3.057 }, { "gear", "trinket", 3, 50, 2.995 },
		{ "gear", "wrist", 3, 50, 2.995 }, { "mat", "craft", 5, 2.909 }, { "mat", "craft", 3, 2.84 }, { "gear", "weapon", 3, 40, 2.817 },
		{ "mat", "gem", 3, 2.525 }, { "gear", "ring", 3, 50, 2.396 }, { "gear", "neck", 2, 50, 2.054 }, { "mat", "dust", 4, 2.02 },
		{ "mat", "dust", 5, 1.701 }, { "gear", "armor", 5, 50, 1.688 }, { "gear", "neck", 3, 50, 1.497 }, { "gear", "offhand", 3, 50, 1.409 },
		{ "gear", "weapon", 5, 50, 1.407 }, { "mat", "dust", 3, 1.382 }, { "gear", "trinket", 4, 50, 1.198 }, { "gear", "wrist", 4, 50, 1.198 },
		{ "gear", "armor", 4, 40, 1.114 }, { "gear", "ring", 4, 50, 0.958 }, { "gear", "weapon", 4, 40, 0.929 }, { "mat", "craft", 6, 0.831 },
		{ "mat", "gem", 6, 0.798 }, { "mat", "craft", 2, 0.762 }, { "gear", "neck", 4, 50, 0.599 }, { "mat", "gem", 2, 0.598 },
		{ "gear", "armor", 5, 40, 0.506 }, { "gear", "offhand", 4, 50, 0.464 }, { "mat", "dust", 6, 0.425 }, { "gear", "weapon", 5, 40, 0.422 },
		{ "gear", "offhand", 3, 40, 0.421 }, { "mat", "dust", 2, 0.319 }, { "gear", "trinket", 5, 50, 0.257 }, { "gear", "wrist", 5, 50, 0.257 },
		{ "mat", "scroll", 2, 0.244 }, { "mat", "scroll", 3, 0.24 }, { "gear", "offhand", 5, 50, 0.211 }, { "gear", "ring", 5, 50, 0.205 },
		{ "gear", "armor", 6, 50, 0.188 }, { "mat", "seal", 2, 0.177 }, { "mat", "seal", 3, 0.177 }, { "mat", "seal", 4, 0.169 },
		{ "gear", "weapon", 6, 50, 0.156 }, { "gear", "offhand", 4, 40, 0.139 }, { "gear", "neck", 5, 50, 0.128 }, { "mat", "scroll", 1, 0.12 },
		{ "mat", "seal", 1, 0.089 }, { "gear", "offhand", 5, 40, 0.063 }, { "gear", "armor", 6, 40, 0.056 }, { "gear", "weapon", 6, 40, 0.047 },
		{ "gear", "offhand", 6, 50, 0.023 }, { "gear", "armor", 7, 50, 0.02 }, { "gear", "weapon", 7, 50, 0.016 }, { "gear", "offhand", 6, 40, 0.007 },
		{ "gear", "weapon", 7, 40, 0.005 }, { "gear", "armor", 7, 40, 0.006 }, { "gear", "offhand", 7, 50, 0.002 }, { "gear", "offhand", 7, 40, 0.001 },
	} },
	[930601] = { kind = "act", lv = 50, e = {
		{ "gear", "armor", 3, 50, 7.142 }, { "mat", "gem", 5, 6.616 }, { "mat", "craft", 4, 6.534 }, { "gear", "weapon", 3, 50, 5.955 },
		{ "mat", "craft", 5, 5.929 }, { "mat", "gem", 4, 5.688 }, { "gear", "trinket", 2, 50, 4.107 }, { "gear", "wrist", 2, 50, 4.107 },
		{ "mat", "dust", 5, 3.622 }, { "mat", "craft", 3, 3.388 }, { "gear", "ring", 2, 50, 3.286 }, { "mat", "dust", 4, 3.157 },
		{ "gear", "trinket", 3, 50, 2.995 }, { "gear", "wrist", 3, 50, 2.995 }, { "mat", "gem", 3, 2.902 }, { "mat", "gem", 6, 2.902 },
		{ "mat", "craft", 6, 2.783 }, { "gear", "armor", 4, 50, 2.414 }, { "gear", "ring", 3, 50, 2.396 }, { "gear", "neck", 2, 50, 2.054 },
		{ "gear", "weapon", 4, 50, 2.011 }, { "mat", "dust", 3, 1.579 }, { "mat", "dust", 6, 1.579 }, { "gear", "neck", 3, 50, 1.497 },
		{ "gear", "armor", 5, 50, 1.262 }, { "gear", "trinket", 4, 50, 1.198 }, { "gear", "wrist", 4, 50, 1.198 }, { "gear", "weapon", 5, 50, 1.051 },
		{ "gear", "ring", 4, 50, 0.958 }, { "gear", "offhand", 3, 50, 0.892 }, { "mat", "craft", 2, 0.726 }, { "gear", "neck", 4, 50, 0.599 },
		{ "mat", "gem", 2, 0.464 }, { "mat", "seal", 3, 0.356 }, { "mat", "scroll", 3, 0.349 }, { "mat", "seal", 4, 0.341 },
		{ "mat", "scroll", 4, 0.338 }, { "gear", "offhand", 4, 50, 0.303 }, { "mat", "seal", 2, 0.302 }, { "mat", "scroll", 2, 0.297 },
		{ "mat", "dust", 2, 0.279 }, { "gear", "trinket", 5, 50, 0.257 }, { "gear", "wrist", 5, 50, 0.257 }, { "gear", "ring", 5, 50, 0.205 },
		{ "gear", "offhand", 5, 50, 0.158 }, { "gear", "armor", 6, 50, 0.14 }, { "gear", "neck", 5, 50, 0.128 }, { "gear", "weapon", 6, 50, 0.117 },
		{ "mat", "scroll", 1, 0.07 }, { "mat", "seal", 1, 0.07 }, { "gear", "offhand", 6, 50, 0.018 }, { "gear", "armor", 7, 50, 0.016 },
		{ "gear", "weapon", 7, 50, 0.013 }, { "gear", "offhand", 7, 50, 0.003 },
	} },
	[930651] = { kind = "act", lv = 65, e = {
		{ "gear", "armor", 3, 65, 11.36 }, { "gear", "weapon", 3, 65, 9.465 }, { "gear", "trinket", 2, 65, 4.661 }, { "gear", "wrist", 2, 65, 4.661 },
		{ "mat", "gem", 5, 4.399 }, { "gear", "armor", 4, 65, 4.132 }, { "mat", "craft", 5, 4.108 }, { "mat", "craft", 4, 4.108 },
		{ "gear", "ring", 2, 65, 3.729 }, { "mat", "gem", 4, 3.716 }, { "gear", "weapon", 4, 65, 3.443 }, { "gear", "trinket", 3, 65, 3.399 },
		{ "gear", "wrist", 3, 65, 3.399 }, { "gear", "ring", 3, 65, 2.719 }, { "mat", "dust", 5, 2.427 }, { "gear", "neck", 2, 65, 2.331 },
		{ "mat", "gem", 6, 2.275 }, { "gear", "armor", 5, 65, 2.201 }, { "mat", "craft", 6, 2.133 }, { "mat", "dust", 4, 2.063 },
		{ "mat", "craft", 3, 1.975 }, { "gear", "weapon", 5, 65, 1.834 }, { "gear", "neck", 3, 65, 1.699 }, { "mat", "gem", 3, 1.517 },
		{ "gear", "offhand", 3, 65, 1.421 }, { "gear", "trinket", 4, 65, 1.359 }, { "gear", "wrist", 4, 65, 1.359 }, { "mat", "dust", 6, 1.213 },
		{ "gear", "ring", 4, 65, 1.088 }, { "mat", "dust", 3, 0.849 }, { "gear", "neck", 4, 65, 0.68 }, { "mat", "seal", 1, 0.663 },
		{ "mat", "scroll", 1, 0.663 }, { "gear", "offhand", 4, 65, 0.517 }, { "mat", "craft", 2, 0.316 }, { "gear", "trinket", 5, 65, 0.291 },
		{ "gear", "wrist", 5, 65, 0.291 }, { "gear", "offhand", 5, 65, 0.275 }, { "gear", "armor", 6, 65, 0.244 }, { "gear", "ring", 5, 65, 0.233 },
		{ "mat", "gem", 2, 0.228 }, { "gear", "weapon", 6, 65, 0.204 }, { "gear", "neck", 5, 65, 0.146 }, { "mat", "dust", 2, 0.121 },
		{ "gear", "offhand", 6, 65, 0.031 }, { "gear", "armor", 7, 65, 0.026 }, { "gear", "weapon", 7, 65, 0.022 }, { "gear", "offhand", 7, 65, 0.004 },
	} },
	[930701] = { kind = "act", lv = 65, e = {
		{ "gear", "armor", 3, 65, 9.511 }, { "gear", "weapon", 3, 65, 7.921 }, { "mat", "gem", 5, 5.279 }, { "mat", "craft", 5, 5.045 },
		{ "mat", "craft", 4, 4.495 }, { "mat", "gem", 4, 4.223 }, { "gear", "trinket", 2, 65, 4.176 }, { "gear", "wrist", 2, 65, 4.176 },
		{ "gear", "trinket", 3, 65, 3.593 }, { "gear", "wrist", 3, 65, 3.593 }, { "gear", "armor", 4, 65, 3.505 }, { "gear", "ring", 2, 65, 3.34 },
		{ "gear", "weapon", 4, 65, 2.921 }, { "mat", "gem", 6, 2.904 }, { "mat", "dust", 5, 2.886 }, { "gear", "ring", 3, 65, 2.874 },
		{ "mat", "craft", 6, 2.844 }, { "mat", "dust", 4, 2.323 }, { "gear", "neck", 2, 65, 2.088 }, { "mat", "craft", 3, 2.018 },
		{ "gear", "armor", 5, 65, 1.981 }, { "gear", "neck", 3, 65, 1.796 }, { "gear", "weapon", 5, 65, 1.651 }, { "mat", "dust", 6, 1.619 },
		{ "mat", "gem", 3, 1.496 }, { "gear", "trinket", 4, 65, 1.403 }, { "gear", "wrist", 4, 65, 1.403 }, { "gear", "offhand", 3, 65, 1.186 },
		{ "gear", "ring", 4, 65, 1.122 }, { "mat", "dust", 3, 0.845 }, { "gear", "neck", 4, 65, 0.701 }, { "gear", "trinket", 5, 65, 0.486 },
		{ "gear", "wrist", 5, 65, 0.486 }, { "gear", "offhand", 4, 65, 0.439 }, { "gear", "ring", 5, 65, 0.388 }, { "mat", "craft", 2, 0.275 },
		{ "gear", "offhand", 5, 65, 0.248 }, { "gear", "neck", 5, 65, 0.243 }, { "gear", "armor", 6, 65, 0.22 }, { "mat", "seal", 3, 0.21 },
		{ "mat", "scroll", 3, 0.207 }, { "mat", "seal", 4, 0.205 }, { "mat", "seal", 5, 0.205 }, { "mat", "scroll", 4, 0.202 },
		{ "mat", "scroll", 5, 0.202 }, { "gear", "weapon", 6, 65, 0.184 }, { "mat", "gem", 2, 0.176 }, { "mat", "seal", 2, 0.156 },
		{ "mat", "scroll", 2, 0.152 }, { "mat", "dust", 2, 0.07 }, { "gear", "trinket", 6, 65, 0.054 }, { "gear", "wrist", 6, 65, 0.054 },
		{ "gear", "ring", 6, 65, 0.043 }, { "mat", "scroll", 1, 0.036 }, { "mat", "seal", 1, 0.036 }, { "gear", "offhand", 6, 65, 0.028 },
		{ "gear", "neck", 6, 65, 0.027 }, { "gear", "armor", 7, 65, 0.024 }, { "gear", "weapon", 7, 65, 0.021 }, { "gear", "offhand", 7, 65, 0.006 },
	} },
	[930851] = { kind = "act", lv = 80, e = {
		{ "gear", "armor", 3, 80, 9.456 }, { "gear", "weapon", 3, 80, 7.876 }, { "mat", "craft", 5, 4.833 }, { "mat", "gem", 5, 4.805 },
		{ "gear", "trinket", 2, 80, 4.176 }, { "gear", "wrist", 2, 80, 4.176 }, { "gear", "armor", 4, 80, 3.854 }, { "mat", "craft", 4, 3.603 },
		{ "mat", "craft", 6, 3.603 }, { "gear", "trinket", 3, 80, 3.593 }, { "gear", "wrist", 3, 80, 3.593 }, { "mat", "gem", 4, 3.456 },
		{ "mat", "gem", 6, 3.372 }, { "gear", "ring", 2, 80, 3.34 }, { "gear", "weapon", 4, 80, 3.21 }, { "gear", "ring", 3, 80, 2.874 },
		{ "mat", "dust", 5, 2.63 }, { "gear", "armor", 5, 80, 2.449 }, { "gear", "neck", 2, 80, 2.088 }, { "gear", "weapon", 5, 80, 2.04 },
		{ "mat", "dust", 4, 1.888 }, { "mat", "dust", 6, 1.888 }, { "gear", "neck", 3, 80, 1.796 }, { "gear", "trinket", 4, 80, 1.403 },
		{ "gear", "wrist", 4, 80, 1.403 }, { "mat", "craft", 3, 1.23 }, { "gear", "offhand", 3, 80, 1.178 }, { "gear", "ring", 4, 80, 1.122 },
		{ "mat", "gem", 3, 1.012 }, { "mat", "gem", 7, 0.843 }, { "mat", "craft", 7, 0.791 }, { "gear", "neck", 4, 80, 0.701 },
		{ "mat", "dust", 3, 0.539 }, { "gear", "trinket", 5, 80, 0.486 }, { "gear", "wrist", 5, 80, 0.486 }, { "gear", "offhand", 4, 80, 0.483 },
		{ "mat", "dust", 7, 0.472 }, { "gear", "ring", 5, 80, 0.388 }, { "gear", "offhand", 5, 80, 0.307 }, { "gear", "armor", 6, 80, 0.272 },
		{ "gear", "neck", 5, 80, 0.243 }, { "gear", "weapon", 6, 80, 0.227 }, { "mat", "seal", 3, 0.189 }, { "mat", "scroll", 3, 0.187 },
		{ "mat", "seal", 4, 0.185 }, { "mat", "seal", 5, 0.185 }, { "mat", "scroll", 4, 0.182 }, { "mat", "scroll", 5, 0.182 },
		{ "mat", "seal", 2, 0.116 }, { "mat", "scroll", 2, 0.113 }, { "mat", "seal", 6, 0.073 }, { "mat", "scroll", 6, 0.071 },
		{ "gear", "trinket", 6, 80, 0.054 }, { "gear", "wrist", 6, 80, 0.054 }, { "gear", "ring", 6, 80, 0.043 }, { "gear", "offhand", 6, 80, 0.034 },
		{ "gear", "armor", 7, 80, 0.03 }, { "gear", "weapon", 7, 80, 0.027 }, { "mat", "seal", 1, 0.027 }, { "mat", "scroll", 1, 0.027 },
		{ "gear", "neck", 6, 80, 0.027 }, { "gear", "offhand", 7, 80, 0.006 }, { "mat", "scroll", 7, 0.001 },
	} },
	[930901] = { kind = "act", lv = 80, e = {
		{ "gear", "armor", 3, 80, 9.642 }, { "gear", "weapon", 3, 80, 8.035 }, { "mat", "craft", 5, 4.688 }, { "mat", "gem", 5, 4.66 },
		{ "gear", "trinket", 2, 80, 4.176 }, { "gear", "wrist", 2, 80, 4.176 }, { "mat", "craft", 6, 4.006 }, { "gear", "armor", 4, 80, 3.988 },
		{ "mat", "gem", 6, 3.761 }, { "gear", "trinket", 3, 80, 3.593 }, { "gear", "wrist", 3, 80, 3.593 }, { "gear", "ring", 2, 80, 3.34 },
		{ "gear", "weapon", 4, 80, 3.323 }, { "mat", "craft", 4, 3.068 }, { "gear", "ring", 3, 80, 2.874 }, { "mat", "gem", 4, 2.861 },
		{ "gear", "armor", 5, 80, 2.659 }, { "mat", "dust", 5, 2.551 }, { "gear", "weapon", 5, 80, 2.215 }, { "mat", "dust", 6, 2.093 },
		{ "gear", "neck", 2, 80, 2.088 }, { "gear", "neck", 3, 80, 1.796 }, { "mat", "dust", 4, 1.57 }, { "gear", "trinket", 4, 80, 1.403 },
		{ "gear", "wrist", 4, 80, 1.403 }, { "mat", "gem", 7, 1.308 }, { "gear", "offhand", 3, 80, 1.205 }, { "mat", "craft", 7, 1.193 },
		{ "gear", "ring", 4, 80, 1.122 }, { "mat", "dust", 7, 0.719 }, { "gear", "neck", 4, 80, 0.701 }, { "mat", "craft", 3, 0.682 },
		{ "gear", "offhand", 4, 80, 0.503 }, { "mat", "gem", 3, 0.491 }, { "gear", "trinket", 5, 80, 0.486 }, { "gear", "wrist", 5, 80, 0.486 },
		{ "gear", "ring", 5, 80, 0.388 }, { "gear", "offhand", 5, 80, 0.335 }, { "gear", "armor", 6, 80, 0.295 }, { "mat", "dust", 3, 0.262 },
		{ "gear", "weapon", 6, 80, 0.247 }, { "gear", "neck", 5, 80, 0.243 }, { "mat", "seal", 3, 0.185 }, { "mat", "scroll", 3, 0.183 },
		{ "mat", "seal", 4, 0.181 }, { "mat", "seal", 5, 0.181 }, { "mat", "scroll", 4, 0.179 }, { "mat", "scroll", 5, 0.179 },
		{ "mat", "seal", 2, 0.106 }, { "mat", "scroll", 2, 0.105 }, { "mat", "seal", 6, 0.072 }, { "mat", "scroll", 6, 0.07 },
		{ "gear", "trinket", 6, 80, 0.054 }, { "gear", "wrist", 6, 80, 0.054 }, { "gear", "ring", 6, 80, 0.043 }, { "gear", "offhand", 6, 80, 0.037 },
		{ "gear", "armor", 7, 80, 0.032 }, { "gear", "weapon", 7, 80, 0.029 }, { "gear", "neck", 6, 80, 0.027 }, { "mat", "seal", 1, 0.026 },
		{ "mat", "scroll", 1, 0.025 }, { "gear", "offhand", 7, 80, 0.007 }, { "mat", "scroll", 7, 0.001 },
	} },
}

-- the ten grades: random stats, sockets (장식, 세공, 각인), what breaking
-- one down gives (gold, forge experience) and fusion (9 of a grade): the
-- weights of two grades lower .. two grades higher
T.GRADES = {
	{ key = "common", affix = 0, gem = 0, ench = 0, insc = 0, gold = 10, cube = 2, fuse = { 0, 0, 0, 100000, 5000 } },
	{ key = "uncommon", affix = 1, gem = 0, ench = 0, insc = 0, gold = 30, cube = 6, fuse = { 0, 0, 0, 100000, 4000 } },
	{ key = "rare", affix = 1, gem = 1, ench = 0, insc = 0, gold = 90, cube = 18, fuse = { 0, 0, 0, 100000, 2500 } },
	{ key = "legendary", affix = 2, gem = 2, ench = 0, insc = 0, gold = 270, cube = 54, fuse = { 0, 0, 0, 100000, 1000 } },
	{ key = "immortal", affix = 2, gem = 2, ench = 1, insc = 0, gold = 810, cube = 162, fuse = { 0, 0, 100000, 100000, 500 } },
	{ key = "arcana", affix = 3, gem = 2, ench = 1, insc = 1, gold = 2592, cube = 518, fuse = { 0, 0, 100000, 50000, 250 } },
	{ key = "beyond", affix = 3, gem = 2, ench = 2, insc = 1, gold = 8294, cube = 1658, fuse = { 0, 0, 100000, 30000, 100 } },
	{ key = "celestial", affix = 3, gem = 2, ench = 2, insc = 2, gold = 29029, cube = 5803, fuse = { 0, 0, 100000, 20000, 20 } },
	{ key = "divine", affix = 3, gem = 2, ench = 2, insc = 2, gold = 101602, cube = 20311, fuse = { 0, 0, 100000, 10000, 0 } },
	{ key = "cosmic", affix = 3, gem = 2, ench = 2, insc = 2, gold = 355607, cube = 71089, fuse = { 0, 0, 0, 0, 0 } },
}
