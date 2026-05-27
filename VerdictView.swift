import SwiftUI
import UIKit

struct VerdictView: View {
    let result: VerdictResult
    let userPhoto: UIImage
    let outfitPhoto: UIImage
    let onTryItOn: (UIImage) -> Void
    let onAnalyzeAnother: () -> Void

    @State private var isTryOnLoading = false
    @State private var tryOnError: String? = nil
    @State private var prefetchedTryOnImage: UIImage? = nil
    @State private var prefetchError: Error? = nil
    @State private var isPrefetching: Bool = false
    @State private var isBadgeVisible = false
    @State private var isContentVisible = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: .zero) {
                heroSection

                contentCard
                    .offset(y: -DesignSystem.contentOverlap)
                    .offset(y: isContentVisible ? .zero : DesignSystem.stackMd + DesignSystem.stackSm)
                    .opacity(isContentVisible ? 1 : .zero)
                    .animation(.easeOut(duration: 0.6), value: isContentVisible)
            }
            .padding(.bottom, DesignSystem.stackLg)
        }
        .background(DesignSystem.background)
        .ignoresSafeArea(edges: .top)
        .disabled(isTryOnLoading)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(isTryOnLoading)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                isBadgeVisible = true
            }

            withAnimation(.easeOut(duration: 0.6)) {
                isContentVisible = true
            }

            // Start pre-fetching the try-on result immediately
            isPrefetching = true
            Task {
                do {
                    let image = try await PerfectCorpService().generateTryOn(
                        userPhoto: userPhoto,
                        outfitPhoto: outfitPhoto
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
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            ClippedFillImage(uiImage: outfitPhoto)
                .frame(maxWidth: .infinity)
                .frame(height: DesignSystem.uploadPreviewHeight)

            backButton
                .padding(DesignSystem.marginMobile)
                .padding(.top, DesignSystem.stackSm)

            verdictBadge
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backButton: some View {
        Button {
            onAnalyzeAnother()
        } label: {
            Circle()
                .fill(DesignSystem.surface.opacity(DesignSystem.materialOpacity))
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: DesignSystem.closeButtonSize, height: DesignSystem.closeButtonSize)
                .overlay {
                    Image(systemName: "chevron.left")
                        .font(.system(size: DesignSystem.gutter, weight: .semibold))
                        .foregroundColor(DesignSystem.primary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to analyze another outfit")
        .disabled(isTryOnLoading)
    }

    private var verdictBadge: some View {
        VStack(spacing: DesignSystem.unit) {
            Text(result.verdict ? "YES" : "NO")
                .font(DesignSystem.playfair(32, weight: .bold))
                .foregroundColor(DesignSystem.onPrimary)

            Image(systemName: result.verdict ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: DesignSystem.stackMd, weight: .semibold))
                .foregroundColor(DesignSystem.onPrimary)
        }
        .frame(width: DesignSystem.verdictBadgeSize, height: DesignSystem.verdictBadgeSize)
        .background(result.verdict ? DesignSystem.verdictYes : DesignSystem.verdictNo)
        .clipShape(Circle())
        .overlay(Circle().stroke(DesignSystem.onPrimary, lineWidth: DesignSystem.accentBorderWidth))
        .shadow(
            color: (result.verdict ? DesignSystem.verdictYes : DesignSystem.verdictNo).opacity(0.15),
            radius: DesignSystem.stackLg - DesignSystem.stackSm,
            x: .zero,
            y: DesignSystem.marginMobile
        )
        .scaleEffect(isBadgeVisible ? 1 : 0.5)
    }

    private var contentCard: some View {
        VStack(spacing: DesignSystem.stackMd) {
            VStack(spacing: DesignSystem.stackSm) {
                Text("THE VERDICT")
                    .font(DesignSystem.labelSm)
                    .foregroundColor(DesignSystem.onSurfaceVariant)
                    .tracking(DesignSystem.trackingVerdict)

                Text(result.verdict ? "A Perfect Match" : "Not Quite Right")
                    .font(DesignSystem.headlineMd)
                    .foregroundColor(DesignSystem.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            reasoningCard

            if isTryOnLoading {
                tryOnLoadingState
            } else {
                Button {
                    startTryOn()
                } label: {
                    Label("TRY IT ON", systemImage: "camera.viewfinder")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(PrimaryButtonStyle())

                if result.verdict {
                    Button("Analyze Another Outfit") {
                        onAnalyzeAnother()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if let tryOnError {
                    tryOnErrorCard(tryOnError)
                }
            }

            metadataGrid
            styleChips
        }
        .padding(DesignSystem.stackMd)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.surface)
        .clipShape(TopRoundedRectangle(radius: DesignSystem.contentCardRadius))
    }

    private var reasoningCard: some View {
        Text(result.reasoning)
            .font(DesignSystem.bodyMd)
            .italic()
            .foregroundColor(DesignSystem.onSurface)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(DesignSystem.stackMd)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(DesignSystem.surfaceContainerLow)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.radiusXl)
                    .stroke(DesignSystem.surfaceVariant, lineWidth: DesignSystem.hairlineWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }

    private var tryOnLoadingState: some View {
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
    }

    private func tryOnErrorCard(_ message: String) -> some View {
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }

    private var metadataGrid: some View {
        HStack(spacing: DesignSystem.gutter) {
            metadataCard(label: "STYLE", value: "EDITORIAL")
            metadataCard(label: "AI", value: "ANALYZED")
        }
    }

    private func metadataCard(label: String, value: String) -> some View {
        VStack(spacing: DesignSystem.unit) {
            Text(label)
                .font(DesignSystem.labelSm)
                .foregroundColor(DesignSystem.onSurfaceVariant)
                .tracking(DesignSystem.trackingLabel)

            Text(value)
                .font(DesignSystem.labelMd)
                .foregroundColor(DesignSystem.primary)
        }
        .padding(DesignSystem.gutter)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.surfaceContainerLowest)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.radiusLg)
                .stroke(DesignSystem.surfaceVariant, lineWidth: DesignSystem.hairlineWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
    }

    private var styleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.stackSm) {
                Text("Minimalist")
                    .modifier(ChipStyle())
                Text("Editorial")
                    .modifier(ChipStyle())
                Text("Curated")
                    .modifier(ChipStyle())
            }
        }
    }

    @MainActor
    private func startTryOn() {
        guard !isTryOnLoading else { return }

        tryOnError = nil

        // Case 1: pre-fetch already completed successfully — use it instantly
        if let prefetchedImage = prefetchedTryOnImage {
            onTryItOn(prefetchedImage)
            return
        }

        // Case 2: pre-fetch failed — surface the error, let user retry
        if let error = prefetchError {
            tryOnError = error.localizedDescription
            return
        }

        // Case 3: pre-fetch still in flight — show loading state and wait for it
        isTryOnLoading = true

        Task {
            // Poll until the pre-fetch resolves (max 30 seconds)
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline {
                if let image = prefetchedTryOnImage {
                    isTryOnLoading = false
                    onTryItOn(image)
                    return
                }
                if let error = prefetchError {
                    isTryOnLoading = false
                    tryOnError = error.localizedDescription
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
            // Timeout — fall back to a direct API call
            do {
                let image = try await PerfectCorpService().generateTryOn(
                    userPhoto: userPhoto,
                    outfitPhoto: outfitPhoto
                )
                isTryOnLoading = false
                onTryItOn(image)
            } catch {
                isTryOnLoading = false
                tryOnError = error.localizedDescription
            }
        }
    }
}

#Preview {
    VerdictView(
        result: VerdictResult(
            verdict: true,
            reasoning: "The warm tones in this outfit complement your skin's undertone beautifully. The silhouette is balanced and flattering for your proportions."
        ),
        userPhoto: UIImage(systemName: "photo")!,
        outfitPhoto: UIImage(systemName: "photo")!
    ) { _ in } onAnalyzeAnother: {}
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )

        return Path(path.cgPath)
    }
}
