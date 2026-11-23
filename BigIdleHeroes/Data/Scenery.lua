-- Scenery behind the battle: each outdoor place's own trees, rocks and
-- plants (the game's world models, by file id), picked by hand from the
-- place's folders, in three rows: far (its trees, dim), mid (smaller trees
-- and rocks) and near (bushes, plants, stumps along the ground); no graves,
-- fences or buildings. Inside places (a mine, a castle, a crypt, a
-- necropolis) have the dungeon's own props instead: statues, shelves,
-- braziers, tables, pots, eggs (inside = true: smaller, man-sized rows).
local _, ns = ...

ns.SCENERY = {
	elwynn = {
		far = { 189927, 189928, 189929, 189930, 189924, 189925 }, -- elwynntreecanopy01, elwynntreecanopy02, elwynntreecanopy03, elwynntreecanopy04, elwynnpine01, elwynnpine02
		mid = { 189932, 189919, 189920, 189923 }, -- elwynntreemid01, canopylesstree01, canopylesstree02, elwynnfirtree01
		near = { 189692, 189693, 189696, 189698, 189777, 189774, 189939, 189768 }, -- elwynnbush01, elwynnbush02, elwynnbush05, elwynnbush07, elwynnthornbush01, elwynnshrub1, elwynntreestump01, elwynnrock1
	},
	dunmorogh = {
		far = { 203285, 203286, 203287, 203288, 203290, 203255, 203256 }, -- wintertree01, wintertree02, wintertree03, wintertree04, wintertree05, ironforgepine01, ironforgepine02
		mid = { 203276, 203277, 203278, 203279, 203280 }, -- wintermidtree01, wintermidtree02, wintermidtree03, wintersmalltree01, wintersmalltree02
		near = { 203151, 203149, 203265, 203266, 203268 }, -- ironforgesnowybush02, ironforgebush01, ironstump01, ironstump02, ironstump03
	},
	teldrassil = {
		far = { 202050, 202051, 202052, 202053, 202054, 202055, 202056, 202057, 202058 }, -- kalidartree01, kalidartree02, kalidartree03, kalidartree04, kalidartree05, kalidartree06, kalidartree07, kalidartree08, kalidartree09
		mid = { 202053, 202054, 202055 }, -- kalidartree04, kalidartree05, kalidartree06
		near = { 202021, 202022, 202023, 202024, 202059, 202060 }, -- kalidarbush01, kalidarbush02, kalidarbush03, kalidarbush04, kalidartreestump01, kalidartreestump02
	},
	durotar = {
		far = { 201803, 201804, 201805, 201806, 201807, 201808, 201800, 201801, 201802 }, -- durotartree01, durotartree02, durotartree03, durotartree04, durotartree05, durotartree06, durotarpalm01, durotarpalm02, durotarpalm03
		mid = { 338541, 338543, 201783, 201785, 201786, 201788 }, -- durotargreentree03, durotargreentree05, durotarrock01, durotarrock02, durotarrock03, durotarrock04
		near = { 201768, 201769, 201770, 201771, 338535, 338838, 201789, 201790, 201791, 201792 }, -- durotarbush01, durotarbush02, durotarbush03, durotarbush04, durotar_lumpygrass01, durotar_lumpygrass02, durotarrock05, durotarrock06, durotarrock07, durotarrock08
	},
	mulgore = {
		far = { 202322, 202323 }, -- mullgoretree01, mullgoretree02
		mid = { 202300, 202301, 202302, 202303, 202323 }, -- mullgorerock01, mullgorerock02, mullgorerock03, mullgorerock04, mullgoretree02
		near = { 202305, 202306, 202307, 202308, 202309, 202310, 202311 }, -- mullgorethorn01, mullgorethorn02, mullgorethorn03, mullgorethorn04, mullgorethorn05, mullgorethorn06, mullgorethorn07
	},
	tirisfal = {
		far = { 204124, 204129, 204130, 204131, 204132, 204133, 204134 }, -- tirisfalgladetree01, tirisfallgladecanopytree02, tirisfallgladecanopytree03, tirisfallgladecanopytree04, tirisfallgladecanopytree05, tirisfallgladecanopytree06, tirisfallgladecanopytree07
		mid = { 204124, 204132, 204133, 204134 }, -- tirisfalgladetree01, tirisfallgladecanopytree05, tirisfallgladecanopytree06, tirisfallgladecanopytree07
		near = { 204097, 204098, 204099, 204101, 204103, 204135, 204136 }, -- tirisfallbush01, tirisfallgladebush03, tirisfallgladebush04, doomweed01, gloomweed01, tirisfalltreestump01, tirisfalltreestump02
	},
	westfall = {
		far = { 190638, 190639, 190640, 190641, 190642 }, -- westfalltree01, westfalltree02, westfalltree03, westfalltree04, westfalltreecanopy01
		mid = { 190623, 190624, 190640 }, -- westfallboulder01, westfallboulder02, westfalltree03
		near = { 190566, 190564, 190577, 190573, 190647 }, -- westfallbush01, westfallberrybush, westfallreeds01, westfalldandilion, westfalltreestump01
	},
	lochmodan = {
		far = { 203347, 203348, 203349, 203350, 203351, 203352, 203353, 203354, 203355 }, -- lochmodantree01, lochmodantree02, lochmodantree03, lochmodantree04, lochmodantree05, lochmodantree06, lochmodantree07, lochmodantree08, lochmodantree09
		mid = { 203351, 203352, 203353 }, -- lochmodantree05, lochmodantree06, lochmodantree07
		near = { 203296, 203297, 203299, 203300, 203316, 203317, 203318, 203319, 203357 }, -- lochmodanshrub01, lochmodanshrub02, lochmodanshrub03, lochmodanshrub04, lochtallgrass01, lochtallgrass02, lochtallgrass03, lochtallgrass04, lochmodantreestump01
	},
	silverpine = {
		far = { 203977, 203979, 203982, 203983 }, -- silverpinetree01, silverpinetree02, silverpinetree03, silverpinetree04
		mid = { 203982, 203983 }, -- silverpinetree03, silverpinetree04
		near = { 203967, 203969, 203971, 203985, 203986 }, -- silverpinebush01, silverpinebush02, silverpinebush03, silverpinetreestump01, silverpinetreestump02
	},
	barrens = {
		far = { 201394, 201396, 201398, 201399, 201400, 201402, 201403, 201405, 201406, 201407 }, -- barrenstree01, barrenstree02, barrenstree03, barrenstree04, barrenstree05, barrenstree06, barrenstree07, barrenstree08, barrenstree09, barrenstree10
		mid = { 304802, 304806, 304810 }, -- barrenstreegreen01, barrenstreegreen02, barrenstreegreen03
		near = { 201370, 201371, 201372 }, -- barrensbush01, barrensbush02, barrensbush03
	},
	redridge = {
		far = { 190121, 190122, 190123, 190124, 190119, 190120 }, -- redridgetreecanopy01, redridgetreecanopy02, redridgetreecanopy03, redridgetreecanopy04, redridgetree01, redridgetree02
		mid = { 190126, 190101, 190102, 190103 }, -- redridgetreemid01, redridgerock01, redridgerock02, redridgerock03
		near = { 190080, 190081, 190082, 190128, 190084 }, -- redridgebush01, redridgebush02, redridgebush03, redridgetreestump01, catailpatch01
	},
	stonetalon = {
		far = { 202620, 202621, 202622, 202623, 202624, 202625, 202626, 202627 }, -- stonetree01, stonetree02, stonetree03, stonetree04, stonetree05, stonetree06, stonetree07, stonetree08
		mid = { 202624, 202625, 202626, 202627, 202614 }, -- stonetree05, stonetree06, stonetree07, stonetree08, stonetalonrockoutcrop01
		near = { 202641, 202642, 202643, 202644, 202633 }, -- stonetreestump01, stonetreestump02, stonetreestump03, stonetreestump04, stonetreelog01
	},
	wailing = {
		far = { 199217, 199218 }, -- wailingplant01, wailingplant02
		mid = { 199226, 199227, 199351, 202176, 202177, 202178 }, -- wailingcavernsraptornest01, wailingcavernsraptornest02, wailingstonebrazier, maraudonshroom01, maraudonshroom02, maraudonshroom03
		near = { 199222, 199223, 199224, 199215, 199220, 202164, 202165, 202166, 202167, 202186, 202187, 202188, 201370, 201371, 201372 }, -- wailingcavernsraptoreggs01, wailingcavernsraptoreggs02, wailingcavernsraptoreggs03, wailingfern06, wailingplantpurple01, maraudondetail01, maraudondetail02, maraudondetail03, maraudondetail04, maraudonroot01, maraudonroot02, maraudonroot03, barrensbush01, barrensbush02, barrensbush03
	},
	ashenvale = {
		far = { 201223, 201224, 201226, 201228, 201230 }, -- ashenvaletree01, ashenvaletree02, ashenvaletree03, ashenvaletree04, ashenvaletree05
		mid = { 201228, 201230, 201195, 201196 }, -- ashenvaletree04, ashenvaletree05, ashenvalerock01, ashenvalerock02
		near = { 201211, 201212, 201197, 201198, 201233 }, -- ashenvaletreestump01, ashenvaletreestump02, ashenvalerock03, ashenvalerock04, ashenvaleplantstardust
	},
	duskwood = {
		far = { 189547, 189551, 189552 }, -- duskwoodspookytree01, duskwoodspookytree02, duskwoodspookytree03
		mid = { 189551, 189552 }, -- duskwoodspookytree02, duskwoodspookytree03
		near = { 189405, 189406, 189407, 189408 }, -- duskwoodspookybush01, duskwoodspookybush02, duskwoodspookybush03, duskwoodspookybush04
	},
	hillsbrad = {
		far = { 203617, 203618, 203619, 203620, 203621, 203622, 203623, 203624, 203688, 203689, 203690 }, -- alteractree01, alteractree02, alteractree03, alteractree04, alteractree06, alteractree07, alteractree08, alteractree09, arathitree01, arathitree02, arathitree03
		mid = { 203611, 203612, 203613, 203691, 203692 }, -- alteracboulder01, alteracboulder02, alteracboulder03, arathitree04, arathitree05
		near = { 203595, 203596, 203597, 203643, 203645, 203646, 203684 }, -- alteracshrub01, alteracshrub02, alteracshrub03, arathiplant01, arathiplant02, arathiplant03, arathistump01
	},
	wetlands = {
		far = { 203543, 203544, 203545, 203546, 203547, 203548 }, -- wetlandtree01, wetlandtree02, wetlandtree03, wetlandtree04, wetlandtree05, wetlandtree06
		mid = { 402678, 203533 }, -- wetland_angledtree_01, wetlandstree04
		near = { 203484, 203485, 203486, 203487, 203488, 203489, 203490, 203491, 203492, 203479, 203480, 203481, 203482, 203483, 203539 }, -- wetlandshrub01, wetlandshrub02, wetlandshrub03, wetlandshrub04, wetlandshrub05, wetlandshrub06, wetlandshrub07, wetlandshrub08, wetlandshrub09, wetlandgrass01, wetlandgrass02, wetlandgrass03, wetlandgrass04, wetlandgrass05, wetlandstreestump01
	},
	needles = {
		far = { 202716, 202718, 202719, 202720, 202721, 202722, 202723, 202724, 202725, 202726, 202727, 202728, 202729, 202730, 202731 }, -- thousandrock01, thousandrock02, thousandrock03, thousandrock04, thousandrock05, thousandrock06, thousandrock07, thousandrock08, thousandrock09, thousandrock10, thousandrock11, thousandrock12, thousandrock13, thousandrock14, thousandrock15
		mid = { 202710, 202711, 202712, 202713 }, -- saltflatrock_01, saltflatrock_02, saltflatrock_03, saltflatrock_04
		near = { 347911, 347912, 347913, 347914, 347915, 347916, 347917, 347918, 347919 }, -- thousandrockbroken01, thousandrockbroken02, thousandrockbroken03, thousandrockbroken04, thousandrockbroken05, thousandrockbroken06, thousandrockbroken07, thousandrockbroken08, thousandrockbroken09
	},
	scarletyard = {
		far = { 204124, 204129, 204130, 204131, 204132, 204133, 204134 }, -- tirisfalgladetree01, tirisfallgladecanopytree02, tirisfallgladecanopytree03, tirisfallgladecanopytree04, tirisfallgladecanopytree05, tirisfallgladecanopytree06, tirisfallgladecanopytree07
		mid = { 204124, 204132, 204133, 204134 }, -- tirisfalgladetree01, tirisfallgladecanopytree05, tirisfallgladecanopytree06, tirisfallgladecanopytree07
		near = { 204097, 204098, 204099, 204101, 204103, 204135, 204136 }, -- tirisfallbush01, tirisfallgladebush03, tirisfallgladebush04, doomweed01, gloomweed01, tirisfalltreestump01, tirisfalltreestump02
	},
	razorfen = {
		far = { 201394, 201396, 201398, 201399, 201400 }, -- barrenstree01, barrenstree02, barrenstree03, barrenstree04, barrenstree05
		mid = { 202300, 202301 }, -- mullgorerock01, mullgorerock02
		near = { 202305, 202306, 202307, 202308, 202309, 202310, 202311, 201370, 201371, 201372 }, -- mullgorethorn01, mullgorethorn02, mullgorethorn03, mullgorethorn04, mullgorethorn05, mullgorethorn06, mullgorethorn07, barrensbush01, barrensbush02, barrensbush03
	},
	arathi = {
		far = { 203688, 203689, 203690, 203691, 203692 }, -- arathitree01, arathitree02, arathitree03, arathitree04, arathitree05
		mid = { 203668, 203669, 203671, 203672, 203673, 203674, 203675, 203676, 203677, 203678 }, -- arathirock01, arathirock02, arathirock03, arathirock04, arathirock05, arathirock06, arathirock07, arathirock08, arathirock09, arathirock10
		near = { 203643, 203645, 203646, 203647, 203650, 203652, 203684, 203686, 203687 }, -- arathiplant01, arathiplant02, arathiplant03, arathiplant04, arathiplant05, arathiplant06, arathistump01, arathistump02, arathistump03
	},
	desolace = {
		far = { 201610, 201611, 201612, 201613 }, -- desolacerock01, desolacerock02, desolacerock03, desolacerock04
		mid = { 201610, 201611, 201612, 201613 }, -- desolacerock01, desolacerock02, desolacerock03, desolacerock04
		near = { 201607 }, -- desolacemushroom
	},
	stranglethorn = {
		far = { 190316, 190319, 190322, 190311 }, -- stranglethorntree01, stranglethorntree02, stranglethorntree04, bootybaytree01
		mid = { 190308, 190322 }, -- strangledeadtree01, stranglethorntree04
		near = { 190228, 190229, 190230, 190231, 190232, 190233, 190235, 190237, 190238, 190239, 190241, 190223, 190224, 190225, 190226, 190227 }, -- stranglethornfern01, stranglethornfern02, stranglethornfern03, stranglethornfern04, stranglethornfern05, stranglethornfern06, stranglethornplant01, stranglethornplant02, stranglethornplant03, stranglethornplant04, stranglethornplant05, strangleplant06, strangleplant07, strangleplant08, strangleplant09, strangleplant10
	},
	badlands = {
		far = { 202975, 202978, 202981, 202983, 202973, 202974 }, -- badlandstree01, badlandstree02, badlandstree03, badlandstree04, badlandspalmtree01, badlandspalmtree02
		mid = { 202940, 202941, 202942, 202943, 202944, 202945, 202946, 202947 }, -- badlandsrock01, badlandsrock02, badlandsrock03, badlandsrock04, badlandsrock05, badlandsrock06, badlandsrock07, badlandsrock08
		near = { 202904, 202905, 202906, 202908, 202910, 202911, 202913, 202914, 202925, 202927, 202928, 202929, 202930, 202931, 202932, 202933, 202934, 202926 }, -- badlandsshrub01, badlandsshrub02, badlandsshrub03, badlandsshrub04, badlandsshrub05, badlandsshrub06, badlandsshrub07, badlandsshrub08, badlandscactus_1, badlandscactus_2, badlandscactus_3, badlandscactus_4, badlandscactus_5, badlandscactus_6, badlandscactus_7, badlandscactus_8, badlandscactus_9, badlandscactus_10
	},
	dustwallow = {
		far = { 201826, 201827, 201828, 201829, 201830, 201831, 201832, 201833 }, -- dustwallowtree01, dustwallowtree02, dustwallowtree03, dustwallowtree04, dustwallowtree05, dustwallowtree06, dustwallowtree07, dustwallowtree08
		mid = { 201830, 201831, 201832, 201833 }, -- dustwallowtree05, dustwallowtree06, dustwallowtree07, dustwallowtree08
		near = { 201811, 201812, 201813, 201814, 201815, 201816 }, -- dustwallowbush01, dustwallowbush02, dustwallowshrub01, dustwallowshrub02, dustwallowshrub03, dustwallowshrub04
	},
	swamp = {
		far = { 190418, 190419, 190420, 190421, 190422, 190423, 190424, 190425 }, -- swampsorrowcanopytree01, swampsorrowcanopytree02, swampsorrowcanopytree03, swampsorrowcanopytree04, swampsorrowcanopytree05, swampsorrowcanopytree06, swampsorrowtree01, swampsorrowtree02
		mid = { 190388, 190389, 190390, 190425 }, -- swampsorrowrock01, swampsorrowrock02, swampsorrowrock03, swampsorrowtree02
		near = { 190377, 190378, 190379, 190380, 190381, 367632, 367633, 367634, 367635 }, -- swampplant03, swampplant04, swampplant05, swampsorrowplant01, swampsorrowplant02, swampsorrowstump01, swampsorrowstump02, swampsorrowstump03, swampsorrowstump04
	},
	feralas = {
		far = { 201935, 201936, 201937, 201938, 201940 }, -- feralastree01, feralastree02, feralastree03, feralastree04, feralastree05
		mid = { 201939, 201933, 201934 }, -- feralastree04_capped, feralasstone01, feralasstone02
		near = { 201930, 201948, 201949 }, -- feralasferns01, feralastreestump01, feralastreestump02
	},
	hinterlands = {
		far = { 203587, 203588, 203589, 203590, 203591, 203580, 203583 }, -- aerietree01, aerietree02, aerietree03, aerietree04, aerietree05, aeriepeaksfir01, aeriepeaksfir02
		mid = { 203558, 203559, 203560, 203561 }, -- aerieboulder01, aerieboulder02, aerieboulder03, aerieboulder04
		near = { 203565, 203566, 203584 }, -- aeriepeaksbush01, aeriepeaksbush02, aeriepeaksstump01
	},
	tanaris = {
		far = { 202677, 202678, 202679, 202680 }, -- tanarisrock01, tanarisrock02, tanarisrock03, tanarisrock04
		mid = { 202681, 202682, 202683 }, -- tanarisrock05, tanarisrock06, tanarisrock07
		near = { 202657, 202658, 202659, 202660, 202661, 202662 }, -- tanariscactus01, tanariscactus02, tanariscactus03, tanariscactus04, tanariscactus05, tanariscactus06
	},
	searing = {
		far = { 189218, 189219, 189220, 189221, 189222, 189223 }, -- lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
		mid = { 189218, 189219, 189220, 189221, 189222, 189223 }, -- lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
		near = { 189218, 189219, 189220, 189221, 189222, 189223 }, -- lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
	},
	zulfarrak = {
		far = { 202677, 202678, 202679, 202680 }, -- tanarisrock01, tanarisrock02, tanarisrock03, tanarisrock04
		mid = { 202681, 202682, 202683 }, -- tanarisrock05, tanarisrock06, tanarisrock07
		near = { 202657, 202658, 202659, 202660, 202661, 202662 }, -- tanariscactus01, tanariscactus02, tanariscactus03, tanariscactus04, tanariscactus05, tanariscactus06
	},
	azshara = {
		far = { 201332, 201333, 201334, 201335, 201336, 201337, 201338 }, -- azr_tree01, azr_tree02, azr_tree03, azr_tree04, azr_tree05, azr_tree06, azr_tree07
		mid = { 201305, 201306, 201307, 201308, 201309 }, -- azshararock01, azshararock02, azshararock03, azshararock04, azshararock05
		near = { 311991, 311992, 312063, 312064, 312828, 312829 }, -- azr_tree_stump_01, azr_tree_stump_02, azr_tree_stump_03, azr_tree_stump_04, azr_tree_stump_05, azr_tree_stump_06
	},
	blasted = {
		far = { 190486, 190487, 190488, 367354, 367446, 367447, 190484, 190485 }, -- blastedlandsblastedtree01, blastedlandsblastedtree03, blastedlandsblastedtree04, blastedlands_twistedtree01, blastedlands_twistedtree02, blastedlands_twistedtree03, blastedlandsashtree02, blastedlandsashtree03
		mid = { 190453, 190454 }, -- blastedlandsrock02, blastedlandsrock03
		near = { 190456, 190457, 190447 }, -- blastedlandsroot01, blastedlandsroot03, blastedlandsrock01
	},
	maraudon = {
		far = { 202092, 202093, 202111, 202112 }, -- maraudoncorruptedtree01, maraudoncorruptedtree02, maraudontransitiontree01, maraudontransitiontree02
		mid = { 202123, 202124, 202125, 202126, 202127, 202128, 202140, 202141, 202142, 202143, 202144 }, -- amethystcrystal01, amethystcrystal02, amethystcrystal03, amethystcrystal04, amethystcrystal05, amethystcrystal06, rubycrystal01, rubycrystal02, rubycrystal03, rubycrystal04, rubycrystal05
		near = { 202176, 202177, 202178, 202164, 202165, 202166, 202167, 202168, 202169, 202170 }, -- maraudonshroom01, maraudonshroom02, maraudonshroom03, maraudondetail01, maraudondetail02, maraudondetail03, maraudondetail04, maraudondetail05, maraudondetail06, maraudondetail07
	},
	ungoro = {
		far = { 202770, 202771, 202772, 202773, 202774, 202775, 202776, 202777, 202778, 202779, 190316, 190319 }, -- ungororock06, ungororock07, ungororock08, ungororock09, ungororock10, ungororock11, ungororock12, ungororock13, ungororock14, ungororock15, stranglethorntree01, stranglethorntree02
		mid = { 202748, 202749, 202750, 202751, 202752, 202753, 202754, 202755 }, -- ungorocrystal_blue01, ungorocrystal_blue02, ungorocrystal_green01, ungorocrystal_green02, ungorocrystal_red01, ungorocrystal_red02, ungorocrystal_yellow01, ungorocrystal_yellow02
		near = { 190228, 190229, 190230, 190231, 190232, 190233, 190235, 190237, 190238 }, -- stranglethornfern01, stranglethornfern02, stranglethornfern03, stranglethornfern04, stranglethornfern05, stranglethornfern06, stranglethornplant01, stranglethornplant02, stranglethornplant03
	},
	felwood = {
		far = { 201900, 201901, 201902, 201903, 201904, 201905, 201906 }, -- felwoodtree01, felwoodtree02, felwoodtree03, felwoodtree04, felwoodtree05, felwoodtree06, felwoodtree07
		mid = { 201913, 201914, 201915, 201916, 201859, 201860 }, -- felwoodtreesub01, felwoodtreesub02, felwoodtreesub03, felwoodtreesub04, felwoodmushroom01, felwoodmushroom02
		near = { 201847, 201849, 201851, 201852, 201912, 201870, 201876 }, -- felwoodbush01, felwoodbush02, felwoodbush03, felwoodbush04, felwoodtreestump01, nightdragon01, windblossom01
	},
	burningsteppes = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189218, 189219, 189220, 189221, 189222, 189223 }, -- lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
		near = { 189218, 189219, 189220, 189221, 189222, 189223 }, -- lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
	},
	plaguelands = {
		far = { 203798, 203799, 203800, 203801, 203802, 203803, 203804, 203805, 203806, 203807, 203808, 203809, 203810 }, -- plaguelandtree01, plaguelandtree02, plaguelandtree03, plaguelandtree04, plaguelandtree05, plaguelandtree06, plaguelandtree07, plaguelandtree08, plaguelandtree09, plaguelandtree10, plaguelandtree11, plaguelandtree12, plaguelandtree13
		mid = { 203773, 203774, 203775, 203776, 203777, 203778, 203779, 203780, 203788, 203789, 203790, 203791 }, -- plaguelandrock01, plaguelandrock02, plaguelandrock03, plaguelandrock04, plaguelandrock05, plaguelandrock06, plaguelandrock07, plaguelandrock08, plaguelandmushroom01, plaguelandmushroom02, plaguelandmushroom03, plaguelandmushroom04
		near = { 203731, 203732, 203733, 203734, 203759, 203760, 203761, 203762, 203793, 203795, 203796, 203797 }, -- plaguelandwesternbush01, plaguelandwesternbush02, plaguelandwesternbush03, plaguelandwesternbush04, plaguelandfern01, plaguelandfern02, plaguelandfern03, plaguelandfern04, plaguelandstump01, plaguelandstump02, plaguelandstump03, plaguelandstump04
	},
	winterspring = {
		far = { 202857, 202858, 202859, 202876, 202877, 202878 }, -- newwinterspringtree01, newwinterspringtree02, newwinterspringtree05, winterspringtree01, winterspringtree02, winterspringtree03
		mid = { 202855, 202856, 202845, 202846, 202847, 202848 }, -- newwinterspringmidtree01, newwinterspringmidtree02, winterspringrock01, winterspringrock02, winterspringrock03, winterspringrock04
		near = { 202868, 202849, 202850, 202851, 202852 }, -- winterspringbush01, winterspringrock05, winterspringrock06, winterspringrock07, winterspringrock08
	},
	diremaul = {
		far = { 201935, 201936, 201937, 201938, 201940, 201732 }, -- feralastree01, feralastree02, feralastree03, feralastree04, feralastree05, gardentreeferalas
		mid = { 201939, 201933, 201934 }, -- feralastree04_capped, feralasstone01, feralasstone02
		near = { 201930, 201948, 201949 }, -- feralasferns01, feralastreestump01, feralastreestump02
	},
	silithus = {
		far = { 202463, 202464, 202465, 202466, 202456, 202457, 202458 }, -- silithus_crystal_clump_01, silithus_crystal_clump_02, silithus_crystal_clump_03, silithus_crystal_clump_04, silithus_commnicationcrystal_01, silithus_commnicationcrystal_02, silithus_commnicationcrystal_03
		mid = { 202477, 202478, 202479, 202480, 202481, 202482 }, -- silithus_crystal_nub_01, silithus_crystal_nub_02, silithus_crystal_nub_03, silithus_crystal_nub_04, silithus_crystal_nub_05, silithus_crystal_nub_06
		near = { 202477, 202478, 202479, 202480, 202481, 202482 }, -- silithus_crystal_nub_01, silithus_crystal_nub_02, silithus_crystal_nub_03, silithus_crystal_nub_04, silithus_crystal_nub_05, silithus_crystal_nub_06
	},
	zulgurub = {
		far = { 190711, 190712, 190713, 190714, 190715, 190316, 190319 }, -- zulgurubtree01, zulgurubtree02, zulgurubtree03, zulgurubtree04, zulgurubtree05, stranglethorntree01, stranglethorntree02
		mid = { 190322, 190308 }, -- stranglethorntree04, strangledeadtree01
		near = { 190228, 190229, 190230, 190231, 190232, 190233, 190235, 190237, 190238, 190239, 190241 }, -- stranglethornfern01, stranglethornfern02, stranglethornfern03, stranglethornfern04, stranglethornfern05, stranglethornfern06, stranglethornplant01, stranglethornplant02, stranglethornplant03, stranglethornplant04, stranglethornplant05
	},
	ahnqiraj = {
		far = { 202463, 202464, 202465, 202466, 202456, 202457, 202458 }, -- silithus_crystal_clump_01, silithus_crystal_clump_02, silithus_crystal_clump_03, silithus_crystal_clump_04, silithus_commnicationcrystal_01, silithus_commnicationcrystal_02, silithus_commnicationcrystal_03
		mid = { 202477, 202478, 202479, 202480, 202481, 202482 }, -- silithus_crystal_nub_01, silithus_crystal_nub_02, silithus_crystal_nub_03, silithus_crystal_nub_04, silithus_crystal_nub_05, silithus_crystal_nub_06
		near = { 202477, 202478, 202479, 202480, 202481, 202482 }, -- silithus_crystal_nub_01, silithus_crystal_nub_02, silithus_crystal_nub_03, silithus_crystal_nub_04, silithus_crystal_nub_05, silithus_crystal_nub_06
	},
	ragefire = {
		far = {  }, -- none
		mid = { 199129, 199155, 203091, 203092, 189218, 189219, 189220, 189221, 189222, 189223 }, -- mediumbrazier01, largefirepit01, dragonkinnest01, dragonkinnest02, lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
		near = { 199179, 199401, 203089, 203090, 189218, 189219, 189220, 189221, 189222, 189223 }, -- jarorc01, skullcandle01, dragonkinegg, dragonkineggbroken, lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
	},
	moltencore = {
		far = {  }, -- none
		mid = { 199129, 199155, 203091, 203092, 189218, 189219, 189220, 189221, 189222, 189223 }, -- mediumbrazier01, largefirepit01, dragonkinnest01, dragonkinnest02, lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
		near = { 199179, 199401, 203089, 203090, 189218, 189219, 189220, 189221, 189222, 189223 }, -- jarorc01, skullcandle01, dragonkinegg, dragonkineggbroken, lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
	},
	onyxia = {
		far = {  }, -- none
		mid = { 199129, 199155, 203091, 203092, 189218, 189219, 189220, 189221, 189222, 189223 }, -- mediumbrazier01, largefirepit01, dragonkinnest01, dragonkinnest02, lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
		near = { 199179, 199401, 203089, 203090, 189218, 189219, 189220, 189221, 189222, 189223 }, -- jarorc01, skullcandle01, dragonkinegg, dragonkineggbroken, lavarock01, lavarock02, lavarock03, lavarock04, lavarock05, lavarock06
	},
	deadmines = {
		inside = true,
		far = { 197789, 197790, 197767 }, -- goblinshreddersuit01, goblinshreddersuit02, goblinmachinery
		mid = { 189282, 197779, 197780, 197760 }, -- goblinmeltingpot, goblinrocketcart01, goblinrocketcart02, goblincontrolpanel
		near = { 198173, 198004, 198158, 198163 }, -- deadminepowderkeg, beerkeg01, crategrain01, graincrate01
	},
	shadowfang = {
		inside = true,
		far = { 198052, 198053, 198054, 198073, 198074 }, -- duskwoodbookshelf01, duskwoodbookshelf02, duskwoodbookshelf03, candelabratall01, candelabratall02
		mid = { 198608, 198609, 198013, 198014 }, -- shadowfangtable01, shadowfangtable02, shadowfangbench01, shadowfangbench02
		near = { 198055, 198016, 198017, 198076 }, -- generalbookstackshort01, booklarge01, booklarge02, generalcandelabra01
	},
	blackfathom = {
		inside = true,
		far = { 201452, 201422 }, -- bfd_statuenagapriestess, bfd_nagabrazier
		mid = { 201424, 201425, 201426, 201422 }, -- bfd_stonechair01, bfd_stonechair02, bfd_stonechair03, bfd_nagabrazier
		near = { 201447, 201448, 201449, 201450, 201445, 201446 }, -- blackfathom_pot01, blackfathom_pot02, blackfathom_pot03, blackfathom_pot04, bfd_brokenpottery01, bfd_brokenpottery02
	},
	scarletlib = {
		inside = true,
		far = { 198047, 198049, 198052, 198053, 198054 }, -- abbeyshelf01, abbeyshelf02, duskwoodbookshelf01, duskwoodbookshelf02, duskwoodbookshelf03
		mid = { 198073, 198074, 198175, 198254, 198407 }, -- candelabratall01, candelabratall02, fancydesk01, globe01, duskwoodpodium01
		near = { 198055, 198056, 198016, 198019, 198076 }, -- generalbookstackshort01, generalbookstacktall01, booklarge01, booklargeopen01, generalcandelabra01
	},
	scarletarmory = {
		inside = true,
		far = { 190924, 190926, 190922, 190918 }, -- statuehmcrusader, statuehmcrusadersoldier, statuehmcaptain, statuehfspear
		mid = { 198636, 198665, 198666, 198612 }, -- generalweaponrack01, generalwoodendummy02, stormwindwoodendummy01, generalrack01
		near = { 198004, 198158, 198643 }, -- beerkeg01, crategrain01, humanarrows
	},
	scarletcathedral = {
		inside = true,
		far = { 190928, 190929, 190925, 190923 }, -- statuehmpaladin, statuehmpriest, statuehmcrusaderclean, statuehmcaptainclean
		mid = { 198390, 197831, 197832, 198073, 198074 }, -- generalchurchpew01, altar01, altar02, candelabratall01, candelabratall02
		near = { 198076, 198019, 198055 }, -- generalcandelabra01, booklargeopen01, generalbookstackshort01
	},
	gnomeregan = {
		inside = true,
		far = { 197678, 197679, 197680, 197681, 197682, 197683 }, -- gnomemachine01, gnomemachine02, gnomemachine03, gnomemachine04, gnomemachine05, gnomemachine06
		mid = { 197671, 197704, 411841, 346124, 197701 }, -- gnomebiggear, gnomeroboarm, gnome_tesla, gnome_engine, gnomehutmachinery
		near = { 197754, 197755, 197756, 197757, 197758, 197759, 197640, 197641, 197642, 197675 }, -- gnometool01, gnometool02, gnometool03, gnometool04, gnometool05, gnometool06, gnomebucket01, gnomebucket02, gnomebucket03, gnomesmallgear
	},
	uldaman = {
		inside = true,
		far = { 203439, 203442, 203440, 203469, 203392, 203393 }, -- uldamandwarfstatue, uldamanstonegiantstatue, uldamanmountaingiantstatue, titanfemalestatue, uldamanbookshelf, uldamanbookshelf01
		mid = { 203397, 203452, 203454, 203404, 203376 }, -- uldamanbrazier01, uldamantable01, uldamantablenew, uldamanlampandpost, uldamanbench01
		near = { 203422, 203423, 203424, 203385, 203386, 203387, 203429, 203425 }, -- uldamanpot01, uldamanpot02, uldamanpot03, uldamanbook01, uldamanbook02, uldamanbook03, uldamanscroll01, uldamanpotbroken01
	},
	sunkentemple = {
		inside = true,
		far = { 200625, 200621, 200623 }, -- snakegargoyle, mummytroll01, skulltiki
		mid = { 190363, 200629, 200638, 200640 }, -- serpentaltar, cobrathrone01, trollskullpile, trolltablet
		near = { 200638, 200633, 200634, 200635, 522970 }, -- trollskullpile, troll_tikimask01, troll_tikimask02, troll_tikimask03, mallskull
	},
	blackrockdepths = {
		inside = true,
		far = { 203024, 203025, 203012, 197210 }, -- statuedarkironthaurissan, statuedarkironthaurissanhammer, darkironforge, darkironthrone
		mid = { 203018, 203010, 197224, 197225, 197155, 197165 }, -- darkironbrazier, darkironanvil, darkironworkbench01, darkironworkbench02, darkirongrindingwheel, darkironkegstand01
		near = { 197162, 197150, 197152, 197137, 197138, 197214 }, -- darkironkeg01, darkironcrate01, darkironcrate02, darkironchair01, darkironchair02, darkironwoodpile01
	},
	blackrockspire = {
		inside = true,
		far = { 199387, 199389, 353154, 353155, 199141 }, -- orctent01, orctent02, orctent03, orctent04, tallbrazier01
		mid = { 199129, 199203, 199357, 199356, 199155 }, -- mediumbrazier01, rawmeatrack01, orctable01, orcbench01, largefirepit01
		near = { 199094, 199095, 199090, 199091, 199179, 199180, 199401 }, -- orccrate01, orccrate02, orcbarrel01, orcbarrel03, jarorc01, jarorc02, skullcandle01
	},
	blackwing = {
		inside = true,
		far = { 203057, 203058, 203059, 203060 }, -- blackrockbloodmachine01, blackrockbloodmachine02, blackrockbloodmachine03, blackrockbloodmachine04
		mid = { 203091, 203092, 203093, 203061 }, -- dragonkinnest01, dragonkinnest02, dragonkinnest03, blackrockbloodvile
		near = { 203089, 203090, 203094 }, -- dragonkinegg, dragonkineggbroken, dragonkinnestclump01
	},
	gordok = {
		inside = true,
		far = { 199025, 201696, 201705, 201706, 201707, 201708 }, -- ogrethrone, diremaulogrescaffolding01, diremaulstonestatue01, diremaulstonestatue02, diremaulstonestatue03, diremaulstonestatue04
		mid = { 201688, 201691, 201692, 201693, 201694, 198989, 198990 }, -- ogrecampfire01, diremaulogrepost01, diremaulogrepost02, diremaulogrepost03, diremaulogrepost04, ogrebackpack01, ogrebackpack02
		near = { 201699, 201700, 201701, 201702, 201703, 201704 }, -- diremaulfloorrubble01, diremaulfloorrubble02, diremaulfloorrubble03, diremaulgroundrubble01, diremaulgroundrubble02, diremaulgroundrubble03
	},
	highborne = {
		inside = true,
		far = { 201679, 201680, 201681, 201705, 201706, 201707, 201708, 201638 }, -- goldenhighelfstatue01, goldenhighelfstatue02, goldenhighelfstatue03, diremaulstonestatue01, diremaulstonestatue02, diremaulstonestatue03, diremaulstonestatue04, diremaulcrystalgenerator
		mid = { 201617, 201618, 201643, 201641 }, -- corruptedcrystalshard, corruptedcrystalshard_blue, nightmarestone, nightmarebell
		near = { 201699, 201700, 201701, 201642 }, -- diremaulfloorrubble01, diremaulfloorrubble02, diremaulfloorrubble03, nightmarecandle
	},
	scholomance = {
		inside = true,
		far = { 203836, 203837, 203861, 203862, 203864 }, -- scholme_bookshelf, scholme_bookshelflarge, scholme_candelabra, scholme_candelabra02, scholme_greencandelabra
		mid = { 203881, 203883, 203886, 203895, 203841, 203845 }, -- greenbubblingcauldron, redbubblingcauldron, yellowbubblingcauldron, creepyoperationtable01, scholomancebrazier01green, scholomancebrazier01purple
		near = { 203912, 203913, 203911, 203892, 203838, 203848 }, -- ghoul_in_a_jar, skeleton_in_a_jar, empty_testing_jar, scholomancecrystalball01, scholme_bookshelfsmall, floorcandlescorner01green
	},
	stratholme = {
		inside = true,
		far = { 198319, 198320, 200754, 200755, 200756 }, -- westernplaguelandslampost01, westernplaguelandslampost02, lordaeron_statue_01, lordaeron_statue_02, lordaeron_statue_03
		mid = { 200666, 204011, 200655, 200652 }, -- meatwagonwrecked01, stratholmepostboxruined, lordaeronbrazier01, lordaeron_bench_01
		near = { 198321, 326458, 200672 }, -- westernplaguelandslampostbroken01, undeadzigguratskulls, meatwagonwheel
	},
	stratslaughter = {
		inside = true,
		far = { 200664, 200784, 204006 }, -- meatwagon, undead_teslacoil, furnace_skull01
		mid = { 200782, 200786, 200767, 200772, 200778 }, -- undead_operation_table, undead_tools_table, undead_alchemy_table, undead_crankwheel, undeadhookbody01
		near = { 326458, 200670, 200781 }, -- undeadzigguratskulls, meatwagongrill, undead_meter
	},
	aqtemple = {
		inside = true,
		far = { 202553, 202533, 202442, 202429 }, -- quirajpillar, obsidianstatue, ahn_qirajobelisk, ahnqirajalter
		mid = { 202508, 202509, 202554, 202413 }, -- silithidgong, silithidgongpodium, quirajpillarbroken, ahnqirajegglayer
		near = { 202490, 202555, 202556, 202582, 202589 }, -- silithidegg, quirajruinblock01, quirajruinblock02, silithidtankhuskhead, silithidwasphuskhead
	},
	naxxramas = {
		inside = true,
		far = { 204019, 200784, 204065, 204006 }, -- nox_tesla, undead_teslacoil, kelthuzad_throne, furnace_skull01
		mid = { 200782, 200767, 204013, 204024 }, -- undead_operation_table, undead_alchemy_table, plaguewingsporetrap, nox_anvil
		near = { 326458, 203913, 203912, 203911 }, -- undeadzigguratskulls, skeleton_in_a_jar, ghoul_in_a_jar, empty_testing_jar
	},
}

