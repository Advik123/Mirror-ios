import Foundation

struct OutfitSuggestion: Codable, Hashable {
    let reply: String
    let outfitDescription: String
    let imagenPrompt: String
    /// Perfect Corp try-on category: upper_body, full_body, lower_body, or shoes.
    let garmentCategory: String
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var text: String

    enum Role {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
