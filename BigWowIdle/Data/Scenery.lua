-- Scenery behind the battle: the game's own terrain models (trees, rocks,
-- ruins, plants) of each place, by file id, in three rows: far (tall, in
-- the haze), mid and near (low, along the ground). They drift past while
-- the party walks on between waves.
local _, ns = ...

ns.SCENERY = {
	elwynn = {
		far = { 189898, 189921, 189924, 189928, 189932 }, -- battlegladespinehumandark, canopylesstree03, elwynnpine01, elwynntreecanopy02, elwynntreemid01
		mid = { 189629, 189686, 189750, 189795, 189906, 189924 }, -- humanguardtower, battlegladeskullorc2, elwynndetailrock02, elwynnwoodfence01, spike, elwynnpine01
		near = { 189692, 189697, 189744, 189754, 189777, 189916 }, -- elwynnbush01, elwynnbush06, elwynndetailgrass01, elwynngrass01, elwynnthornbush01, elwynnlog02
	},
	dunmorogh = {
		far = { 203276, 203278, 203280, 203286, 203288 }, -- wintermidtree01, wintermidtree03, wintersmalltree02, wintertree02, wintertree04
		mid = { 203136, 203160, 203209, 203277, 203280, 203287 }, -- runestonesnow_01, dunmoroghstonefence03, snowytowerrock02, wintermidtree02, wintersmalltree02, wintertree03
		near = { 203265, 203266, 203268, 203269, 203270 }, -- ironstump01, ironstump02, ironstump03, ironstump04, ironstump05
	},
	teldrassil = {
		far = { 202013, 202048, 202052, 202056, 202059 }, -- felpinecone, kalidarfallentree01, kalidartree03, kalidartree07, kalidartreestump01
		mid = { 202013, 202018, 202048, 202052, 202056, 202059 }, -- felpinecone, furbolgtotem01, kalidarfallentree01, kalidartree03, kalidartree07, kalidartreestump01
		near = { 202021, 202022, 202024, 202035, 202038, 202040 }, -- kalidarbush01, kalidarbush02, kalidarbush04, kalidargiantroot02, kalidarroots01, kalidarroots03
	},
	durotar = {
		far = { 201800, 201803, 201807, 338541, 368834 }, -- durotarpalm01, durotartree01, durotartree05, durotargreentree03, durotarpalmfallen04
		mid = { 201774, 201779, 201788, 201800, 201806, 368831 }, -- durotarcliffrock01, durotarcliffrock06, durotarrock04, durotarpalm01, durotartree04, durotarpalmfallen01
		near = { 201766, 201768, 201770, 201771, 338537, 338538 }, -- cactusapple01, durotarbush01, durotarbush03, durotarbush04, durotar_marshgrass01, durotar_marshgrass02
	},
	mulgore = {
		far = { 202297, 202321, 202322, 202323 }, -- pinecone, mullgorefallentree01, mullgoretree01, mullgoretree02
		mid = { 202297, 202298, 202301, 202303, 202312, 202322 }, -- pinecone, mullgorerockarch, mullgorerock02, mullgorerock04, mullgorethornspike, mullgoretree01
		near = { 202305, 202306, 202307, 202308, 202309, 202310 }, -- mullgorethorn01, mullgorethorn02, mullgorethorn03, mullgorethorn04, mullgorethorn05, mullgorethorn06
	},
	tirisfal = {
		far = { 204124, 204126, 204129, 204131, 204134 }, -- tirisfalgladetree01, tirisfallfallentree02, tirisfallgladecanopytree02, tirisfallgladecanopytree04, tirisfallgladecanopytree07
		mid = { 204090, 204108, 204117, 204122, 204128, 204133 }, -- massgrave, brillgraves04, tirisfalloutpost02, tirisfalloutpost07, tirisfallfallentree04, tirisfallgladecanopytree06
		near = { 204097, 204098, 204099, 204101, 204103 }, -- tirisfallbush01, tirisfallgladebush03, tirisfallgladebush04, doomweed01, gloomweed01
	},
	westfall = {
		far = { 190638, 190639, 190640, 190642, 190647 }, -- westfalltree01, westfalltree02, westfalltree03, westfalltreecanopy01, westfalltreestump01
		mid = { 190519, 190525, 190633, 190639, 190647, 190666 }, -- westfallwindmill, aquaduct_pillar3, tombstone01, westfalltree02, westfalltreestump01, westfallruins01
		near = { 190564, 190566, 190577, 190675 }, -- westfallberrybush, westfallbush01, westfallreeds01, westfallvineyard01
	},
	lochmodan = {
		far = { 203343, 203348, 203351, 203353, 203356 }, -- lochmodanfallentree01, lochmodantree02, lochmodantree05, lochmodantree07, lochmodantreelog01
		mid = { 203307, 203313, 203327, 203333, 203347, 203353 }, -- lochmodanstonefence01, lochmodanwoodfence03, titanruinshead01, titanruinswall01, lochmodantree01, lochmodantree07
		near = { 203296, 203299, 203301, 203317, 203319, 203362 }, -- lochmodanshrub01, lochmodanshrub03, lochmodanshrub06, lochtallgrass02, lochtallgrass04, lochtallgrass05
	},
	silverpine = {
		far = { 203965, 203978, 203985, 204127, 204132 }, -- silverpineboardwalk01, silverpinetree01fallen, silverpinetreestump01, tirisfallfallentree03, tirisfallgladecanopytree05
		mid = { 203965, 203979, 204105, 204116, 204124, 204131 }, -- silverpineboardwalk01, silverpinetree02, brillgraves01, tirisfalloutpost01, tirisfalgladetree01, tirisfallgladecanopytree04
		near = { 204097, 204098, 204099, 204101, 204103 }, -- tirisfallbush01, tirisfallgladebush03, tirisfallgladebush04, doomweed01, gloomweed01
	},
	barrens = {
		far = { 201394, 201398, 201402, 201405, 304802 }, -- barrenstree01, barrenstree03, barrenstree06, barrenstree08, barrenstreegreen01
		mid = { 201363, 201366, 201390, 201399, 201403, 201407 }, -- kotobeastbone01, kotobeastbone04, raptorhut02, barrenstree04, barrenstree07, barrenstree10
		near = { 201370, 201371, 201372, 351244, 351245, 351246 }, -- barrensbush01, barrensbush02, barrensbush03, barrens_druidroot_01, barrens_druidroot_02, barrens_druidroot_03
	},
	ragefire = {
		far = { 189253, 189254, 189255, 202344 }, -- ashtree01, ashtree02, ashtree03, manerothtree
		mid = { 189179, 189221, 189241, 189248, 202356, 365013 }, -- lotharstatue, lavarock04, stonegolemstatue2-9, stonegolemstatue9-9, hordeonyxiatrophypost, winterorc_rocks_02
		near = { 189179, 189220, 189239, 189246, 244285, 440163 }, -- lotharstatue, lavarock03, stonebracket03, stonegolemstatue7-9, org_arena_red_fence, orgrim_rocks_01
	},
	redridge = {
		far = { 190114, 190116, 190119, 190121, 190124 }, -- redridgefallentree01, redridgefallentree02, redridgetree01, redridgetreecanopy01, redridgetreecanopy04
		mid = { 190101, 190106, 190115, 190118, 190121, 190124 }, -- redridgerock01, battlegladewoodspikeslongrow, redridgefallentree01moss, redridgefallentree03, redridgetreecanopy01, redridgetreecanopy04
		near = { 190080, 190081, 190082, 190108 }, -- redridgebush01, redridgebush02, redridgebush03, redridgestump02
	},
	stonetalon = {
		far = { 202620, 202623, 202627, 202641, 202649 }, -- stonetree01, stonetree04, stonetree08, stonetreestump01, stonetree01_web
		mid = { 202611, 202616, 202623, 202627, 202641, 202649 }, -- stonetalonharpysnest01, stonetalontools_saw01, stonetree04, stonetree08, stonetreestump01, stonetree01_web
		near = { 202611, 202612, 202614, 202615, 202616, 254628 }, -- stonetalonharpysnest01, stonetalonharpysnest02, stonetalonrockoutcrop01, stonetalontools_crank01, stonetalontools_saw01, stonetalonvolcanotop
	},
	wailing = {
		far = { 201394, 201398, 201402, 201406, 304802 }, -- barrenstree01, barrenstree03, barrenstree06, barrenstree09, barrenstreegreen01
		mid = { 201363, 201367, 201396, 201403, 202792, 202807 }, -- kotobeastbone01, kotobeastbone05, barrenstree02, barrenstree07, wc_cage01, wc_druidofthethunderspine
		near = { 201370, 201371, 201372, 351244, 351245, 351246 }, -- barrensbush01, barrensbush02, barrensbush03, barrens_druidroot_01, barrens_druidroot_02, barrens_druidroot_03
	},
	deadmines = {
		far = { 190638, 190639, 190640, 190642, 190647 }, -- westfalltree01, westfalltree02, westfalltree03, westfalltreecanopy01, westfalltreestump01
		mid = { 190519, 190642, 307337, 307355, 314517, 320501 }, -- westfallwindmill, westfalltreecanopy01, goblin_fence_brown_02, goblin_fence_green_10, goblin_cage_01, goblin_horde_spikes_05
		near = { 190564, 190566, 190577, 190675 }, -- westfallberrybush, westfallbush01, westfallreeds01, westfallvineyard01
	},
	ashenvale = {
		far = { 201211, 201213, 201218, 201222, 201226 }, -- ashenvaletreestump01, ashenvaletreestump03, ashenvaletreelog02, ashenvalecuttree02, ashenvaletree03
		mid = { 201195, 201212, 201222, 201230, 201246, 201251 }, -- ashenvalerock01, ashenvaletreestump02, ashenvalecuttree02, ashenvaletree05, ruinssatyrwall01, ruinssatyrwall06
		near = { 201201, 201202, 201203, 201204, 201208, 201209 }, -- ashenvaleroots01, ashenvaleroots02, ashenvaleroots03, ashenvaleroots04, ashenvalestump01, ashenvalestump02
	},
	duskwood = {
		far = { 189521, 189545, 189552, 189560, 189567 }, -- duskwoodtreespookless01, duskwoodfallentree, duskwoodspookytree03, duskwoodtreecanopy01, duskwoodtreestump02
		mid = { 189359, 189472, 189494, 189513, 189536, 189559 }, -- gnolltent02, duskwoodfencetopbroken, gatesegment03, duskwoodruinsfoundation02, tombstonemonument01, duskwoodtree07
		near = { 189395, 189397, 189400, 189406, 189427, 189438 }, -- duskwoodbush01, duskwoodbush03, duskwoodbush06, duskwoodspookybush02, duskwoodgrass01, duskwoodthornbush02
	},
	hillsbrad = {
		far = { 203617, 203620, 203623, 203690, 203693 }, -- alteractree01, alteractree04, alteractree08, arathitree03, arathitree_dead_001
		mid = { 203608, 203618, 203656, 203669, 203677, 203689 }, -- alteracopengrave01, alteractree02, arathifarmhouse01, arathirock02, arathirock09, arathitree02
		near = { 203595, 203597, 203643, 203646, 203650, 203684 }, -- alteracshrub01, alteracshrub03, arathiplant01, arathiplant03, arathiplant05, arathistump01
	},
	wetlands = {
		far = { 203533, 203540, 203543, 203545, 203547 }, -- wetlandstree04, wetlandstreestump02, wetlandtree01, wetlandtree03, wetlandtree05
		mid = { 203501, 203507, 203522, 203533, 203541, 203546 }, -- dragonbonesbody, dragonbonesskull, dwarvebone02, wetlandstree04, wetlandstreestump03, wetlandtree04
		near = { 203479, 203482, 203485, 203488, 203491, 203494 }, -- wetlandgrass01, wetlandgrass04, wetlandshrub02, wetlandshrub05, wetlandshrub08, wetlandsshrub05
	},
	shadowfang = {
		far = { 189521, 189551, 189561, 189581, 203978 }, -- duskwoodtreespookless01, duskwoodspookytree02, duskwoodtreecanopy02, warningtree, silverpinetree01fallen
		mid = { 189359, 189478, 189506, 189530, 189557, 189589 }, -- gnolltent02, rockwallrubble, duskwoodruins01, tombstone05, duskwoodtree05, duskwoodwarpgate
		near = { 189395, 189397, 189400, 189406, 189427, 189438 }, -- duskwoodbush01, duskwoodbush03, duskwoodbush06, duskwoodspookybush02, duskwoodgrass01, duskwoodthornbush02
	},
	blackfathom = {
		far = { 201211, 201213, 201218, 201222, 201226 }, -- ashenvaletreestump01, ashenvaletreestump03, ashenvaletreelog02, ashenvalecuttree02, ashenvaletree03
		mid = { 201195, 201213, 201223, 201236, 201248, 201254 }, -- ashenvalerock01, ashenvaletreestump03, ashenvaletree01, ruinssatyrarch, ruinssatyrwall03, ashensatyrtotem03
		near = { 201201, 201202, 201203, 201204, 201208, 201209 }, -- ashenvaleroots01, ashenvaleroots02, ashenvaleroots03, ashenvaleroots04, ashenvalestump01, ashenvalestump02
	},
	needles = {
		far = { 202710, 202718, 202724, 202729, 347914 }, -- saltflatrock_01, thousandrock02, thousandrock08, thousandrock13, thousandrockbroken04
		mid = { 202710, 202716, 202722, 202727, 202731, 347915 }, -- saltflatrock_01, thousandrock01, thousandrock06, thousandrock11, thousandrock15, thousandrockbroken05
		near = { 202710, 202716, 202722, 202727, 202731, 347915 }, -- saltflatrock_01, thousandrock01, thousandrock06, thousandrock11, thousandrock15, thousandrockbroken05
	},
	scarlet = {
		far = { 204124, 204126, 204129, 204131, 204134 }, -- tirisfalgladetree01, tirisfallfallentree02, tirisfallgladecanopytree02, tirisfallgladecanopytree04, tirisfallgladecanopytree07
		mid = { 190914, 190923, 204090, 204116, 204124, 204131 }, -- statuedmmountainking, statuehmcaptainclean, massgrave, tirisfalloutpost01, tirisfalgladetree01, tirisfallgladecanopytree04
		near = { 204097, 204098, 204099, 204101, 204103 }, -- tirisfallbush01, tirisfallgladebush03, tirisfallgladebush04, doomweed01, gloomweed01
	},
	gnomeregan = {
		far = { 203276, 203278, 203280, 203286, 203288 }, -- wintermidtree01, wintermidtree03, wintersmalltree02, wintertree02, wintertree04
		mid = { 197700, 203158, 203208, 203277, 203285, 203290 }, -- gnomehutelevator, dunmoroghstonefence01, snowytowerrock01, wintermidtree02, wintertree01, wintertree05
		near = { 203265, 203266, 203268, 203269, 203270 }, -- ironstump01, ironstump02, ironstump03, ironstump04, ironstump05
	},
	razorfen = {
		far = { 201394, 201398, 201402, 201406, 304806 }, -- barrenstree01, barrenstree03, barrenstree06, barrenstree09, barrenstreegreen02
		mid = { 201363, 201366, 201394, 201399, 201405, 304802 }, -- kotobeastbone01, kotobeastbone04, barrenstree01, barrenstree04, barrenstree08, barrenstreegreen01
		near = { 201370, 201371, 201372, 351244, 351245, 351246 }, -- barrensbush01, barrensbush02, barrensbush03, barrens_druidroot_01, barrens_druidroot_02, barrens_druidroot_03
	},
	arathi = {
		far = { 203688, 203689, 203691, 203693, 203695 }, -- arathitree01, arathitree02, arathitree04, arathitree_dead_001, arathitree_dead_003
		mid = { 203656, 203663, 203672, 203677, 203682, 203692 }, -- arathifarmhouse01, impalingstone02, arathirock04, arathirock09, arathirock14, arathitree05
		near = { 203636, 203643, 203646, 203650, 203652, 203686 }, -- bramblestaff, arathiplant01, arathiplant03, arathiplant05, arathiplant06, arathistump02
	},
	desolace = {
		far = { 201575, 201595, 201599, 201603, 201610 }, -- defiledtotem01, kodograve03, kodograve07, kodograve11, desolacerock01
		mid = { 201575, 201594, 201597, 201601, 201604, 201610 }, -- defiledtotem01, kodograve02, kodograve05, kodograve09, kodograve12, desolacerock01
		near = { 201575, 201594, 201598, 201601, 201605, 201610 }, -- defiledtotem01, kodograve02, kodograve06, kodograve09, kodograve13, desolacerock01
	},
	stranglethorn = {
		far = { 190308, 190311, 190312, 190316, 190319 }, -- strangledeadtree01, bootybaytree01, strangledeadtreenovine, stranglethorntree01, stranglethorntree02
		mid = { 190141, 190182, 190206, 190275, 190284, 190308 }, -- cage01, aquaductstone_pillar2, crystallizedtroll02, stranglethornruins05, stranglethornruins14, strangledeadtree01
		near = { 190223, 190226, 190229, 190233, 190238, 190313 }, -- strangleplant06, strangleplant09, stranglethornfern02, stranglethornfern06, stranglethornplant03, stranglethornroot01
	},
	badlands = {
		far = { 202973, 202976, 202980, 202983, 367748 }, -- badlandspalmtree01, badlandstree01dead, badlandstree02fallen, badlandstree04, badlands_charredtree03
		mid = { 202890, 202943, 202957, 202976, 202982, 367319 }, -- badlandsbones01, badlandsrock04, badlandscobrapillar03, badlandstree01dead, badlandstree03dead, badlands_charredrock05
		near = { 202904, 202908, 202914, 202928, 202933, 202972 }, -- badlandsshrub01, badlandsshrub04, badlandsshrub08, badlandscactus_3, badlandscactus_8, badlandscactus03
	},
	dustwallow = {
		far = { 201826, 201827, 201829, 201830, 201832 }, -- dustwallowtree01, dustwallowtree02, dustwallowtree04, dustwallowtree05, dustwallowtree07
		mid = { 201811, 201815, 201820, 201828, 201832, 201841 }, -- dustwallowbush01, dustwallowshrub03, dustwallowoutpost04, dustwallowtree03, dustwallowtree07, dustwallowwall01
		near = { 201811, 201814, 201817, 201821, 201838, 201842 }, -- dustwallowbush01, dustwallowshrub02, dustwallowoutpost01, dustwallowoutpost05, duskwallowstonewall02, dustwallowwall02
	},
	swamp = {
		far = { 190408, 190412, 190419, 190423, 368374 }, -- losttreehuts01, swamptreelog02, swampsorrowcanopytree02, swampsorrowcanopytree06, swamptreebroken01
		mid = { 190364, 190393, 190409, 190414, 190421, 368373 }, -- runestonecrud_01, swampbeastbone01, losttreehuts02, swamptreelog04, swampsorrowcanopytree04, swamptreeblowup01
		near = { 190375, 190377, 190379, 190382, 190384, 367633 }, -- swampofsorrowlilypad01, swampplant03, swampplant05, swampsorrowroot01, swampsorrowroot03, swampsorrowstump02
	},
	feralas = {
		far = { 201935, 201937, 201940, 201945, 201948 }, -- feralastree01, feralastree03, feralastree05, feralastreeroots03, feralastreestump01
		mid = { 201933, 201936, 201940, 201945, 201949, 366219 }, -- feralasstone01, feralastree02, feralastree05, feralastreeroots03, feralastreestump02, feralas_stonegiantrock02
		near = { 201930, 201933, 201934, 366218, 366219, 367850 }, -- feralasferns01, feralasstone01, feralasstone02, feralas_stonegiantrock01, feralas_stonegiantrock02, feralas_stonegiantrock04
	},
	hinterlands = {
		far = { 203577, 203578, 203587, 203588, 203590 }, -- griffonmemorialtree01, griffonmemorialtree02, aerietree01, aerietree02, aerietree04
		mid = { 203558, 203560, 203569, 203578, 203587, 203589 }, -- aerieboulder01, aerieboulder03, aeriepeaksrockoutcrop01, griffonmemorialtree02, aerietree01, aerietree03
		near = { 203565, 203566, 203584 }, -- aeriepeaksbush01, aeriepeaksbush02, aeriepeaksstump01
	},
	tanaris = {
		far = { 202655, 202674, 202677, 202680, 202683 }, -- tanaristrollgate, tanarisgoblinwallcurve01, tanarisrock01, tanarisrock04, tanarisrock07
		mid = { 202655, 202673, 202676, 202678, 202681, 202683 }, -- tanaristrollgate, tanarisgoblinwall02, tanarisgoblinwallpost01, tanarisrock02, tanarisrock05, tanarisrock07
		near = { 202657, 202658, 202659, 202660, 202661, 202662 }, -- tanariscactus01, tanariscactus02, tanariscactus03, tanariscactus04, tanariscactus05, tanariscactus06
	},
	uldaman = {
		far = { 202973, 202976, 202980, 202983, 367748 }, -- badlandspalmtree01, badlandstree01dead, badlandstree02fallen, badlandstree04, badlands_charredtree03
		mid = { 202890, 202946, 202975, 203368, 203443, 367316 }, -- badlandsbones01, badlandsrock07, badlandstree01, stonekeeperaltar, uldamantaurenstatue, badlands_charredrock02
		near = { 202904, 202908, 202914, 202928, 202933, 202972 }, -- badlandsshrub01, badlandsshrub04, badlandsshrub08, badlandscactus_3, badlandscactus_8, badlandscactus03
	},
	searing = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189179, 189219, 189236, 189242, 189247, 203006 }, -- lotharstatue, lavarock02, stoneblock01, stonegolemstatue3-9, stonegolemstatue8-9, blackrockaltarritual
		near = { 189179, 189218, 189223, 189240, 189245, 203018 }, -- lotharstatue, lavarock01, lavarock06, stonegolemstatue1-9, stonegolemstatue6-9, darkironbrazier
	},
	zulfarrak = {
		far = { 200623, 202674, 202679, 254421, 331590 }, -- skulltiki, tanarisgoblinwallcurve01, tanarisrock03, go_large_rocket_2, troll_spikes_01
		mid = { 200623, 202673, 202678, 202682, 331587, 331802 }, -- skulltiki, tanarisgoblinwall02, tanarisrock02, tanarisrock06, troll_seawalls_02, troll_spikes_04
		near = { 202657, 202658, 202659, 202660, 202661, 202662 }, -- tanariscactus01, tanariscactus02, tanariscactus03, tanariscactus04, tanariscactus05, tanariscactus06
	},
	azshara = {
		far = { 201332, 201334, 201337, 311992, 312828 }, -- azr_tree01, azr_tree03, azr_tree06, azr_tree_stump_02, azr_tree_stump_05
		mid = { 201271, 201300, 201308, 201334, 201338, 312063 }, -- arcanecrystal, azharadragonstatue_02, azshararock04, azr_tree03, azr_tree07, azr_tree_stump_03
		near = { 201271, 201284, 201299, 201305, 201307, 201309 }, -- arcanecrystal, barnaclerock01, azharadragonstatue_01, azshararock01, azshararock03, azshararock05
	},
	blasted = {
		far = { 190441, 190485, 190487, 190489, 367446 }, -- blastedlandsspine01, blastedlandsashtree03, blastedlandsblastedtree03, blastedlandstree01, blastedlands_twistedtree02
		mid = { 190436, 190441, 190454, 190470, 190478, 190487 }, -- blastedlandsbone01, blastedlandsspine01, blastedlandsrock03, brokengatearch, brokengatewood02, blastedlandsblastedtree03
		near = { 190436, 190439, 190447, 190457, 190469, 190476 }, -- blastedlandsbone01, blastedlandsskull01, blastedlandsrock01, blastedlandsroot03, blastedlandsruinstusk, brokengatewall
	},
	maraudon = {
		far = { 202092, 202093, 202106, 202107, 202111 }, -- maraudoncorruptedtree01, maraudoncorruptedtree02, maraudonspewertree, maraudonspewertreebosscolor, maraudontransitiontree01
		mid = { 201575, 201603, 202104, 202129, 202147, 202204 }, -- defiledtotem01, kodograve11, maraudonspawnertree, diamondcrystal01, rubycrystal08, satyrfloorbraziergreen01
		near = { 201607, 202177, 202187, 202190, 202238, 202241 }, -- desolacemushroom, maraudonshroom02, maraudonroot02, maraudonroot05, maraudonnastyvine01, maraudonnastyvine04
	},
	ungoro = {
		far = { 202782, 202783, 202784 }, -- ungorotreebite, ungorotreebreak, ungorotreebreak2
		mid = { 202747, 202750, 202754, 202771, 202775, 202779 }, -- ungoroarchway01, ungorocrystal_green01, ungorocrystal_yellow01, ungororock07, ungororock11, ungororock15
		near = { 202747, 202750, 202753, 202770, 202773, 202776 }, -- ungoroarchway01, ungorocrystal_green01, ungorocrystal_red02, ungororock06, ungororock09, ungororock12
	},
	felwood = {
		far = { 201900, 201902, 201905, 201912, 201915 }, -- felwoodtree01, felwoodtree03, felwoodtree06, felwoodtreestump01, felwoodtreesub03
		mid = { 201845, 201901, 201903, 201906, 201913, 201915 }, -- illidancrystal02, felwoodtree02, felwoodtree04, felwoodtree07, felwoodtreesub01, felwoodtreesub03
		near = { 201847, 201851, 201860, 201873, 201881, 201883 }, -- felwoodbush01, felwoodbush03, felwoodmushroom02, songflower02, felwoodroots01, felwoodroots03
	},
	burningsteppes = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189179, 189218, 189223, 189239, 189244, 189248 }, -- lotharstatue, lavarock01, lavarock06, stonebracket03, stonegolemstatue5-9, stonegolemstatue9-9
		near = { 189179, 189218, 189222, 189238, 189242, 189246 }, -- lotharstatue, lavarock01, lavarock05, stonebracket02, stonegolemstatue3-9, stonegolemstatue7-9
	},
	sunkentemple = {
		far = { 190408, 190412, 190419, 190423, 368374 }, -- losttreehuts01, swamptreelog02, swampsorrowcanopytree02, swampsorrowcanopytree06, swamptreebroken01
		mid = { 190363, 190400, 190412, 190422, 331587, 368373 }, -- serpentaltar, swampskulls01, swamptreelog02, swampsorrowcanopytree05, troll_seawalls_02, swamptreeblowup01
		near = { 190375, 190377, 190379, 190382, 190384, 367633 }, -- swampofsorrowlilypad01, swampplant03, swampplant05, swampsorrowroot01, swampsorrowroot03, swampsorrowstump02
	},
	plaguelands = {
		far = { 203781, 203799, 203802, 203805, 203808 }, -- treebarrier01, plaguelandtree02, plaguelandtree05, plaguelandtree08, plaguelandtree11
		mid = { 203723, 203738, 203776, 203781, 203801, 203806 }, -- bonespike_01, plaugelandscage01_activebase, plaguelandrock04, treebarrier01, plaguelandtree04, plaguelandtree09
		near = { 203731, 203733, 203760, 203788, 203790, 203795 }, -- plaguelandwesternbush01, plaguelandwesternbush03, plaguelandfern02, plaguelandmushroom01, plaguelandmushroom03, plaguelandstump02
	},
	blackrockdepths = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189179, 189219, 189236, 189242, 189247, 203006 }, -- lotharstatue, lavarock02, stoneblock01, stonegolemstatue3-9, stonegolemstatue8-9, blackrockaltarritual
		near = { 189179, 189218, 189223, 189240, 189245, 203018 }, -- lotharstatue, lavarock01, lavarock06, stonegolemstatue1-9, stonegolemstatue6-9, darkironbrazier
	},
	winterspring = {
		far = { 202855, 202857, 202873, 202877, 202885 }, -- newwinterspringmidtree01, newwinterspringtree01, winterspringfallentree01, winterspringtree02, winterspringworldtreeroot02
		mid = { 202828, 202841, 202848, 202855, 202859, 202878 }, -- winterspringaltar01, furbolgtotemsnow01, winterspringrock04, newwinterspringmidtree01, newwinterspringtree05, winterspringtree03
		near = { 202828, 202839, 202842, 202846, 202849, 202851 }, -- winterspringaltar01, furbolgtentsnow, furbolgtotemsnow02, winterspringrock02, winterspringrock05, winterspringrock07
	},
	diremaul = {
		far = { 201675, 201713, 201734, 201939, 201946 }, -- brokenferalastree01, diremaultreeroot05, gardentreehuge, feralastree04_capped, feralastreeroots04
		mid = { 201617, 201679, 201707, 201719, 201936, 201947 }, -- corruptedcrystalshard, goldenhighelfstatue01, diremaulstonestatue03, diremaulwallrubble02, feralastree02, feralastreeroots05
		near = { 201617, 201658, 201681, 201705, 201719, 366217 }, -- corruptedcrystalshard, diremaulstonebearstatue, goldenhighelfstatue03, diremaulstonestatue01, diremaulwallrubble02, feralas_stonegiantcrystal01
	},
	silithus = {
		far = { 202396, 202455, 202480, 202503, 202565 }, -- ahn_quiraj_ossiriancrystal, silithus_commcrystal_base03, silithus_crystal_nub_04, nightelfruinwallsilithusrubble01, quirajwall01
		mid = { 202396, 202453, 202474, 202495, 202552, 202568 }, -- ahn_quiraj_ossiriancrystal, silithus_commcrystal_base01, silithus_crystal_formation_04, elventowersilithus03, quirajlwall03, silithusgate01
		near = { 202396, 202453, 202474, 202495, 202552, 202568 }, -- ahn_quiraj_ossiriancrystal, silithus_commcrystal_base01, silithus_crystal_formation_04, elventowersilithus03, quirajlwall03, silithusgate01
	},
	blackrockspire = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189179, 189223, 189245, 199052, 199209, 199456 }, -- lotharstatue, lavarock06, stonegolemstatue6-9, tallstriderskull, orcfence, wyvernroost_ruined
		near = { 199215, 199217, 199218, 199220 }, -- wailingfern06, wailingplant01, wailingplant02, wailingplantpurple01
	},
	gordok = {
		far = { 201675, 201710, 201712, 201714, 201732 }, -- brokenferalastree01, diremaultreeroot02, diremaultreeroot04, diremaultreeroot06, gardentreeferalas
		mid = { 198998, 199008, 199018, 201619, 201691, 201711 }, -- brogremoundrock01, grogremoundrock05, snogremoundrock03, corruptedcrystalvine, diremaulogrepost01, diremaultreeroot03
		near = { 198998, 199006, 199015, 199035, 201658, 201693 }, -- brogremoundrock01, grogremoundrock03, ogremoundrock06, ogrewalltorchblue, diremaulstonebearstatue, diremaulogrepost03
	},
	highborne = {
		far = { 198959, 201709, 201711, 201714, 201732 }, -- teleporttree, diremaultreeroot01, diremaultreeroot03, diremaultreeroot06, gardentreeferalas
		mid = { 198755, 198828, 198947, 201680, 201731, 352425 }, -- elvenstonestool01, newelfruin05, steppingstone01, goldenhighelfstatue02, gardentreecanopy, azrelfruin_uw04
		near = { 198755, 198826, 198943, 201658, 328178, 352427 }, -- elvenstonestool01, newelfruin03, statueaszharafeet, diremaulstonebearstatue, nightelfsingletent01, azrelfruin_uw07
	},
	scholomance = {
		far = { 203781, 203799, 203802, 203805, 203808 }, -- treebarrier01, plaguelandtree02, plaguelandtree05, plaguelandtree08, plaguelandtree11
		mid = { 203723, 203739, 203778, 203799, 203805, 203831 }, -- bonespike_01, plaugelandscage01_activetop, plaguelandrock06, plaguelandtree02, plaguelandtree08, undeadwall_01
		near = { 203731, 203733, 203760, 203788, 203790, 203795 }, -- plaguelandwesternbush01, plaguelandwesternbush03, plaguelandfern02, plaguelandmushroom01, plaguelandmushroom03, plaguelandstump02
	},
	stratholme = {
		far = { 203781, 203799, 203802, 203805, 203808 }, -- treebarrier01, plaguelandtree02, plaguelandtree05, plaguelandtree08, plaguelandtree11
		mid = { 203723, 203738, 203776, 203783, 203802, 203807 }, -- bonespike_01, plaugelandscage01_activebase, plaguelandrock04, plaguedfallentree01, plaguelandtree05, plaguelandtree10
		near = { 203731, 203733, 203760, 203788, 203790, 203795 }, -- plaguelandwesternbush01, plaguelandwesternbush03, plaguelandfern02, plaguelandmushroom01, plaguelandmushroom03, plaguelandstump02
	},
	zulgurub = {
		far = { 190308, 190312, 190319, 190711, 190713 }, -- strangledeadtree01, strangledeadtreenovine, stranglethorntree02, zulgurubtree01, zulgurubtree03
		mid = { 190141, 190184, 190264, 190280, 190291, 190348 }, -- cage01, aquaductstone_short, stranglethorncliffrock01, stranglethornruins10, stranglethornruins21, trolldungeonserpentstatue
		near = { 190223, 190227, 190231, 190237, 190313, 512315 }, -- strangleplant06, strangleplant10, stranglethornfern04, stranglethornplant02, stranglethornroot01, zulgurub_vines_01
	},
	ahnqiraj = {
		far = { 202396, 202455, 202480, 202503, 202565 }, -- ahn_quiraj_ossiriancrystal, silithus_commcrystal_base03, silithus_crystal_nub_04, nightelfruinwallsilithusrubble01, quirajwall01
		mid = { 202396, 202453, 202474, 202495, 202552, 202568 }, -- ahn_quiraj_ossiriancrystal, silithus_commcrystal_base01, silithus_crystal_formation_04, elventowersilithus03, quirajlwall03, silithusgate01
		near = { 202396, 202453, 202474, 202495, 202552, 202568 }, -- ahn_quiraj_ossiriancrystal, silithus_commcrystal_base01, silithus_crystal_formation_04, elventowersilithus03, quirajlwall03, silithusgate01
	},
	moltencore = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189179, 189219, 189236, 189242, 189247, 203006 }, -- lotharstatue, lavarock02, stoneblock01, stonegolemstatue3-9, stonegolemstatue8-9, blackrockaltarritual
		near = { 189179, 189218, 189223, 189240, 189245, 203018 }, -- lotharstatue, lavarock01, lavarock06, stonegolemstatue1-9, stonegolemstatue6-9, darkironbrazier
	},
	onyxia = {
		far = { 201826, 201827, 201829, 201830, 201832 }, -- dustwallowtree01, dustwallowtree02, dustwallowtree04, dustwallowtree05, dustwallowtree07
		mid = { 201811, 201816, 201821, 201829, 201837, 201843 }, -- dustwallowbush01, dustwallowshrub04, dustwallowoutpost05, dustwallowtree04, duskwallowstonewall01, dustwallowwall03
		near = { 201811, 201814, 201818, 201822, 201839, 201844 }, -- dustwallowbush01, dustwallowshrub02, dustwallowoutpost02, dustwallowoutpost06, duskwallowstonewallpost, dustwallowwallpost
	},
	blackwing = {
		far = { 189253, 189254, 189255 }, -- ashtree01, ashtree02, ashtree03
		mid = { 189179, 189219, 189236, 189242, 189247, 203006 }, -- lotharstatue, lavarock02, stoneblock01, stonegolemstatue3-9, stonegolemstatue8-9, blackrockaltarritual
		near = { 189179, 189218, 189223, 189240, 189245, 203018 }, -- lotharstatue, lavarock01, lavarock06, stonegolemstatue1-9, stonegolemstatue6-9, darkironbrazier
	},
	aqtemple = {
		far = { 202376, 202450, 202477, 202501, 202562 }, -- exterior_arch01, floatingredcrystalbroken03, silithus_crystal_nub_01, nightelfruinwallsilithus02, quirajtwall03
		mid = { 202376, 202447, 202466, 202485, 202550, 202567 }, -- exterior_arch01, floatingredcrystal01, silithus_crystal_clump_04, silithus_crystal_spike_03, quirajlwall01, quirajwall03
		near = { 202376, 202447, 202466, 202485, 202550, 202567 }, -- exterior_arch01, floatingredcrystal01, silithus_crystal_clump_04, silithus_crystal_spike_03, quirajlwall01, quirajwall03
	},
	naxxramas = {
		far = { 203781, 203799, 203802, 203805, 203808 }, -- treebarrier01, plaguelandtree02, plaguelandtree05, plaguelandtree08, plaguelandtree11
		mid = { 200655, 200756, 203726, 203777, 203799, 203806 }, -- lordaeronbrazier01, lordaeron_statue_03, bonewall_01, plaguelandrock05, plaguelandtree02, plaguelandtree09
		near = { 203731, 203733, 203760, 203788, 203790, 203795 }, -- plaguelandwesternbush01, plaguelandwesternbush03, plaguelandfern02, plaguelandmushroom01, plaguelandmushroom03, plaguelandstump02
	},
}

