import UIKit

enum StylistChatError: LocalizedError {
    case imageEncodingFailed
    case requestFailed(Int)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode your profile photo."
        case .requestFailed(let code):
            return "Stylist API returned status \(code)."
        case .invalidResponse(let message):
            return message
        }
    }
}

final class StylistChatService {
    func suggestOutfitStreaming(
        userMessage: String,
        userPhoto: UIImage?,
        onPartialReply: @MainActor @escaping (String) -> Void
    ) async throws -> OutfitSuggestion {
        let requestBody = try buildRequestBody(userMessage: userMessage, userPhoto: userPhoto)

        guard let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:streamGenerateContent?key=\(APIKeys.gemini)&alt=sse"
        ) else {
            throw StylistChatError.invalidResponse("Invalid Gemini API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StylistChatError.invalidResponse("Stylist API returned a non-HTTP response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let responseBody = String(data: errorData, encoding: .utf8) ?? "No response body"
            throw StylistChatError.invalidResponse("Stylist API returned status \(httpResponse.statusCode): \(responseBody)")
        }

        var accumulated = ""
        var lastPartialReply = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else {
                continue
            }

            let payload = String(line.dropFirst(6))
            guard
                let data = payload.data(using: .utf8),
                let chunk = try? JSONDecoder().decode(StylistGeminiResponse.self, from: data),
                let text = chunk.candidates.first?.content.parts.first?.text
            else {
                continue
            }

            accumulated += text

            let partialReply = extractStreamingReply(from: accumulated)
            if partialReply != lastPartialReply {
                lastPartialReply = partialReply
                await onPartialReply(partialReply)
            }
        }

        return try parseSuggestion(from: accumulated)
    }

    private func buildRequestBody(userMessage: String, userPhoto: UIImage?) throws -> StylistGeminiRequest {
        let profileContext: String
        if let profile = StyleProfileStore().load() {
            profileContext = profile.geminiContext + " "
        } else {
            profileContext = ""
        }

        let systemInstruction = """
        \(profileContext)You are a professional fashion stylist. The user will ask what they should wear or describe the kind of outfit they want. Give personalized advice based on their request\(userPhoto != nil ? ", their photo (skin tone, proportions, and gender presentation)" : "").

        Recommend only garments appropriate for the user's gender (from profile context when provided; otherwise infer from their photo). Use correct gendered categories and cuts in outfitDescription and imagenPrompt (e.g. men's chinos and oxford shirt vs women's wide-leg trousers and silk blouse). Do not suggest pieces clearly meant for a different gender presentation unless the user explicitly asks for cross-gender or androgynous styling.

        Return ONLY a valid JSON object with no markdown, no code fences, no text outside the JSON:
        {
          "reply": "2-4 sentences of friendly stylist advice answering their question",
          "outfitDescription": "brief comma-separated list of gender-appropriate clothing items and colors",
          "garmentCategory": "upper_body or full_body — use full_body when the outfit includes pants, jeans, shorts, a skirt, or a dress; otherwise upper_body",
          "imagenPrompt": "A detailed English prompt for a fashion lookbook photo of one model wearing the complete outfit, front-facing, standing straight, plain light gray studio background, sharp focus, even lighting. Face visible. Entire outfit clearly visible on the body. No flat-lay, no collage, no separate product shots."
        }

        The imagenPrompt must describe a worn outfit on one model (not a flat-lay or composite product image). Keep the prompt under 480 characters.
        """

        var parts: [StylistGeminiPart] = [
            StylistGeminiPart(text: userMessage)
        ]

        if let userPhoto, let userPhotoBase64 = prepareImage(userPhoto) {
            parts.insert(
                StylistGeminiPart(
                    inlineData: StylistGeminiInlineData(
                        mimeType: "image/jpeg",
                        data: userPhotoBase64
                    )
                ),
                at: 0
            )
        }

        return StylistGeminiRequest(
            systemInstruction: StylistGeminiContent(
                parts: [StylistGeminiPart(text: systemInstruction)]
            ),
            contents: [
                StylistGeminiContent(parts: parts)
            ]
        )
    }

    private func parseSuggestion(from rawText: String) throws -> OutfitSuggestion {
        let cleanedText = cleanedJSON(from: rawText)

        do {
            return try JSONDecoder().decode(
                OutfitSuggestion.self,
                from: Data(cleanedText.utf8)
            )
        } catch {
            throw StylistChatError.invalidResponse("Could not parse stylist JSON: \(rawText)")
        }
    }

    private func extractStreamingReply(from raw: String) -> String {
        guard let replyRange = raw.range(of: "\"reply\"") else {
            return ""
        }

        var remainder = raw[replyRange.upperBound...]
            .trimmingCharacters(in: .whitespaces)

        guard let colonIndex = remainder.firstIndex(of: ":") else {
            return ""
        }

        remainder = remainder[remainder.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespaces)

        guard remainder.first == "\"" else {
            return ""
        }

        remainder.removeFirst()

        var result = ""
        var index = remainder.startIndex

        while index < remainder.endIndex {
            let character = remainder[index]

            if character == "\\" {
                let nextIndex = remainder.index(after: index)
                guard nextIndex < remainder.endIndex else {
                    break
                }
                result.append(remainder[nextIndex])
                index = remainder.index(after: nextIndex)
                continue
            }

            if character == "\"" {
                break
            }

            result.append(character)
            index = remainder.index(after: index)
        }

        return result
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

private struct StylistGeminiRequest: Encodable {
    let systemInstruction: StylistGeminiContent
    let contents: [StylistGeminiContent]

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

private struct StylistGeminiContent: Codable {
    let parts: [StylistGeminiPart]
}

private struct StylistGeminiPart: Codable {
    let text: String?
    let inlineData: StylistGeminiInlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: StylistGeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct StylistGeminiInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct StylistGeminiResponse: Decodable {
    let candidates: [StylistGeminiCandidate]
}

private struct StylistGeminiCandidate: Decodable {
    let content: StylistGeminiContent
}
