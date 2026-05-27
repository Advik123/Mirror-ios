import Foundation
import UIKit

// MARK: - Configuration
private let baseAPIURL = "https://yce-api-01.makeupar.com"

enum PerfectCorpError: LocalizedError {
    case imagePreparationFailed
    case requestFailed(Int, String)
    case invalidResponse(String)
    case taskFailed(String)
    case taskTimedOut
    
    var errorDescription: String? {
        switch self {
        case .imagePreparationFailed:
            return "Failed to prepare one or both images for upload."
        case .requestFailed(let code, let message):
            return "Perfect Corp API returned status \(code): \(message)"
        case .invalidResponse(let msg):
            return msg
        case .taskFailed(let message):
            return "Perfect Corp task failed: \(message)"
        case .taskTimedOut:
            return "Perfect Corp task did not finish in time. Please try again."
        }
    }
}

final class PerfectCorpService {
    private var cachedTextToImageTemplateID: String?

    func generateTryOn(
        userPhoto: UIImage,
        outfitPhoto: UIImage,
        garmentCategory: String = "auto"
    ) async throws -> UIImage {
        guard
            let personImageData = prepareImage(userPhoto),
            let outfitImageData = prepareImage(outfitPhoto)
        else {
            throw PerfectCorpError.imagePreparationFailed
        }

        let personFileID = try await uploadImage(
            personImageData,
            fileName: "person.jpg"
        )
        let outfitFileID = try await uploadImage(
            outfitImageData,
            fileName: "outfit.jpg"
        )
        let taskID = try await createTryOnTask(
            personFileID: personFileID,
            outfitFileID: outfitFileID,
            garmentCategory: garmentCategory
        )
        let resultURL = try await pollForResultURL(taskID: taskID)

        return try await downloadImage(from: resultURL)
    }

    func generateOutfitPreview(prompt: String) async throws -> UIImage {
        let templateID = try await fetchTextToImageTemplateID()
        let taskID = try await createTextToImageTask(prompt: prompt, templateID: templateID)
        let resultURL = try await pollTextToImageResultURL(taskID: taskID)

        return try await downloadImage(from: resultURL)
    }

    private func fetchTextToImageTemplateID() async throws -> String {
        if let cachedTextToImageTemplateID {
            return cachedTextToImageTemplateID
        }

        let templateResponse: PerfectCorpTextToImageTemplatesData = try await get(
            path: "/s2s/v2.0/task/template/text-to-image?page_size=20"
        )

        let fashionKeywords = ["fashion", "cloth", "outfit", "style", "lookbook", "editorial"]
        let preferredTemplate = templateResponse.templates.first { template in
            let searchable = "\(template.title) \(template.categoryName)".lowercased()
            return fashionKeywords.contains { searchable.contains($0) }
        }

        guard let templateID = (preferredTemplate ?? templateResponse.templates.first)?.id else {
            throw PerfectCorpError.invalidResponse("Perfect Corp did not return a text-to-image template.")
        }

        cachedTextToImageTemplateID = templateID
        return templateID
    }

    private func createTextToImageTask(prompt: String, templateID: String) async throws -> String {
        let enhancedPrompt = """
        \(prompt.trimmingCharacters(in: .whitespacesAndNewlines)). \
        High-quality fashion photography, sharp focus, even studio lighting, plain background, \
        front-facing standing pose, entire outfit clearly visible.
        """

        let taskResponse: PerfectCorpTaskData = try await post(
            path: "/s2s/v2.0/task/text-to-image",
            body: PerfectCorpTextToImageRequest(
                prompt: enhancedPrompt,
                negativePrompt: "flat-lay, top-down, product collage, multiple garments laid out, back view, side profile, sitting, crouching, blurry, distorted, watermark, text overlay, multiple people, obscured clothing",
                templateID: templateID,
                widthRatio: 3,
                heightRatio: 4,
                steps: 20,
                cfgScale: 7
            )
        )

        return taskResponse.taskID
    }