-- the place of each stage, by difficulty and stage (1..30)
ns.STAGE_SCENERY = {
	{ -- 일반
		"elwynn", "dunmorogh", "teldrassil", "durotar", "mulgore", "tirisfal", "westfall", "lochmodan", "silverpine", "barrens",
		"ragefire", "redridge", "stonetalon", "wailing", "deadmines", "ashenvale", "duskwood", "hillsbrad", "wetlands", "shadowfang",
		"blackfathom", "needles", "scarletyard", "gnomeregan", "razorfen", "scarletlib", "arathi", "desolace", "stranglethorn", "scarletarmory",
	},
	{ -- 영웅
		"badlands", "dustwallow", "swamp", "scarletcathedral", "razorfen", "feralas", "hinterlands", "tanaris", "uldaman", "uldaman",
		"searing", "zulfarrak", "azshara", "blasted", "maraudon", "maraudon", "ungoro", "felwood", "burningsteppes", "sunkentemple",
		"plaguelands", "blackrockdepths", "blackrockdepths", "blackrockdepths", "winterspring", "plaguelands", "diremaul", "silithus", "blackrockspire", "blackrockspire",
	},
	{ -- 신화
		"gordok", "highborne", "scholomance", "stratholme", "blackrockspire", "scholomance", "scholomance", "stratslaughter", "blackrockspire", "blackrockspire",
		"zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub",
		"silithus", "silithus", "ahnqiraj", "ahnqiraj", "ahnqiraj", "ahnqiraj", "ahnqiraj", "ahnqiraj", "azshara", "blasted",
	},
	{ -- 신화+
		"moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore",
		"onyxia", "blackwing", "blackwing", "blackwing", "blackwing", "blackwing", "aqtemple", "aqtemple", "aqtemple", "aqtemple",
		"naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas",
	},
}

