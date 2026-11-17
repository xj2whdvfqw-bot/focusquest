import Foundation

// MARK: - Bossove svetu Dojo, Farm, History Hall a Orbit (16x16, "." = pruhledne)
// Prevzato z prilohy design/CHANGES.md ("Appendix: pixel art for new characters").

extension SpritePalette {
    static let bossRows: [String: [String]] = [
        // Dojo
        "dojo-karate": [
            "................", ".....KKKKKK.....", "....KKKKKKKK....", "....KFFFFFFK....",
            "....FFKFFKFF....", "....FFFFFFFF....", ".....FFFFFF.....", "...WWWWFFWWWW...",
            "..FWWWWWWWWWWF..", "..FWWWWWWWWWWF..", "...KKKKKKKKKK...", "....WWWKKWWW....",
            "....WWW..WWW....", "....WWW..WWW....", "....FFF..FFF....", "................"
        ],
        "dojo-master": [
            ".......YY.......", ".....YYYYYY.....", "...YYYYYYYYYY...", ".TTTTTTTTTTTTTT.",
            "....FKFFFFKF....", "....FFFFFFFF....", "....WWWWWWWW....", "..T..WWWWWW.....",
            "..TFAAAWWAAA....", "..T.AAAAAAAA....", "..T.AAAAAAAA....", "..T.AAAAAAAA....",
            "..T..AAAAAA.....", "..T..AAAAAA.....", "..T..KK..KK.....", "..T............."
        ],
        "dojo-monk": [
            "................", "......FFFF......", ".....FFFFFF.....", ".....FKFFKF.....",
            ".....FFFFFF.....", "......FFFF......", "....OOOOFFFF....", "...OOOOOOFFFF...",
            "...OOOOOOOOFF...", "...OOOOFFOOOO...", "...OOOOOOOOOO...", "....OOOOOOOO....",
            "....OOOOOOOO....", "....OOOOOOOO....", "....TT....TT....", "................"
        ],
        "dojo-boxer": [
            "................", ".....KKKKKK.....", ".....KFFFFK.....", ".....FKFFKF.....",
            ".....FFFFFF.....", "......FFFF......", "..RR.FFFFFF.RR..", ".RRRRFFFFFFRRRR.",
            ".RRRRFFFFFFRRRR.", "..RR.FFFFFF.RR..", ".....WWWWWW.....", "....BBBBBBBB....",
            "....BBB..BBB....", "....FFF..FFF....", "....WWW..WWW....", "................"
        ],
        "dojo-mma": [
            "................", ".......KK.......", "......FKKF......", ".....FFFFFF.....",
            ".....FKFFKF.....", ".....FFFFFF.....", "......FFFF......", "...FFFFFFFFFF...",
            "..FFFFFFFFFFFF..", "..KF.FFFFFF.FK..", ".KK..FFFFFF..KK.", "....GGGGGGGG....",
            "....GGG..GGG....", "....FFF..FFF....", "....FFF..FFF....", "................"
        ],
        "dojo-judo": [
            "................", ".....TTTTTT.....", "....TTTTTTTT....", "....TFFFFFFT....",
            "....FFKFFKFF....", "....FFFFFFFF....", ".....FFFFFF.....", "...BBBBFFBBBB...",
            "..FBBBBBBBBBBF..", "..FBBBBBBBBBBF..", "...YYYYYYYYYY...", "....BBBYYBBB....",
            "....BBB..BBB....", "....BBB..BBB....", "....FFF..FFF....", "................"
        ],
        "dojo-kendo": [
            "...............T", ".....SSSSSS...T.", "....SAAAAAAS.T..", "....SAKAAKAST...",
            "....SAAAAAAT....", "....SSSSSSFS....", "...SSSSSSSFSS...", "...SAAAAAAASS...",
            "...SAAAAAAASS...", "....SSSSSSSS....", "...UUUUUUUUUU...", "...UUUUUUUUUU...",
            "..UUUUUUUUUUUU..", "..UUUUU..UUUUU..", "...FF......FF...", "................"
        ],
        "dojo-muaythai": [
            "................", ".....KKKKKK.....", ".....YYYYYY.....", ".....FKFFKF.....",
            ".....FFFFFF.....", "......FFFF......", "...FFFFFFFFFF...", "..RFFFFFFFFFFR..",
            "..FFFFFFFFFFFF..", "..W.FFFFFFFF.W..", "....YYYYYYYY....", "....YYKYYKYY....",
            "....FFF..FFF....", "....WWW..WWW....", "....FFF..FFF....", "................"
        ],
        "dojo-sumo": [
            ".......KK.......", "......KKKK......", ".....KFFFFK.....", ".....FKFFKF.....",
            ".....FFFFFF.....", "...FFFFFFFFFF...", "..FFFFFFFFFFFF..", ".FFFFFFFFFFFFFF.",
            ".FFFFFFFFFFFFFF.", ".FFFFFFFFFFFFFF.", ".FFFFFFFFFFFFFF.", ".KKKKKKKKKKKKKK.",
            "..FFFFKKKKFFFF..", "..FFFF....FFFF..", "..FFFF....FFFF..", "................"
        ],
        // Farm
        "farm-bunny": [
            "....WW....WW....", "....WN....NW....", "....WN....NW....", "....WN....NW....",
            "....WWWWWWWW....", "...WWWWWWWWWW...", "...WWKWWWWKWW...", "...WWWWNNWWWW...",
            "....WWWWWWWW....", "...WWWWWWWWWW...", "..WWWWEEEEWWWW..", "..WWWEEEEEEWWW..",
            "..WWWEEEEEEWWW..", "...WWWWWWWWWW...", "...WW......WW...", "................"
        ],
        "farm-hen": [
            "................", "......RR........", ".....RRR........", ".....WWWW.......",
            "....WKWWW.......", "...YYWWWW.......", ".....RWWW.......", ".....WWWW....WW.",
            "....WWWWWWWWWWW.", "...WWWWWWWWWWWW.", "...WWWWEEEEWWW..", "....WWWWWWWWW...",
            ".....WWWWWWW....", "......O...O.....", ".....OO..OO.....", "................"
        ],
        "farm-sheep": [
            "................", "....WW.WW.WW....", "...WWWWWWWWWW...", "..WWWWKKKKWWWW..",
            ".KKWWKKKKKKWWKK.", "..WWWKWKKWKWWW..", "..WWWKKKKKKWWW..", "..WWWWKKKKWWWW..",
            ".WWWWWWWWWWWWWW.", ".WWWWWWWWWWWWWW.", ".WWWWWWWWWWWWWW.", "..WWWWWWWWWWWW..",
            "...WWWWWWWWWW...", "...KK......KK...", "...KK......KK...", "................"
        ],
        "farm-cow": [
            "................", "..E..........E..", "..EE.WWWWWW.EE..", "...KWWWWWWWWK...",
            "....WKWWWWKW....", "....WWKKWWWW....", "....NNNNNNNN....", "....NKNNNNKN....",
            "....NNNNNNNN....", "..WWWWKKWWWWWW..", "..WKKWWWWWWKKW..", "..WKKWWWWWWWWW..",
            "..WWWWWWNNWWWW..", "...KK......KK...", "...KK......KK...", "................"
        ],
        "farm-pig": [
            "................", "...NN......NN...", "...NNNNNNNNNN...", "...NNKNNNNKNN...",
            "...NNNNNNNNNN...", "....NEEEEEEN....", "....NEKEEKEN....", "....NEEEEEEN....",
            "..NNNNNNNNNNNN..", ".NNNNNNNNNNNNNN.", ".NNNNNNNNNNNNNN.", ".NNNNNNNNNNNNNN.",
            "..NNNNNNNNNNNN..", "...NN......NN...", "...TT......TT...", "................"
        ],
        "farm-donkey": [
            "...AA......AA...", "...AA......AA...", "...AN......NA...", "...AAAAKKAAAA...",
            "...AKAAAAAAKA...", "...AAAAAAAAAA...", "....EEEEEEEE....", "....EKEEEEKE....",
            "....EEEEEEEE....", "..AAAAAAAAAAAA..", "..AAAAEEEEAAAA..", "..AAAAAAAAAAAA..",
            "..AAAAAAAAAAAA..", "...AA......AA...", "...KK......KK...", "................"
        ],
        "farm-horse": [
            "................", "....TT....TT....", "....TTKKKKTT....", "....TTTKKTTT....",
            "....TKTWWTKT....", "....TTTWWTTT....", ".....TTWWTT.....", ".....TTTTTT.....",
            ".....TKTTKT.....", "..TTTTTTTTTTTT..", "..TTTTTTTTTTTK..", "..TTTTTTTTTTTK..",
            "..TTTTTTTTTTTT..", "...TT......TT...", "...KK......KK...", "................"
        ],
        // History Hall
        "hist-napoleon": [
            "................", "..KKKKKKKKKKKK..", "...KKKKYKKKKK...", "....KKKKKKKK....",
            ".....FFFFFF.....", ".....FKFFKF.....", ".....FFFFFF.....", "....UUUWWUUU....",
            "...YUUUWWUUUY...", "...UUUFUUUUUU...", "...UUUUUUUUUU...", "....WWWWWWWW....",
            "....WWW..WWW....", "....WWW..WWW....", "....KKK..KKK....", "................"
        ],
        "hist-cleo": [
            "................", ".....KKKKKK.....", "....KYYYYYYK....", "....KFFFFFFK....",
            "....KFKFFKFK....", "....KFFFFFFK....", "....KKFFFFKK....", "....KYCYYCYK....",
            "...FYYYYYYYYF...", "...F.WWWWWW.F...", ".....WWYYWW.....", ".....WWWWWW.....",
            "....WWWWWWWW....", "....WWWWWWWW....", ".....YY..YY.....", "................"
        ],
        "hist-caesar": [
            "................", "....G.GGGG.G....", "....GTTTTTTG....", "....FFFFFFFF....",
            "....FFKFFKFF....", "....FFFFFFFF....", ".....FFFFFF.....", "...WWWWWRRWWW...",
            "..FWWWWRRWWWWF..", "..FWWWRRWWWWWF..", "...WWRRWWWWWW...", "...WRRWWWWWWW...",
            "....WWWWWWWW....", "....WWWWWWWW....", "....TT....TT....", "................"
        ],
        "hist-bard": [
            "................", ".....FFFFFF.....", "....TFFFFFFT....", "....TFKFFKFT....",
            "....TFFFFFFT....", ".....FTTTTF.....", "......FTTF......", "...WWWWWWWWWW...",
            "....WWWWWWWW....", "...KKKKKKKKKK..W", "..FKKKKYKKKKF.W.", "...KKKKYKKKKK...",
            "....KKKKKKKK....", "....KKK..KKK....", "....KKK..KKK....", "................"
        ],
        "hist-leonardo": [
            "................", "....TTTTTTTT....", "...TTTTTTTTTT...", "...WFFFFFFFFW...",
            "...WFKFFFFKFW...", "...WFFFFFFFFW...", "...WWWWWWWWWW...", "....WWWWWWWW....",
            "...RRWWWWWWRR...", "..RRRRWWWWRRRR..", "..FRRRRWWRRRRF..", "...RRRRRRRRRR...",
            "...RRRRRRRRRR...", "...RRRRRRRRRR...", "....TT....TT....", "................"
        ],
        "hist-mozart": [
            "................", ".....WWWWWW.....", "....WWWWWWWW....", "...WWFFFFFFWW...",
            "...WWFKFFKFWW...", "...WWFFFFFFWW...", "....WFFNNFFW....", ".....RWWWWR.....",
            "....RRRWWRRR....", "...FRRYRRYRRF...", "....RRRRRRRR....", "....RRRRRRRR....",
            "....EEEEEEEE....", "....EEE..EEE....", "....KKK..KKK....", "................"
        ],
        "hist-newton": [
            ".......RR.......", "......RRRG......", ".....AAAAAA.....", "....AAFFFFAA....",
            "...AAFKFFKFAA...", "...AAFFFFFFAA...", "...AAAFFFFAAA...", "...AAWWWWWWAA...",
            "...TTTWWWWTTT...", "..FTTTTTTTTTTF..", "...TTTTTTTTTT...", "...TTTTTTTTTT...",
            "....TTTTTTTT....", "....KKK..KKK....", "....KKK..KKK....", "................"
        ],
        "hist-karel": [
            "....Y.Y..Y.Y....", "....YYYYYYYY....", "....YRYYYYRY....", "....FFFFFFFF....",
            "....FKFFFFKF....", "....AFFFFFFA....", "....AAAAAAAA....", ".....AAAAAA.....",
            "..WWWWRRRRWWWW..", "..WKWWRRRRWWKW..", "..RRRRRRRRRRRR..", "..RRRRYYYYRRRR..",
            "..RRRRRRRRRRRR..", "..RRRRRRRRRRRR..", "....KK....KK....", "................"
        ],
        "hist-komensky": [
            "................", ".....KKKKKK.....", "....KKKKKKKK....", "....FFFFFFFF....",
            "....FKFFFFKF....", "....FFFFFFFF....", "....AAFFFFAA....", "....AAAAAAAA....",
            "...KAAAAAAAAK...", "..KKKAAAAAAKKK..", "..KKKKAAAAKKKK..", "..KKFEEEEEEFKK..",
            "..KKKTTTTTTKKK..", "..KKKKKKKKKKKK..", "...KK......KK...", "................"
        ],
        // Orbit
        "planet-mercury": [
            "......AAAA......", "....AAASAAAA....", "...AASAAAAAAA...", "...AAAAAASAAA...",
            "..AAAKAAAAKAAA..", "..AAAAAAAAASAA..", "...AAASKKAAAA...", "....AAAAASAA....",
            ".....AAAAAA.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-venus": [
            "......YYYY......", "....OYYYYOYY....", "...OYYYYOYYYY...", "...YYYYOYYYYO...",
            "..YYYKOYYYKOYY..", "..YYYOYYYYOYYY..", "...YOYYKKOYYY...", "....YYYYOYYY....",
            ".....YYOYYY.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-earth": [
            "......BBBB......", "....BBGGBBBB....", "...BBGGBBBGBB...", "...BGGBBBBBBB...",
            "..BBBKBBBBKBBB..", "..BBBBBBBGGBBB..", "...BBBBKKGGGB...", "....BBGBBBBB....",
            ".....BBBBBB.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-mars": [
            "......OROO......", "....ROOOOOOR....", "...OOOOOROOOO...", "...OOROOOOOOR...",
            "..ROOKOOORKOOO..", "..OOOOROOOOOOR..", "...ROOOKKOROO...", "....OOOROOOO....",
            ".....OOOOOO.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-jupiter": [
            "......EEEE......", "....TTTTTTTT....", "...EEEEEEEEEE...", "...OOOOOOOOOO...",
            "..EEEKEEEEKEEE..", "..TTTTTTTTTTTT..", "...EEEEKKRREE...", "....OOOOOOOO....",
            ".....EEEEEE.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-saturn": [
            "......EEEE......", "....YYYYYYYY....", "...EEEEEEEEEE...", "...YYYYYYYYYY...",
            "..EEEKEEEEKEEE..", "TTTTTTTTTTTTTTTT", "...EEEEKKEEEE...", "....YYYYYYYY....",
            ".....EEEEEE.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-uranus": [
            "......CCCC......", "....CCCCCCCC....", "...CCCCCCCCCC...", "...CCCCCCCCCC...",
            "..CCCKCCCCKCCC..", "..CCCCCCCCCCCC..", "...CCCCKKCCCC...", "....CCCCCCCC....",
            ".....CCCCCC.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ],
        "planet-neptune": [
            "......UUUU......", "....UUUUUUUU....", "...ULLLUUUUUU...", "...UUUUUUUUUU...",
            "..UUUKUUUUKUUU..", "..UUUUUUUUUUUU..", "...UUUUKKLLUU...", "....UUUUUUUU....",
            ".....UUUUUU.....", "....WWWWWWWW....", "...WWWWBBWWWW...", "..WWWWWWWWWWWW..",
            "..A.WWWWWWWW.A..", "....WWW..WWW....", "....AAA..AAA....", "................"
        ]
    ]
}