    private func pollTextToImageResultURL(taskID: String) async throws -> URL {
        let maxAttempts = 45
        let pollingDelayNanoseconds: UInt64 = 2_000_000_000
        let encodedTaskID = urlPathComponent(taskID)

        for attempt in 1...maxAttempts {
            let statusResponse: PerfectCorpTaskStatusData = try await get(
                path: "/s2s/v2.0/task/text-to-image/\(encodedTaskID)"
            )

            switch statusResponse.taskStatus {
            case "success":
                guard let url = statusResponse.results?.firstResultURL else {
                    throw PerfectCorpError.invalidResponse("Perfect Corp text-to-image task succeeded but did not include a result URL.")
                }

                return url
            case "error":
                let message = statusResponse.errorMessage ?? statusResponse.error ?? "Unknown task error."
                throw PerfectCorpError.taskFailed(message)
            default:
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: pollingDelayNanoseconds)
                }
            }
        }

        throw PerfectCorpError.taskTimedOut
    }

    private func prepareImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let originalSize = image.size
        let longestSide = max(originalSize.width, originalSize.height)

        guard originalSize.width > 0, originalSize.height > 0, longestSide > 0 else {
            return nil
        }

        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let targetSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.85)
    }

    private func uploadImage(_ imageData: Data, fileName: String) async throws -> String {
        let uploadResponse: PerfectCorpFileData = try await post(
            path: "/s2s/v2.0/file/cloth",
            body: PerfectCorpFileRequest(
                files: [
                    PerfectCorpFileDescriptor(
                        contentType: "image/jpg",
                        fileName: fileName,
                        fileSize: imageData.count
                    )
                ]
            )
        )

        guard let file = uploadResponse.files.first else {
            throw PerfectCorpError.invalidResponse("Perfect Corp File API did not return a file.")
        }

        guard let uploadRequest = file.requests.first else {
            throw PerfectCorpError.invalidResponse("Perfect Corp File API did not return an upload request.")
        }

        try await uploadImageData(imageData, using: uploadRequest)
        return file.fileID
    }

    private func uploadImageData(_ imageData: Data, using uploadRequest: PerfectCorpUploadRequest) async throws {
        guard let url = URL(string: uploadRequest.url) else {
            throw PerfectCorpError.invalidResponse("Perfect Corp File API returned an invalid upload URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = uploadRequest.method

        for (name, value) in uploadRequest.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if uploadRequest.headers["Content-Type"] == nil {
            request.setValue("image/jpg", forHTTPHeaderField: "Content-Type")
        }

        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerfectCorpError.invalidResponse("Perfect Corp upload returned a non-HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PerfectCorpError.requestFailed(
                httpResponse.statusCode,
                responseBody(from: data)
            )
        }
    }

    private func createTryOnTask(
        personFileID: String,
        outfitFileID: String,
        garmentCategory: String
    ) async throws -> String {
        let taskResponse: PerfectCorpTaskData = try await post(
            path: "/s2s/v2.0/task/cloth",
            body: PerfectCorpTaskRequest(
                srcFileID: personFileID,
                refFileID: outfitFileID,
                garmentCategory: garmentCategory,
                changeShoes: garmentCategory == "full_body" || garmentCategory == "shoes"
            )
        )

        return taskResponse.taskID
    }

    private func pollForResultURL(taskID: String) async throws -> URL {
        let maxAttempts = 45
        let pollingDelayNanoseconds: UInt64 = 2_000_000_000
        let encodedTaskID = urlPathComponent(taskID)

        for attempt in 1...maxAttempts {
            let statusResponse: PerfectCorpTaskStatusData = try await get(
                path: "/s2s/v2.0/task/cloth/\(encodedTaskID)"
            )

            switch statusResponse.taskStatus {
            case "success":
                guard
                    let urlString = statusResponse.results?.url,
                    !urlString.isEmpty,
                    let url = URL(string: urlString)
                else {
                    throw PerfectCorpError.invalidResponse("Perfect Corp task succeeded but did not include a result URL.")
                }

                return url
            case "error":
                let message = statusResponse.errorMessage ?? statusResponse.error ?? "Unknown task error."
                throw PerfectCorpError.taskFailed(message)
            default:
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: pollingDelayNanoseconds)
                }
            }
        }

        throw PerfectCorpError.taskTimedOut
    }

    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerfectCorpError.invalidResponse("Perfect Corp result download returned a non-HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PerfectCorpError.requestFailed(
                httpResponse.statusCode,
                responseBody(from: data)
            )
        }

        guard let image = UIImage(data: data) else {
            throw PerfectCorpError.invalidResponse("Could not decode Perfect Corp result image.")
        }

        return image
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = try makeAuthenticatedRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return try await send(request)
    }

    private func get<ResponseBody: Decodable>(path: String) async throws -> ResponseBody {
        var request = try makeAuthenticatedRequest(path: path)
        request.httpMethod = "GET"

        return try await send(request)
    }

    private func makeAuthenticatedRequest(path: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseAPIURL)\(path)") else {
            throw PerfectCorpError.invalidResponse("Perfect Corp endpoint is not a valid URL.")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(APIKeys.perfectCorp)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<ResponseBody: Decodable>(_ request: URLRequest) async throws -> ResponseBody {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerfectCorpError.invalidResponse("Perfect Corp API returned a non-HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PerfectCorpError.requestFailed(
                httpResponse.statusCode,
                responseBody(from: data)
            )
        }

        do {
            let response = try JSONDecoder().decode(PerfectCorpResponse<ResponseBody>.self, from: data)

            guard response.status == 200 else {
                let message = response.errorMessage ?? response.error ?? responseBody(from: data)
                throw PerfectCorpError.requestFailed(response.status, message)
            }

            guard let responseData = response.data else {
                throw PerfectCorpError.invalidResponse("Perfect Corp API response did not include data.")
            }

            return responseData
        } catch let error as PerfectCorpError {
            throw error
        } catch {
            throw PerfectCorpError.invalidResponse("Could not decode Perfect Corp response: \(responseBody(from: data))")
        }
    }

    private func responseBody(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "No response body"
    }

    private func urlPathComponent(_ value: String) -> String {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
    }
}

