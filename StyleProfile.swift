import Foundation

struct StyleProfile: Codable {
    var styleVibes: [StyleVibe]
    var priority: StylePriority
    var bodyType: BodyType
    var gender: Gender?

    // MARK: - Enums

    enum StyleVibe: String, Codable, CaseIterable {
        case minimalist = "Minimalist"
        case streetwear = "Streetwear"
        case classic    = "Classic"
        case bold       = "Bold"
        case bohemian   = "Bohemian"
    }

    enum StylePriority: String, Codable, CaseIterable {
        case colorHarmony  = "Color Harmony"
        case silhouetteFit = "Silhouette Fit"
        case overallVibe   = "Overall Vibe"
    }

    enum BodyType: String, Codable, CaseIterable {
        case petite   = "Petite"
        case athletic = "Athletic"
        case curvy    = "Curvy"
        case tall     = "Tall"
        case average  = "Average"
    }

    enum Gender: String, Codable, CaseIterable {
        case womens = "Women's"
        case mens   = "Men's"
    }

    // MARK: - Gemini context string

    var geminiContext: String {
        let vibes = styleVibes.map(\.rawValue).joined(separator: " and ")
        var context = "The user has a \(vibes) aesthetic, prioritizes \(priority.rawValue.lowercased()), and has a \(bodyType.rawValue.lowercased()) body type."
        if let gender {
            context += " They shop \(gender.rawValue) fashion and want recommendations and verdicts for \(gender.rawValue.lowercased()) garments."
        } else {
            context += " Infer their gender presentation from their photo when available."
        }
        return context + " Factor all of this into your analysis."
    }
}