function ns.SceneryKey(diff, idx)
	local row = ns.STAGE_SCENERY[diff]
	return row and row[idx]
end

function ns.SceneryFor(diff, idx)
	return ns.SCENERY[ns.SceneryKey(diff, idx) or ""]
end

-- Behind the scenery: a picture of the place (Media/Scenes/<place>.tga), a
-- strip cut from a screenshot of it in the game.
ns.BACKDROPS = {
	ahnqiraj = true, aqtemple = true, arathi = true, ashenvale = true, azshara = true, badlands = true,
	barrens = true, blackfathom = true, blackrockdepths = true, blackrockspire = true, blackwing = true,
	blasted = true, burningsteppes = true, deadmines = true, desolace = true, diremaul = true, dunmorogh = true,
	durotar = true, duskwood = true, dustwallow = true, elwynn = true, felwood = true, feralas = true,
	gnomeregan = true, hillsbrad = true, hinterlands = true, lochmodan = true, maraudon = true,
	moltencore = true, mulgore = true, naxxramas = true, needles = true, onyxia = true, plaguelands = true,
	ragefire = true, razorfen = true, redridge = true, scarlet = true, scholomance = true,
	searing = true, shadowfang = true, silithus = true, silverpine = true, stonetalon = true,
	stranglethorn = true, stratholme = true, sunkentemple = true, swamp = true, tanaris = true,
	teldrassil = true, tirisfal = true, uldaman = true, ungoro = true, wailing = true, westfall = true,
	wetlands = true, winterspring = true, zulfarrak = true, zulgurub = true,
}