private struct PerfectCorpResponse<ResponseData: Decodable>: Decodable {
    let status: Int
    let data: ResponseData?
    let error: String?
    let errorCode: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case status
        case data
        case error
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }
}

private struct PerfectCorpFileRequest: Encodable {
    let files: [PerfectCorpFileDescriptor]
}

private struct PerfectCorpFileDescriptor: Encodable {
    let contentType: String
    let fileName: String
    let fileSize: Int

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case fileName = "file_name"
        case fileSize = "file_size"
    }
}

private struct PerfectCorpFileData: Decodable {
    let files: [PerfectCorpFile]
}

private struct PerfectCorpFile: Decodable {
    let fileID: String
    let requests: [PerfectCorpUploadRequest]

    enum CodingKeys: String, CodingKey {
        case fileID = "file_id"
        case requests
    }
}

private struct PerfectCorpUploadRequest: Decodable {
    let method: String
    let url: String
    let headers: [String: String]

    enum CodingKeys: String, CodingKey {
        case method
        case url
        case headers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        method = try container.decode(String.self, forKey: .method)
        url = try container.decode(String.self, forKey: .url)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
    }
}

private struct PerfectCorpTextToImageRequest: Encodable {
    let prompt: String
    let negativePrompt: String
    let templateID: String
    let widthRatio: Int
    let heightRatio: Int
    let steps: Int
    let cfgScale: Int

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt = "negative_prompt"
        case templateID = "template_id"
        case widthRatio = "width_ratio"
        case heightRatio = "height_ratio"
        case steps
        case cfgScale = "cfg_scale"
    }
}

private struct PerfectCorpTextToImageTemplatesData: Decodable {
    let templates: [PerfectCorpTextToImageTemplate]
}

private struct PerfectCorpTextToImageTemplate: Decodable {
    let id: String
    let title: String
    let categoryName: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case categoryName = "category_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
    }
}

private struct PerfectCorpTaskRequest: Encodable {
    let srcFileID: String
    let refFileID: String
    let garmentCategory: String
    let changeShoes: Bool

    enum CodingKeys: String, CodingKey {
        case srcFileID = "src_file_id"
        case refFileID = "ref_file_id"
        case garmentCategory = "garment_category"
        case changeShoes = "change_shoes"
    }
}

private struct PerfectCorpTaskData: Decodable {
    let taskID: String

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
    }
}

private struct PerfectCorpTaskStatusData: Decodable {
    let taskStatus: String
    let error: String?
    let errorMessage: String?
    let results: PerfectCorpTaskResults?

    enum CodingKeys: String, CodingKey {
        case taskStatus = "task_status"
        case error
        case errorMessage = "error_message"
        case results
    }
}

private struct PerfectCorpTaskResults: Decodable {
    let url: String?
    let output: [PerfectCorpOutputItem]?

    var firstResultURL: URL? {
        if let urlString = url, !urlString.isEmpty, let url = URL(string: urlString) {
            return url
        }

        if let output {
            for item in output {
                if let urlString = item.url, !urlString.isEmpty, let url = URL(string: urlString) {
                    return url
                }
            }
        }

        return nil
    }
}

private struct PerfectCorpOutputItem: Decodable {
    let url: String?
}
