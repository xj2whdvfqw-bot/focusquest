import Foundation

// MARK: - Bossove svetu Whisperwood, Coral Deep a Snoozeville High (16x16, "." = pruhledne)
// Vlastni postavy FocusQuestu, nejsou odvozene od znamych postav.
// Barvy: viz SpritePalette.color(for:) (M = tmave zelena mech, H = tmave hneda).

extension SpritePalette {
    static let originalBossRows: [String: [String]] = [
        // Whisperwood: lesni skritci
        "forest-mushroom": [
            "................", ".....RRRRRR.....", "...RRWRRRRWRR...", "..RRRRRRWRRRRR..",
            "..RWRRRRRRRRWR..", "..RRRRRRRRRRRR..", "....EEEEEEEE....", "....EKEEEEKE....",
            "....EEEEEEEE....", ".....EEKKEE.....", "......EEEE......", ".....GGGGGG.....",
            "....GG.GG.GG....", ".....GGGGGG.....", ".....E....E.....", "................"
        ],
        "forest-grass": [
            "..G...G..G...G..", "..GG.GG..GG.GG..", "...GGGG..GGGG...", "....GGGGGGGG....",
            "...GGGGGGGGGG...", "...GGKGGGGKGG...", "...GGGGGGGGGG...", "...GGGKKKKGGG...",
            "....GGGGGGGG....", ".....GGGGGG.....", "....M.GGGG.M....", "...M..GGGG..M...",
            "......G..G......", "......G..G......", ".....MM..MM.....", "................"
        ],
        "forest-flower": [
            "................", ".....NN..NN.....", "....NNNNNNNN....", "...NNNYYYYNNN...",
            "..NNNYYYYYYNNN..", "...NYKYYYYKYN...", "..NNYYYYYYYYNN..", "...NYYYKKYYYN...",
            "....NNYYYYNN....", ".....NN..NN.....", ".......GG.......", "....GG.GG.......",
            ".....GGGG..GG...", ".......GGGGG....", ".......GG.......", "................"
        ],
        "forest-moss": [
            "...........W....", "..........W.....", "....MMMMM..WW...", "..MMGMMMMMM.....",
            ".MMMMMMGMMMM....", ".AAMMMMMMMAAA...", "AAAAAAAAAAAAAA..", "AAKKAAAAAKKAAA..",
            "AAAAAAAAAAAAAA..", "AAAAAKKKKAAAAA..", ".AAAAAAAAAAAA...", "..AAAAAAAAAA....",
            "...AA......AA...", "................", "................", "................"
        ],
        "forest-acorn": [
            ".......H........", "......HH........", "....HHHHHHH.....", "...HTHTHTHTH....",
            "..HHHHHHHHHHH...", "...TTTTTTTTT....", "...TFFFFFFFT....", "...TFKFFFKFT....",
            "...TFFFFFFFT....", "...TFFFKKFFT....", "....TTTTTTT.....", ".....TTTTT......",
            "......TTT.......", "....H..T..H.....", ".....HH.HH......", "................"
        ],
        "forest-tree": [
            ".....GGGGGG.....", "...GGGMGGGGGG...", "..GGGGGGGGMGGG..", "..GMGGGGGGGGGG..",
            "..GGGGGGMGGGGG..", "...GGGGGGGGGG...", "....GGTTTTGG....", "......TTTT......",
            ".....TKTTKT.....", ".....TTTTTT.....", ".....TTKKTT.....", "..T..TTTTTT..T..",
            "...TTTTTTTTTT...", ".....TTTTTT.....", "....TT.TT.TT....", "................"
        ],
        "forest-elder": [
            "..MMGGGGGGGGMM..", ".MGGGMGGGGMGGGM.", "MGGGGGGGMGGGGGGM", "MGGMGGGGGGGGMGGM",
            ".MGGGGGGGGGGGGM.", "..HHTTTTTTTTHH..", "..HTTYYTTYYTTH..", "..HTTTTTTTTTTH..",
            "..HTTWWWWWWTTH..", "..HTWWWWWWWWTH..", "..HTTWWWWWWTTH..", "..HTTTWWWWTTTH..",
            "...HTTTTTTTTH...", "..HHTTTTTTTTHH..", ".HH.HH.HH.HH.HH.", "................"
        ],
        // Coral Deep: podmorsky svet
        "reef-seahorse": [
            "................", "......OOOO......", ".....OOOOOO.....", ".....OKOOOOOO...",
            ".....OOOO..OOO..", "......OOO.......", ".....OOYO.......", "....OOYYO.O.....",
            "....OOYYOOO.....", "....OOYYO.......", ".....OOYO.......", "......OOO.......",
            ".......OO.......", "........OO..O...", ".........OOOO...", "................"
        ],
        "reef-clownfish": [
            "................", "................", "................", "......OOOO......",
            "....OOWOOOWO..O.", "...OOOWOOOWOOOO.", "..OKOOWOOOWOOOO.", "..OOOOWOOOWOOO..",
            "...OOOWOOOWOOOO.", "....OOWOOOWO..O.", "......OOOO......", "................",
            "................", "................", "................", "................"
        ],
        "reef-jelly": [
            "................", ".....NNNNNN.....", "...NNNNNNNNNN...", "..NNNWNNNNNNNN..",
            "..NNNNNNNNNNNN..", "..NNNKNNNNKNNN..", "..NNNNNNNNNNNN..", "..NNNNNKKNNNNN..",
            "...NNNNNNNNNN...", "...P.P.PP.P.P...", "...P.P.PP.P.P...", "..P..P.P..P..P..",
            "..P.P..P..P.P...", "...P...P...P....", "...P...P...P....", "................"
        ],
        "reef-urchin": [
            "................", ".......D........", "...D...D...D....", "....D.PPP.D.....",
            "..D..PPPPP..D...", "...DPPPPPPPD....", ".DDPPWKPWKPPDD..", "...PPPPPPPPP....",
            ".DDPPPPKKPPPDD..", "...DPPPPPPPD....", "..D..PPPPP..D...", "....D.PPP.D.....",
            "...D...D...D....", ".......D........", "................", "................"
        ],
        "reef-octopus": [
            "................", ".....RRRRRR.....", "....RRRRRRRR....", "...RRRRRRRRRR...",
            "...RRWKRRWKRR...", "...RRRRRRRRRR...", "...RRRRKKRRRR...", "....RRRRRRRR....",
            "..RRRRRRRRRRRR..", ".RR.RR.RR.RR.RR.", ".R..R..RR..R..R.", "RR.RR..RR..RR.RR",
            "R..R...R....R..R", "...R..R..R..R...", "................", "................"
        ],
        "reef-shark": [
            "................", ".......A........", "......AA........", ".....AAA........",
            "...AAAAAAAAA....", "..AAAAAAAAAAAA.A", ".AAKAAAAAAAAAAAA", "AAAAAAAAAAAAAA.A",
            "AWWWWWWWWWAAA...", "AWKWKWKWWWAA....", ".AWWWWWWWAA.....", "..AAAAAAAA......",
            "....AA....TT....", "..........TT....", "................", "................"
        ],
        "reef-kraken": [
            "....PPPPPPPP....", "...PPPPPPPPPP...", "..PPPPPPPPPPPP..", "..PPYKPPPPYKPP..",
            "..PPYYPPPPYYPP..", "..PPPPPPPPPPPP..", "..PPPKKKKKKPPP..", "..PPPPWPPWPPPP..",
            ".PPPPPPPPPPPPPP.", "PP.PP.PPPP.PP.PP", "P..P..P..P..P..P", "PP.PP.PP.PP.PP.P",
            ".P..P..P..P..P..", "PP.PP..PP..PP.PP", "P...P..P....P..P", "................"
        ],
        // Snoozeville High: americka stredni skola
        "hs-nerd": [
            "................", ".....DDDDDD.....", "....DDDDDDDD....", "....DFFFFFFD....",
            "....KKKFFKKK....", "....KWKFFKWK....", "....FFFFFFFF....", ".....FFKKFF.....",
            "......FFFF......", "....WBBBBBBW....", "...FWBBWWBBWF...", "...F.BBBBBB.F...",
            ".....UUUUUU.....", ".....UU..UU.....", ".....KK..KK.....", "................"
        ],
        "hs-emo": [
            "................", "....KKKKKKK.....", "...KKKKKKKKK....", "...KKKKKEEEK....",
            "...KKKKEEEEK....", "...KKKKEEKEK....", "....KKKEEEEK....", ".....KEEPPE.....",
            "......EEEE......", "....KKKKKKKK....", "...KKPKKKKPKK...", "...E.KKKKKK.E...",
            "....UUUUUUUU....", "....UUU..UUU....", "....KKK..KKK....", "................"
        ],
        "hs-cheer": [
            "..........YY....", ".....YYYYYYY....", "....YYYYYYYY....", "....YFFFFFFY....",
            "....FKFFFFKF....", "....FFFFFFFF....", ".....FFRRFF.....", "......FFFF......",
            "YY..RRRRRRRR..YY", "YYYFRRWWWWRRFYYY", "YY...RRRRRR...YY", ".....WWWWWW.....",
            ".....WWWWWW.....", ".....FF..FF.....", ".....WW..WW.....", "................"
        ],
        "hs-gymbro": [
            "................", ".....TTTTTT.....", ".....RRRRRR.....", ".....FFFFFF.....",
            ".....FKFFKF.....", ".....FFFFFF.....", "......FKKF......", "..FFF.FFFF.FFF..",
            ".FFFFFAAAAFFFFF.", ".FFF.AAAAAA.FFF.", ".FF..AAAAAA..FF.", "KKKK.AAAAAA.KKKK",
            ".....DDDDDD.....", ".....DD..DD.....", ".....WW..WW.....", "................"
        ],
        "hs-hoops": [
            "................", ".....KKKKKK.....", "....KKKKKKKK....", "....KTTTTTTK....",
            "....TKTTTTKT....", "....TTTTTTTT....", ".....TTWWTT.....", "......TTTT......",
            "....PPPPPPPP....", "...TPPWWWWPPT...", "...TPPPWWPPPT...", "...T.PPPPPP.OO..",
            ".....PPPPPP.OO..", ".....TT..TT.....", ".....WW..WW.....", "................"
        ],
        "hs-quarterback": [
            "................", "....RRRRRRR.....", "...RRRRRRRRR....", "...RRWRRRRRR....",
            "...RRFFFFFRR....", "...RAKFFKFAR....", "...RAAAAAAAR....", "....AFFFFFA.....",
            "..RRRRRRRRRRRR..", ".RRRRRWWWRRRRRR.", ".RR.RRRWRRRR.RR.", ".FF.RRRWRRRR.TT.",
            ".....WWWWWW..TT.", ".....WW..WW.....", ".....KK..KK.....", "................"
        ],
        "hs-principal": [
            "................", "....AA....AA....", "....AFFFFFFA....", "....FFFFFFFF....",
            "....KKKFFKKK....", "....FWKFFKWF....", "....FFFFFFFF....", "....FAAAAAAF....",
            "......FFFF......", "...UUUUWWUUUU...", "..UUUUUWRWUUUU..", "..UU.UUURUUU.UU.",
            "..FF.UUURUUU.EE.", ".....UUUUUU..EE.", ".....UU..UU.....", ".....KK..KK....."
        ]
    ]
}