-- places shown with another's picture (the same place seen elsewhere)
ns.BACKDROP_SAME = {
	scarletyard = "tirisfal", gordok = "diremaul", highborne = "diremaul",
	scarletlib = "scarlet", scarletarmory = "scarlet", scarletcathedral = "scarlet", stratslaughter = "stratholme",
}

function ns.BackdropFile(diff, idx)
	local key = ns.SceneryKey(diff, idx)
	key = key and (ns.BACKDROP_SAME[key] or key)
	return key and ns.BACKDROPS[key] and ("Interface\\AddOns\\BigIdleHeroes\\Media\\Scenes\\" .. key .. ".tga") or nil
end

-- The ground under the fight: the place's own terrain (or floor) texture,
-- by file id; it tiles and goes by as the party walks.
ns.GROUND = {
	ahnqiraj = 127796, aqtemple = 127824, arathi = 186818, ashenvale = 186832, azshara = 186864,
	badlands = 188878, barrens = 186908, blackfathom = 126988, blackrockdepths = 127718,
	blackrockspire = 127709, blackwing = 127712, blasted = 188906, burningsteppes = 186933, deadmines = 127336,
	desolace = 187001, diremaul = 127803, dunmorogh = 188573, durotar = 187017, duskwood = 187084,
	dustwallow = 187053, elwynn = 187126, felwood = 188474, feralas = 188505, gnomeregan = 127890,
	gordok = 127806, highborne = 127804, hillsbrad = 186781, hinterlands = 186769, lochmodan = 188615,
	maraudon = 127819, moltencore = 186959, mulgore = 188654, naxxramas = 127851, needles = 188929,
	onyxia = 186954, plaguelands = 188736, ragefire = 186933, razorfen = 188746, redridge = 188756,
	scarletarmory = 127923, scarletcathedral = 127924, scarletlib = 127922, scarletyard = 188954,
	scholomance = 127762, searing = 186952, shadowfang = 127752, silithus = 188779, silverpine = 188791,
	stonetalon = 188805, stranglethorn = 188821, stratholme = 127975, stratslaughter = 127763,
	sunkentemple = 127831, swamp = 188840, tanaris = 188870, teldrassil = 188589, tirisfal = 188954,
	uldaman = 127782, ungoro = 188975, wailing = 186899, westfall = 188991, wetlands = 189021,
	winterspring = 189051, zulfarrak = 188872, zulgurub = 189066,
}

function ns.GroundFile(diff, idx)
	local key = ns.SceneryKey(diff, idx)
	return key and ns.GROUND[key]
end
