import Foundation

// MARK: - Bossove svetu (16x16, kazdy znak = jeden pixel, "." = pruhledne)
// Vlastni parodicke postavicky: jmena i vzhled jsou jen volne inspirovane archetypy.

extension SpritePalette {
    /// Zelvi ninjove sdileji jedno telo; "M" je barva satku a "X" zbran.
    private static func turtle(mask: Character, weapon: Character) -> [String] {
        [
            "................",
            ".....GGGGGG.....",
            "....GGGGGGGG....",
            "...MMMMMMMMMMM..",
            "...MWKMMMWKMMMM.",
            "....GGGGGGGG..M.",
            "....GGKKKKGG....",
            "..X..GGGGGG..X..",
            "..XGTTYYYYTTGX..",
            "..XGTYYYYYYTGX..",
            "..GGTTTTTTTTGG..",
            "....TYYYYYYT....",
            ".....GG..GG.....",
            ".....GG..GG.....",
            "....GGG..GGG....",
            "................"
        ].map { row in
            String(row.map { $0 == "M" ? mask : ($0 == "X" ? weapon : $0) })
        }
    }

    static let worldBossRows: [String: [String]] = [
        // Hero Heights
        "web-slacker": [
            "................", ".....RRRRRR.....", "....RRKRRKRR....", "....RWWKKWWR....",
            "....RWWKKWWR....", "....RRKRRKRR....", ".....RRKKRR.....", "...RRRRKKRRRR...",
            "..RRUURRRRUURR..", "..RR.UURRUU.RR..", "..FF.UUUUUU.FF..", ".....UUUUUU.....",
            ".....RR..RR.....", ".....RR..RR.....", "....RRR..RRR....", "................"
        ],
        "thunder-snooze": [
            "................", "..W..AAAAAA..W..", "..WWAAAAAAAAWW..", "....YFFFFFFY....",
            "....YFKKFKKY....", "....YFFFFFFY....", "....YYFNNFYY....", "...RAAAAAAAAR...",
            "..RRASSAASSARAAA", "..RRAAAAAAAARAAA", "..RR.UUUUUU.R.T.", "..RR.UUUUUU...T.",
            "..R..UU..UU.....", ".....UU..UU.....", "....TTT..TTT....", "................"
        ],
        "mr-incredulous": [
            "................", ".....TTTTTT.....", "....TFFFFFFT....", "....KKKKKKKK....",
            "....KWKFFWKK....", "....FFFFFFFF....", ".....FKKKKF.....", "..RRRRRRRRRRRR..",
            ".RRRRRYKKYRRRRR.", ".RRRRRKYYKRRRRR.", ".FFRRRRRRRRRRFF.", "....KKKKKKKK....",
            "....RRRRRRRR....", ".....RR..RR.....", "....KKK..KKK....", "................"
        ],
        "elasti-snooze": [
            "................", ".....TTTTTT.....", "....TTFFFFTT....", "...TTKKKKKKTT...",
            "...TTKWFFWKTT...", "....TFFFFFFT....", ".....FFNNFF.....", "....RRRRRRRRRRRR",
            "...RRRRYYRR...FF", "...RRRRRRRR.....", "...RR.KKKK......", ".....RRRRRR.....",
            ".....RR..RR.....", ".....RR..RR.....", "....KKK..KKK....", "................"
        ],
        "dash-distracted": [
            "................", "......YYYY......", ".....YYYYYY.....", "W....KKKKKK.....",
            "WW...KWFFWK.....", ".....FFFFFF.....", "W.....FKKF......", "WW...RRRRRR.....",
            "....RRYKKYRR....", "W...RRRRRRRR....", "WW..FRRRRRRF....", ".....KKKKKK.....",
            "W....RR..RR.....", "WW...RR...RR....", "....KKK....KK...", "................"
        ],
        "vanishing-violet": [
            "................", ".....KKKKKK.....", "....KKKKKKKK....", "...KKKKKKKKKK...",
            "...KKKWFFWKKK...", "...KKFFFFFFKK...", "...KK.FFFF.KK...", "...KAAAAAAAAK...",
            "...KAAAYYAAAA...", "....AAAAAAAA....", "....FAAAAAAF....", ".....KKKKKK.....",
            ".....AA..AA.....", ".....AA..AA.....", "....AAA..AAA....", "................"
        ],
        "jack-jack-attack": [
            "......O..O......", ".....OYOOYO.....", "....OYYOOYYO....", "....OFFFFFFO....",
            "...OFFKFFKFFO...", "...OFFFFFFFFO...", "....FFFNNFFF....", ".....FFFFFF.....",
            "....RRRRRRRR....", "...FRRRYYRRRF...", "...FRRRRRRRRF...", "....RRRRRRRR....",
            ".....RR..RR.....", "....OFF..FFO....", "...O........O...", "................"
        ],
        // Villain Vault
        "the-jokester": [
            "................", "....GGGGGGGG....", "...GGGGGGGGGG...", "...GGWWWWWWGG...",
            "....WKWWWWKW....", "....WWWWWWWW....", "....RRRRRRRR....", ".....RWWWWR.....",
            "...PPPGGGGPPP...", "..PPPPPGGPPPPP..", "..PP.PPPPPP.PP..", "..WW.PPPPPP.WW..",
            ".....PP..PP.....", ".....PP..PP.....", "....OOO..OOO....", "................"
        ],
        "venomeme": [
            "................", "....KKKKKKKK....", "...KKKKKKKKKK...", "..KWWWKKKKWWWK..",
            "..KWWWWKKWWWWK..", "..KKWWKKKKWWKK..", "..KKKKKKKKKKKK..", "..KWKWKWKWKWKK..",
            "..KKRRRRRRRRKK..", "..KWKWKWKRRWKK..", "...KKKKKKKRRK...", "..KKKKWKKKRRKK..",
            ".KKKKKWKKKKKKKK.", ".....KK..KK.....", "....KKK..KKK....", "................"
        ],
        "green-gobbler": [
            "................", ".....PPPPPP.....", "....PGGGGGGP....", "...PGGGGGGGGP...",
            "...PGYYGGYYGP...", "...PGGGGGGGGP...", "....GKWKWKWG....", ".....GGGGGG.....",
            "...GGPPPPPPGG...", "..GG.PPPPPP.GG..", "..O..GGGGGG..O..", ".....GGGGGG.....",
            ".....GG..GG.....", ".AAAAAAAAAAAAAA.", "..AAKAAAAAAKAA..", "................"
        ],
        "sandbagman": [
            "......EEEE......", "....EEYYYYEE....", "...EYYYYYYYYE...", "...YYFFFFFFYY...",
            "...YFKFFFFKFY...", "...YFFFFFFFFY...", "....FFFKKFFF....", ".....FFFFFF.....",
            "..EEGTGTGTGTEE..", ".EYYGTGTGTGTYYE.", "EYYYGTGTGTGTYYYE", ".EY.TTTTTTTT.YE.",
            "..YYYTT..TTYYY..", ".EYYYYEEEEYYYYE.", "EEYYYYYYYYYYYYEE", "................"
        ],
        // Sewer Dojo
        "leo-napardo": turtle(mask: "U", weapon: "A"),
        "raph-scroll": turtle(mask: "R", weapon: "A"),
        "do-not-tello": turtle(mask: "P", weapon: "T"),
        "mikey-snackelangelo": turtle(mask: "O", weapon: "T"),
        // Swamp Kingdom
        "swamp-ogre": [
            "................", ".GG..GGGGGG..GG.", "..GGGGGGGGGGGG..", "....GGGGGGGG....",
            "....GWKGGKWG....", "....GGGGGGGG....", "....GGKKKKGG....", ".....GGGGGG.....",
            "..TTEEEEEEEETT..", ".GTTEEEEEEEETTG.", ".GTTEEEEEEEETTG.", "..TTTTTTTTTTTT..",
            "....TTTTTTTT....", ".....TT..TT.....", "....KKK..KKK....", "................"
        ],
        "don-keyboard": [
            "...AA......AA...", "...AAA....AAA...", "....AAA..AAA....", ".....AAAAAA.....",
            "....AAWKKWAA....", "....AAAAAAAA....", "...AEEEEEEEEA...", "...AEWWWWWWEA...",
            "....AAAAAAAA....", "...AAAAAAAAAA...", "..WKWKWKWKWKW...", "..KKKKKKKKKKK...",
            "....AA....AA....", "....AA....AA....", "...KKK...KKK....", "................"
        ],
        "rapunzzzel": [
            "............W.W.", ".....YYYYYY..W..", "....YYYYYYYY....", "...YYFFFFFFYY...",
            "...YYFKFFKFYY...", "...YYFFFFFFYY...", "...YY.FNNF.YY...", "...YYPPPPPPYY...",
            "...YPPPPPPPPY...", "..YYPPNPPNPPYY..", "..YPPPPPPPPPPY..", "..YPPPPPPPPPPY..",
            "..YYPPPPPPPPYY..", "...YY.FF.FF.YY..", "....YYYYYYYYYY..", "................"
        ],
        "puss-in-popups": [
            "....R...........", ".....RTTTTTT....", "...TTTTTTTTTTT..", "....OO.OO.OO....",
            "...OOOOOOOOOO.RR", "...OOKKOOKKOO.RW", "...OOKWOOKWOO.RR", "....OOONNOOO....",
            ".....OOOOOO.....", "....OOTTTTOO....", "...O.OOOOOO.O...", ".....OOOOOO..O..",
            ".....OO..OO..O..", "....TTT..TTT....", "................", "................"
        ]
    ]
}
