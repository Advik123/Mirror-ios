import SwiftUI
import UIKit

struct StylistChatView: View {
    let userPhoto: UIImage?
    @FocusState.Binding var isInputFocused: Bool
    let onTryItOn: (UIImage, UIImage) -> Void

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var loadingPhase: LoadingPhase?
    @State private var currentSuggestion: OutfitSuggestion?
    @State private var previewImage: UIImage?
    @State private var pipelineError: String?
    @State private var isTryOnLoading = false
    @State private var prefetchedTryOnImage: UIImage? = nil
    @State private var prefetchError: Error? = nil
    @State private var isPrefetching: Bool = false
    @State private var isShowingFullScreenPreview = false

    private let suggestionPrompts = [
        "Casual and comfy for today",
        "Smart casual for a dinner",
        "Minimalist weekend look"
    ]

    private enum LoadingPhase {
        case styling
        case generatingPreview

        var label: String {
            switch self {
            case .styling:
                return "CONSULTING YOUR STYLIST..."
            case .generatingPreview:
                return "CREATING OUTFIT PREVIEW..."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.gutter) {
            tappableDismissArea {
                header
            }

            if !messages.isEmpty {
                tappableDismissArea {
                    messageThread
                }
            }

            if let loadingPhase {
                tappableDismissArea {
                    loadingCard(loadingPhase)
                }
            }

            if let currentSuggestion, let previewImage, loadingPhase == nil {
                resultCard(suggestion: currentSuggestion, image: previewImage)
            }

            if let pipelineError, loadingPhase == nil {
                tappableDismissArea {
                    errorCard(pipelineError)
                }
            }

            suggestionChips

            inputBar
        }
        .padding(DesignSystem.gutter)
        .background {
            DesignSystem.surfaceContainerHigh
                .onTapGesture {
                    isInputFocused = false
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
        .fullScreenCover(isPresented: $isShowingFullScreenPreview) {
            if let previewImage {
                FullScreenImageViewer(uiImage: previewImage) {
                    isShowingFullScreenPreview = false
                }
            }
        }
    }

    private func tappableDismissArea<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.unit) {
            Text("STYLE ASSISTANT")
                .font(DesignSystem.labelSm)
                .foregroundColor(DesignSystem.onSurfaceVariant)
                .tracking(DesignSystem.trackingLabel)

            Text("Ask your outfit guy")
                .font(DesignSystem.headlineMd)
                .foregroundColor(DesignSystem.primary)
        }
    }

    private var messageThread: some View {
        VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
            ForEach(messages) { message in
                messageBubble(message)
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: DesignSystem.stackLg)
            }

            Text(message.text)
                .font(DesignSystem.bodyMd)
                .foregroundColor(message.role == .user ? DesignSystem.onPrimary : DesignSystem.onSurface)
                .padding(DesignSystem.stackSm)
                .background(message.role == .user ? DesignSystem.primary : DesignSystem.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))

