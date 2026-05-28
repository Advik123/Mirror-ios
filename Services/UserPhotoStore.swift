import UIKit

struct UserPhotoStore {
    private var photoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("user_photo.jpg")
    }

    func savePhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        try? data.write(to: photoURL, options: [.atomic])
    }

    func loadPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL) else {
            return nil
        }

        return UIImage(data: data)
    }
}
