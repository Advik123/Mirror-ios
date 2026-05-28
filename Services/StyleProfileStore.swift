import Foundation

struct StyleProfileStore {
    private static let key = "styleProfile"

    func save(_ profile: StyleProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func load() -> StyleProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let profile = try? JSONDecoder().decode(StyleProfile.self, from: data)
        else { return nil }
        return profile
    }
}
