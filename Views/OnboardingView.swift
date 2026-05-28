import SwiftUI
import UIKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var showStyleProfileStep = false

    var body: some View {
        if showStyleProfileStep {
            StyleProfileOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        } else {
            photoUploadStep
        }
    }

    private var photoUploadStep: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignSystem.stackLg) {
                    heroSection(height: geometry.size.height * DesignSystem.heroHeightRatio)
                    featuresBentoGrid
                }
                .padding(.bottom, DesignSystem.stackLg)
            }
            .background(DesignSystem.background)
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }

    private func heroSection(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            heroImage
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            LinearGradient(
                colors: [.clear, DesignSystem.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: DesignSystem.gradientHeight)

            VStack(spacing: DesignSystem.stackMd) {
                logoMark

                VStack(spacing: DesignSystem.stackSm) {
                    Text("Does that outfit suit you?")
                        .font(DesignSystem.displayLg)
                        .foregroundColor(DesignSystem.primary)
                        .tracking(DesignSystem.trackingTightDisplay)
                        .multilineTextAlignment(.center)

                    Text("Find out in seconds with AI-powered styling and virtual try-ons.")
                        .font(DesignSystem.bodyLg)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }

                if selectedImage == nil {
                    Button {
                        isShowingImagePicker = true
                    } label: {
                        HStack(spacing: DesignSystem.stackSm) {
                            Text("Get Started")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Next →") {
                        guard let selectedImage else {
                            return
                        }

                        UserPhotoStore().savePhoto(selectedImage)
                        showStyleProfileStep = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Text("Explore Wardrobe")
                    .font(DesignSystem.labelMd)
                    .foregroundColor(DesignSystem.primary)
                    .textCase(.uppercase)
                    .underline()
            }
            .padding(.horizontal, DesignSystem.marginMobile)
            .padding(.bottom, DesignSystem.stackMd)
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                DesignSystem.surfaceContainerLow

                Image(systemName: "person.full.dotted")
                    .font(.system(size: DesignSystem.unit * 20))
                    .foregroundColor(DesignSystem.onSurfaceVariant)
            }
        }
    }

    private var logoMark: some View {
        RoundedRectangle(cornerRadius: DesignSystem.radiusXl)
            .fill(DesignSystem.primary)
            .frame(width: DesignSystem.logoSize, height: DesignSystem.logoSize)
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: DesignSystem.unit * 7, weight: .semibold))
                    .foregroundColor(DesignSystem.onPrimary)
            }
    }

    private var featuresBentoGrid: some View {
        VStack(spacing: DesignSystem.gutter) {
            wideFeatureCard

            HStack(spacing: DesignSystem.gutter) {
                closetCard
                guideCard
            }

            styleGuideCard
        }
        .padding(.horizontal, DesignSystem.marginMobile)
    }

    private var wideFeatureCard: some View {
        HStack(spacing: DesignSystem.gutter) {
            VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
                Text("AI Insight")
                    .modifier(ChipStyle())

                Text("Instant Stylist Verdict")
                    .font(DesignSystem.headlineMd)
                    .foregroundColor(DesignSystem.primary)

                Text("Color harmony and silhouette compatibility, translated into a clear yes or no.")
                    .font(DesignSystem.bodyMd)
                    .foregroundColor(DesignSystem.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: DesignSystem.radiusLg)
                .fill(DesignSystem.surfaceContainerHigh)
                .frame(width: DesignSystem.bentoImageSize, height: DesignSystem.bentoImageSize)
                .overlay {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: DesignSystem.unit * 8))
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                }
        }
        .padding(DesignSystem.stackMd)
        .background(DesignSystem.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }

    private var closetCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
            Image(systemName: "hanger")
                .font(.system(size: DesignSystem.unit * 7))

            Text("Your Virtual Closet")
                .font(DesignSystem.headlineMd)

            Text("Your profile photo stays ready for every look.")
                .font(DesignSystem.labelSm)
        }
        .foregroundColor(DesignSystem.surface)
        .padding(DesignSystem.gutter)
        .frame(maxWidth: .infinity, minHeight: DesignSystem.cardHeight, alignment: .topLeading)
        .background(DesignSystem.tertiaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: DesignSystem.unit * 7))

            Text("Try-On Ready")
                .font(DesignSystem.headlineMd)

            Text("Move from verdict to rendered outfit in one tap.")
                .font(DesignSystem.labelSm)
        }
        .foregroundColor(DesignSystem.primary)
        .padding(DesignSystem.gutter)
        .frame(maxWidth: .infinity, minHeight: DesignSystem.cardHeight, alignment: .topLeading)
        .background(DesignSystem.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }

    private var styleGuideCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [DesignSystem.tertiaryContainer, DesignSystem.primaryContainer],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.clear, DesignSystem.primary.opacity(DesignSystem.materialOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )

            Text("Curated Style Guides")
                .font(DesignSystem.headlineLg)
                .foregroundColor(DesignSystem.onPrimary)
                .padding(DesignSystem.stackMd)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