-- the scenery of each stage, by difficulty and stage (1..30)
ns.STAGE_SCENERY = {
	{ -- 일반
		"elwynn", "dunmorogh", "teldrassil", "durotar", "mulgore", "tirisfal", "westfall", "lochmodan", "silverpine", "barrens",
		"ragefire", "redridge", "stonetalon", "wailing", "deadmines", "ashenvale", "duskwood", "hillsbrad", "wetlands", "shadowfang",
		"blackfathom", "needles", "scarlet", "gnomeregan", "razorfen", "scarlet", "arathi", "desolace", "stranglethorn", "scarlet",
	},
	{ -- 영웅
		"badlands", "dustwallow", "swamp", "scarlet", "razorfen", "feralas", "hinterlands", "tanaris", "uldaman", "uldaman",
		"searing", "zulfarrak", "azshara", "blasted", "maraudon", "maraudon", "ungoro", "felwood", "burningsteppes", "sunkentemple",
		"plaguelands", "blackrockdepths", "blackrockdepths", "blackrockdepths", "winterspring", "plaguelands", "diremaul", "silithus", "blackrockspire", "blackrockspire",
	},
	{ -- 신화
		"gordok", "highborne", "scholomance", "stratholme", "blackrockspire", "scholomance", "scholomance", "stratholme", "blackrockspire", "blackrockspire",
		"zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub", "zulgurub",
		"silithus", "silithus", "ahnqiraj", "ahnqiraj", "ahnqiraj", "ahnqiraj", "ahnqiraj", "ahnqiraj", "azshara", "blasted",
	},
	{ -- 신화+
		"moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore", "moltencore",
		"onyxia", "blackwing", "blackwing", "blackwing", "blackwing", "blackwing", "aqtemple", "aqtemple", "aqtemple", "aqtemple",
		"naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas", "naxxramas",
	},
}

function ns.SceneryFor(diff, idx)
	local row = ns.STAGE_SCENERY[diff]
	return row and ns.SCENERY[row[idx]]
end
