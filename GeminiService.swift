import UIKit

enum GeminiError: LocalizedError {
    case imageEncodingFailed
    case requestFailed(Int)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode one or both images."
        case .requestFailed(let code):
            return "Gemini API returned status \(code)."
        case .invalidResponse(let msg):
            return msg
        }
    }
}

final class GeminiService {
    func analyzeOutfit(userPhoto: UIImage, outfitPhoto: UIImage) async throws -> VerdictResult {
        guard
            let userPhotoBase64 = prepareImage(userPhoto),
            let outfitPhotoBase64 = prepareImage(outfitPhoto)
        else {
            throw GeminiError.imageEncodingFailed
        }

        let profileContext: String
        if let profile = StyleProfileStore().load() {
            profileContext = profile.geminiContext + " "
        } else {
            profileContext = ""
        }

        let systemInstruction = """
        \(profileContext)You are a professional fashion stylist and color analyst. You will receive two images: the first is a photo of a person, the second is a photo of an outfit. Analyze whether the outfit suits the person based on (1) color harmony — does the outfit's color palette complement the person's skin tone and undertone, (2) silhouette compatibility — does the outfit's fit and structure flatter the person's body proportions, and (3) gender appropriateness — is the outfit designed for the person's gender presentation (use their stated shopping preference from context when provided; otherwise infer from the person photo). Treat a clear mismatch in gendered garment type or cut (e.g. a women's dress on someone who presents masculine and shops men's fashion) as a strong reason for a No verdict even when colors align. Unisex or androgynous pieces can suit any presentation. Mention gender fit briefly in the reasoning when it affects the verdict. Do not consider occasion. Return ONLY a valid JSON object with no markdown, no code fences, no explanation outside the JSON: { "verdict": true or false, "reasoning": "2-3 sentences of plain English explanation" }
        """

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=\(APIKeys.gemini)") else {
            throw GeminiError.invalidResponse("Invalid Gemini API URL.")
        }

        let requestBody = GeminiRequest(
            systemInstruction: GeminiContent(
                parts: [
                    GeminiPart(text: systemInstruction)
                ]
            ),
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/jpeg",
                                data: userPhotoBase64
                            )
                        ),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/jpeg",
                                data: outfitPhotoBase64
                            )
                        )
                    ]
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse("Gemini API returned a non-HTTP response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw GeminiError.invalidResponse("Gemini API returned status \(httpResponse.statusCode): \(responseBody)")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let rawText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse("Gemini response did not include verdict text.")
        }

        let cleanedText = cleanedJSON(from: rawText)

        do {
            return try JSONDecoder().decode(
                VerdictResult.self,
                from: Data(cleanedText.utf8)
            )
        } catch {
            throw GeminiError.invalidResponse("Could not parse verdict JSON: \(rawText)")
        }
    }

    private func prepareImage(_ image: UIImage) -> String? {
        let maxDimension: CGFloat = 1024
        let longestSide = max(image.size.width, image.size.height)
        let processedImage: UIImage

        if longestSide > maxDimension {
            let scale = maxDimension / longestSide
            let targetSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: targetSize)
            processedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            processedImage = image
        }

        return processedImage.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }

    private func cleanedJSON(from text: String) -> String {
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedText.hasPrefix("```json") {
            cleanedText.removeFirst("```json".count)
        } else if cleanedText.hasPrefix("```") {
            cleanedText.removeFirst("```".count)
        }

        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedText.hasSuffix("```") {
            cleanedText.removeLast("```".count)
        }

        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GeminiRequest: Encodable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: GeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}
