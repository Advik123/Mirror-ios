import SwiftUI
import UIKit
internal import Combine

struct LoadingView: View {
    let userPhoto: UIImage
    let outfitPhoto: UIImage
    let onComplete: (Result<VerdictResult, Error>) -> Void

    @State private var isAnalyzing = false
    @State private var error: Error?
    @State private var hasStarted = false
    @State private var flavorTextIndex = 0

    private let flavorTexts = [
        "READING YOUR COLOR PROFILE",
        "CHECKING SILHOUETTE COMPATIBILITY",
        "CONSULTING YOUR VIRTUAL STYLIST",
        "ALMOST THERE"
    ]

    var body: some View {
        VStack(spacing: DesignSystem.stackMd) {
            if isAnalyzing {
                VStack(spacing: DesignSystem.stackMd) {
                    ProgressView()
                        .tint(DesignSystem.primary)
                        .scaleEffect(1.5)

                    VStack(spacing: DesignSystem.stackSm) {
                        Text("Analyzing your style...")
                            .font(DesignSystem.bodyLg)
                            .foregroundColor(DesignSystem.onSurface)

                        Text(flavorTexts[flavorTextIndex])
                            .font(DesignSystem.labelSm)
                            .foregroundColor(DesignSystem.onSurfaceVariant)
                            .tracking(DesignSystem.trackingLabel)
                            .transition(.opacity)
                            .id(flavorTextIndex)
                    }
                }
            } else if let error {
                VStack(alignment: .leading, spacing: DesignSystem.gutter) {
                    HStack(alignment: .top, spacing: DesignSystem.stackSm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: DesignSystem.stackMd, weight: .medium))
                            .foregroundColor(DesignSystem.verdictNo)

                        Text(error.localizedDescription)
                            .font(DesignSystem.bodyMd)
                            .foregroundColor(DesignSystem.onSurface)
                            .multilineTextAlignment(.leading)
                    }

                    Button("TRY AGAIN") {
                        startAnalysis()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(DesignSystem.stackMd)
                .background(DesignSystem.surfaceContainerLow)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(DesignSystem.verdictNo)
                        .frame(width: DesignSystem.accentBorderWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
                .padding(.horizontal, DesignSystem.marginMobile)
            }
        }
        .background(DesignSystem.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(
            Timer.publish(every: DesignSystem.flavorTextInterval, on: .main, in: .common).autoconnect()
        ) { _ in
            guard isAnalyzing else {
                return
            }

            withAnimation(.easeInOut(duration: 0.4)) {
                flavorTextIndex = (flavorTextIndex + 1) % flavorTexts.count
            }
        }
        .onAppear {
            guard !hasStarted else {
                return
            }

            hasStarted = true
            startAnalysis()
        }
    }

    @MainActor
    private func startAnalysis() {
        guard !isAnalyzing else {
            return
        }

        isAnalyzing = true
        error = nil

        Task {
            do {
                let result = try await GeminiService().analyzeOutfit(
                    userPhoto: userPhoto,
                    outfitPhoto: outfitPhoto
                )

                onComplete(.success(result))
            } catch {
                isAnalyzing = false
                self.error = error
                onComplete(.failure(error))
            }
        }
    }
}

#Preview {
    LoadingView(
        userPhoto: UIImage(systemName: "photo")!,
        outfitPhoto: UIImage(systemName: "photo")!
    ) { _ in }
}
