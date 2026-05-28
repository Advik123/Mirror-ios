import Photos
import SwiftUI
import UIKit

struct TryOnResultView: View {
    let renderedImage: UIImage
    let userPhoto: UIImage
    let outfitPhoto: UIImage
    let onDone: () -> Void

    @State private var saveState: SaveState = .idle
    @State private var isShowingShareSheet = false
    @State private var savedCheckmarkScale: CGFloat = 0.5

    private enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    var body: some View {
        ZStack {
            DesignSystem.background
                .ignoresSafeArea()

            ContainedFitImage(uiImage: renderedImage)
                .padding(.horizontal, DesignSystem.marginMobile)
                .padding(.top, DesignSystem.headerHeight + DesignSystem.stackMd)
                .padding(.bottom, DesignSystem.tryOnGradientHeight + DesignSystem.stackLg)
                .ignoresSafeArea()

            VStack {
                floatingHeader
                Spacer()
                bottomOverlay
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(image: renderedImage)
                .presentationDetents([.medium, .large])
        }
    }

    private var floatingHeader: some View {
        HStack {
            Button {
                onDone()
            } label: {
                Circle()
                    .fill(DesignSystem.surface.opacity(DesignSystem.faintMaterialOpacity))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: DesignSystem.closeButtonSize, height: DesignSystem.closeButtonSize)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: DesignSystem.gutter, weight: .semibold))
                            .foregroundColor(DesignSystem.primary)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Mirror")
                .font(DesignSystem.headlineLgMobile)
                .foregroundColor(DesignSystem.primary)
                .tracking(DesignSystem.trackingWide)

            Spacer()

            Color.clear
                .frame(width: DesignSystem.closeButtonSize, height: DesignSystem.closeButtonSize)
        }
        .padding(.horizontal, DesignSystem.marginMobile)
        .padding(.top, DesignSystem.stackLg)
    }

    private var bottomOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    DesignSystem.onSurface.opacity(DesignSystem.materialOpacity),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: DesignSystem.tryOnGradientHeight)

            VStack(spacing: DesignSystem.gutter) {
                HStack(spacing: DesignSystem.stackMd) {
                    saveButton
                    shareButton
                }

                if case .failed(let message) = saveState {
                    Text(message)
                        .font(DesignSystem.labelSm)
                        .foregroundColor(DesignSystem.onPrimary)
                        .padding(.horizontal, DesignSystem.gutter)
                        .padding(.vertical, DesignSystem.stackSm)
                        .background(DesignSystem.verdictNo)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                disclaimerCard
            }
            .padding(.horizontal, DesignSystem.marginMobile)
            .padding(.bottom, DesignSystem.stackMd)
        }
    }

    private var saveButton: some View {
        Button {
            saveToPhotoLibrary()
        } label: {
            VStack(spacing: DesignSystem.stackSm) {
                Circle()
                    .fill(saveCircleBackground)
                    .animation(.spring(response: 0.3), value: saveState)
                    .frame(width: DesignSystem.actionButtonSize, height: DesignSystem.actionButtonSize)
                    .overlay {
                        saveButtonIcon
                    }

                Text(saveButtonLabel)
                    .font(DesignSystem.labelSm)
                    .foregroundColor(DesignSystem.onPrimary)
                    .tracking(DesignSystem.trackingLabel)
            }
        }
        .disabled(saveState == .saving)
        .buttonStyle(.plain)
    }

    private var shareButton: some View {
        Button {
            isShowingShareSheet = true
        } label: {
            VStack(spacing: DesignSystem.stackSm) {
                Circle()
                    .fill(DesignSystem.surfaceContainerLowest)
                    .frame(width: DesignSystem.actionButtonSize, height: DesignSystem.actionButtonSize)
                    .overlay {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: DesignSystem.stackMd, weight: .medium))
                            .foregroundColor(DesignSystem.primary)
                    }

                Text("SHARE")
                    .font(DesignSystem.labelSm)
                    .foregroundColor(DesignSystem.onPrimary)
                    .tracking(DesignSystem.trackingLabel)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var saveButtonIcon: some View {
        switch saveState {
        case .idle:
            Image(systemName: "bookmark")
                .font(.system(size: DesignSystem.stackMd, weight: .medium))
                .foregroundColor(DesignSystem.primary)
        case .saving:
            ProgressView()
                .tint(DesignSystem.primary)
        case .saved:
            Image(systemName: "checkmark")
                .font(.system(size: DesignSystem.stackMd, weight: .medium))
                .foregroundColor(DesignSystem.onPrimary)
                .scaleEffect(savedCheckmarkScale)
        case .failed:
            Image(systemName: "xmark")
                .font(.system(size: DesignSystem.stackMd, weight: .medium))
                .foregroundColor(DesignSystem.onPrimary)
        }
    }

    private var saveCircleBackground: Color {
        switch saveState {
        case .saved:
            DesignSystem.verdictYes
        case .failed:
            DesignSystem.verdictNo
        default:
            DesignSystem.surfaceContainerLowest
        }
    }

    private var saveButtonLabel: String {
        switch saveState {
        case .idle:
            "SAVE"
        case .saving:
            "SAVING"
        case .saved:
            "SAVED"
        case .failed:
            "FAILED"
        }
    }

    private func saveToPhotoLibrary() {
        saveState = .saving

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            Task { @MainActor in
                guard status == .authorized else {
                    withAnimation(.spring(response: 0.3)) {
                        saveState = .failed("Could not save photo.")
                    }
                    resetSaveState(after: 3)
                    return
                }

                do {
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: renderedImage)
                    }
                    savedCheckmarkScale = 0.5
                    withAnimation(.spring(response: 0.3)) {
                        saveState = .saved
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        savedCheckmarkScale = 1.0
                    }
                    resetSaveState(after: 2)
                } catch {
                    withAnimation(.spring(response: 0.3)) {
                        saveState = .failed("Could not save photo.")
                    }
                    resetSaveState(after: 3)
                }
            }
        }
    }

    private func resetSaveState(after seconds: TimeInterval) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    saveState = .idle
                }
            }
        }
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
            HStack(alignment: .top, spacing: DesignSystem.stackSm) {
                Image(systemName: "info.circle")
                    .font(.system(size: DesignSystem.gutter, weight: .medium))

                Text("Results look best with a single garment on a plain background")
                    .font(DesignSystem.labelSm)
            }
            .foregroundColor(DesignSystem.onPrimary.opacity(0.9))

            Text("AI Rendering Engine | Processing complete")
                .font(DesignSystem.labelSm)
                .foregroundColor(DesignSystem.onPrimary.opacity(0.6))
                .tracking(DesignSystem.trackingLabel)
        }
        .padding(DesignSystem.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surface.opacity(DesignSystem.disclaimerOpacity))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.radiusXl)
                .stroke(DesignSystem.surfaceVariant.opacity(DesignSystem.faintMaterialOpacity), lineWidth: DesignSystem.hairlineWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    TryOnResultView(
        renderedImage: UIImage(systemName: "photo")!,
        userPhoto: UIImage(systemName: "photo")!,
        outfitPhoto: UIImage(systemName: "photo")!
    ) {}
}