            if message.role == .assistant {
                Spacer(minLength: DesignSystem.stackLg)
            }
        }
    }

    private func loadingCard(_ phase: LoadingPhase) -> some View {
        HStack(spacing: DesignSystem.stackSm) {
            ProgressView()
                .tint(DesignSystem.primary)

            Text(phase.label)
                .font(DesignSystem.labelSm)
                .foregroundColor(DesignSystem.onSurfaceVariant)
                .tracking(DesignSystem.trackingLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.gutter)
        .background(DesignSystem.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
    }

    private func resultCard(suggestion: OutfitSuggestion, image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.gutter) {
            tappableDismissArea {
                Text(suggestion.outfitDescription)
                    .font(DesignSystem.labelSm)
                    .foregroundColor(DesignSystem.onSurfaceVariant)
                    .tracking(DesignSystem.trackingLabel)
            }

            outfitPreviewImage(image)

            if isTryOnLoading {
                HStack(spacing: DesignSystem.stackSm) {
                    ProgressView()
                        .tint(DesignSystem.primary)

                    Text("GENERATING YOUR LOOK...")
                        .font(DesignSystem.labelSm)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                        .tracking(DesignSystem.trackingLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.gutter)
                .background(DesignSystem.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
            } else {
                Text("Try-on works best with a full-body profile photo in Settings.")
                    .font(DesignSystem.labelSm)
                    .foregroundColor(DesignSystem.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    isInputFocused = false
                    startTryOn(outfitImage: image, garmentCategory: suggestion.garmentCategory)
                } label: {
                    Label("TRY IT ON", systemImage: "camera.viewfinder")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(userPhoto == nil)

                if userPhoto == nil {
                    Text("Add a profile photo in Settings to try on outfits.")
                        .font(DesignSystem.labelSm)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                }
            }
        }
    }

    private func outfitPreviewImage(_ image: UIImage) -> some View {
        ContainedFitImage(uiImage: image)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.radiusLg)
                    .stroke(DesignSystem.surfaceVariant, lineWidth: DesignSystem.hairlineWidth)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
            .onTapGesture {
                isInputFocused = false
                isShowingFullScreenPreview = true
            }
            .accessibilityLabel("Outfit preview")
            .accessibilityHint("Double tap to view full screen")
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.stackSm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DesignSystem.stackMd, weight: .medium))
                .foregroundColor(DesignSystem.verdictNo)

            Text(message)
                .font(DesignSystem.bodyMd)
                .foregroundColor(DesignSystem.onSurface)
                .multilineTextAlignment(.leading)
        }
        .padding(DesignSystem.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surfaceContainerLow)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DesignSystem.verdictNo)
                .frame(width: DesignSystem.accentBorderWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.stackSm) {
                ForEach(suggestionPrompts, id: \.self) { prompt in
                    Button {
                        isInputFocused = false
                        submitMessage(prompt)
                    } label: {
                        Text(prompt)
                            .modifier(ChipStyle())
                    }
                    .buttonStyle(.plain)
                    .disabled(loadingPhase != nil)
                    .opacity(loadingPhase != nil ? DesignSystem.inactiveOpacity : 1)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: DesignSystem.stackSm) {
            TextField("What should I wear today?", text: $inputText, axis: .vertical)
                .font(DesignSystem.bodyMd)
                .lineLimit(1...3)
                .padding(DesignSystem.stackSm)
                .background(DesignSystem.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusLg)
                        .stroke(DesignSystem.surfaceVariant, lineWidth: DesignSystem.hairlineWidth)
                )
                .focused($isInputFocused)
                .disabled(loadingPhase != nil)

            Button {
                submitMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: DesignSystem.stackMd + DesignSystem.unit, weight: .medium))
                    .foregroundColor(canSend ? DesignSystem.primary : DesignSystem.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend || loadingPhase != nil)
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func submitMessage(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, loadingPhase == nil else {
            return
        }

        inputText = ""
        isInputFocused = false
        pipelineError = nil
        currentSuggestion = nil
        previewImage = nil
        prefetchedTryOnImage = nil
        prefetchError = nil
        isPrefetching = false
        messages.append(ChatMessage(role: .user, text: trimmed))

        Task {
            await runPipeline(for: trimmed)
        }
    }

    @MainActor
    private func runPipeline(for userMessage: String) async {
        loadingPhase = .styling
        var streamingMessageID: UUID?

        do {
            let suggestion = try await StylistChatService().suggestOutfitStreaming(
                userMessage: userMessage,
                userPhoto: userPhoto
            ) { partialReply in
                if streamingMessageID == nil {
                    loadingPhase = nil
                    let messageID = UUID()
                    streamingMessageID = messageID
                    messages.append(ChatMessage(id: messageID, role: .assistant, text: partialReply))
                } else if let messageID = streamingMessageID,
                          let index = messages.firstIndex(where: { $0.id == messageID }) {
                    var message = messages[index]
                    message.text = partialReply
                    messages[index] = message
                }
            }

            if let messageID = streamingMessageID,
               let index = messages.firstIndex(where: { $0.id == messageID }) {
                var message = messages[index]
                message.text = suggestion.reply
                messages[index] = message
            } else {
                loadingPhase = nil
                messages.append(ChatMessage(role: .assistant, text: suggestion.reply))
            }

            currentSuggestion = suggestion
            loadingPhase = .generatingPreview

            let image = try await PerfectCorpService().generateOutfitPreview(prompt: suggestion.imagenPrompt)
            previewImage = image
            loadingPhase = nil
            prefetchTryOn(outfitImage: image, garmentCategory: suggestion.garmentCategory)
        } catch {
            loadingPhase = nil
            pipelineError = error.localizedDescription
        }
    }

    @MainActor
    private func prefetchTryOn(outfitImage: UIImage, garmentCategory: String) {
        guard userPhoto != nil else { return }

        prefetchedTryOnImage = nil
        prefetchError = nil
        isPrefetching = true

        let category = normalizedGarmentCategory(garmentCategory)

        Task {
            do {
                guard let userPhoto else { return }
                let image = try await PerfectCorpService().generateTryOn(
                    userPhoto: userPhoto,
                    outfitPhoto: outfitImage,
                    garmentCategory: category
                )
                await MainActor.run {
                    prefetchedTryOnImage = image
                    isPrefetching = false
                }
            } catch {
                await MainActor.run {
                    prefetchError = error
                    isPrefetching = false
                }
            }
        }
    }

    @MainActor
    private func startTryOn(outfitImage: UIImage, garmentCategory: String) {
        guard let userPhoto, !isTryOnLoading else { return }

        pipelineError = nil

        // Case 1: pre-fetch already completed successfully — use it instantly
        if let prefetchedImage = prefetchedTryOnImage {
            onTryItOn(prefetchedImage, outfitImage)
            return
        }

        // Case 2: pre-fetch failed — surface the error, let user retry
        if let error = prefetchError {
            pipelineError = error.localizedDescription
            return
        }

        // Case 3: pre-fetch still in flight — show loading state and wait for it
        isTryOnLoading = true

        let category = normalizedGarmentCategory(garmentCategory)

        Task {
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline {
                if let image = prefetchedTryOnImage {
                    isTryOnLoading = false
                    onTryItOn(image, outfitImage)
                    return
                }
                if let error = prefetchError {
                    isTryOnLoading = false
                    pipelineError = error.localizedDescription
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
            // Timeout — fall back to a direct API call
            do {
                let image = try await PerfectCorpService().generateTryOn(
                    userPhoto: userPhoto,
                    outfitPhoto: outfitImage,
                    garmentCategory: category
                )
                isTryOnLoading = false
                onTryItOn(image, outfitImage)
            } catch {
                isTryOnLoading = false
                pipelineError = error.localizedDescription
            }
        }
    }

    private func normalizedGarmentCategory(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "full_body", "full body", "fullbody":
            return "full_body"
        case "lower_body", "lower body", "lowerbody":
            return "lower_body"
        case "shoes", "shoe":
            return "shoes"
        case "upper_body", "upper body", "upperbody":
            return "upper_body"
        default:
            return "full_body"
        }
    }
}

#Preview {
    @Previewable @FocusState var isInputFocused: Bool

    StylistChatView(userPhoto: nil, isInputFocused: $isInputFocused) { _, _ in }
        .padding()
        .background(DesignSystem.background)
}
