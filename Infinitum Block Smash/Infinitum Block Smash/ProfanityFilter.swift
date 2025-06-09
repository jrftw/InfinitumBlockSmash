import Foundation

class ProfanityFilter {
    private static let inappropriateWords: Set<String> = [
        "abortion",
        "abuse",
        "agender",
        "anal",
        "arsehole",
        "asexual",
        "bastard",
        "bdsm",
        "beaner",
        "bigender",
        "bitch",
        "blowjob",
        "bomb",
        "bong",
        "cannibal",
        "chink",
        "cholo",
        "cisgender",
        "clitoris",
        "cocaine",
        "cock",
        "coon",
        "crack",
        "cracker",
        "crap",
        "cum",
        "cumshot",
        "cunt",
        "dead",
        "deadbeat",
        "decapitation",
        "depression",
        "dick",
        "douche",
        "dyke",
        "ecstasy",
        "ejaculate",
        "erection",
        "euthanasia",
        "execution",
        "fag",
        "faggot",
        "feces",
        "fetish",
        "fuck",
        "fucktard",
        "fundie",
        "gangbang",
        "gay",
        "genderfluid",
        "genocide",
        "gipsy",
        "goyim",
        "heeb",
        "heroin",
        "hinduphobia",
        "homeless",
        "homo",
        "honky",
        "intersex",
        "isai",
        "itzig",
        "jaffa",
        "jew",
        "jihadi",
        "kaffir",
        "kike",
        "kill",
        "kink",
        "lesbian",
        "lgbt",
        "lsd",
        "lynching",
        "marijuana",
        "massacre",
        "masturbate",
        "mcfagget",
        "meth",
        "midget",
        "minge",
        "miscarriage",
        "molly",
        "motherfucker",
        "mulatto",
        "murder",
        "mutilation",
        "nazi",
        "negro",
        "nig",
        "nigga",
        "nigger",
        "onlyfans",
        "orangie",
        "orgasm",
        "paki",
        "pansexual",
        "penis",
        "porn",
        "pornography",
        "poverty",
        "psycho",
        "ptsd",
        "punk",
        "pussy",
        "queer",
        "rape",
        "redneck",
        "refugee",
        "retard",
        "saaI",
        "schizophrenic",
        "sex",
        "sexuality",
        "shaveling",
        "shit",
        "shoot",
        "shooting",
        "slut",
        "spaz",
        "sped",
        "squaw",
        "squirting",
        "Substance",
        "suicidal",
        "suicide",
        "terrorist",
        "therapy",
        "threats",
        "threesome",
        "titties",
        "torture",
        "tranny",
        "transgender",
        "vagina",
        "welfare",
        "wetback",
        "whore"
    ]
    
    static func containsInappropriateLanguage(_ text: String) -> Bool {
        let normalizedText = text.lowercased()
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")
            .replacingOccurrences(of: "8", with: "b")
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "!", with: "i")
        
        // Check for exact word matches
        let words = normalizedText.components(separatedBy: CharacterSet.alphanumerics.inverted)
        if words.contains(where: { word in inappropriateWords.contains(word) }) {
            return true
        }
        
        // Check for partial matches (words containing inappropriate terms)
        for word in inappropriateWords {
            if normalizedText.contains(word) {
                return true
            }
        }
        
        // Check for leetspeak variations
        for word in inappropriateWords {
            let leetVariations = generateLeetVariations(word)
            for variation in leetVariations {
                if normalizedText.contains(variation) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func generateLeetVariations(_ word: String) -> [String] {
        var variations = [word]
        
        // Common leetspeak substitutions
        let substitutions: [Character: [Character]] = [
            "a": ["4", "@"],
            "e": ["3"],
            "i": ["1", "!"],
            "o": ["0"],
            "s": ["5", "$"],
            "t": ["7"],
            "b": ["8"]
        ]
        
        // Generate variations with leetspeak substitutions
        for (char, replacements) in substitutions {
            if word.contains(char) {
                for replacement in replacements {
                    let variation = word.replacingOccurrences(of: String(char), with: String(replacement))
                    variations.append(variation)
                }
            }
        }
        
        return variations
    }
    
    static func isAppropriate(_ text: String) -> Bool {
        return !containsInappropriateLanguage(text)
    }
} 