import SwiftUI
import UIKit

extension VerdictResult: Hashable {
    static func == (lhs: VerdictResult, rhs: VerdictResult) -> Bool {
        lhs.verdict == rhs.verdict && lhs.reasoning == rhs.reasoning
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(verdict)
        hasher.combine(reasoning)
    }
}

private final class TryOnResultHolder: Hashable {
    let image: UIImage
    let outfitPhoto: UIImage

    init(image: UIImage, outfitPhoto: UIImage) {
        self.image = image
        self.outfitPhoto = outfitPhoto
    }

    static func == (lhs: TryOnResultHolder, rhs: TryOnResultHolder) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

private enum HomeRoute: Hashable {
    case loading
    case verdict(VerdictResult)
    case tryOnResult(TryOnResultHolder)
    case settings
}

struct HomeView: View {
    @FocusState private var isStylistInputFocused: Bool
    @State private var path = NavigationPath()
    @State private var userPhoto: UIImage?
    @State private var selectedOutfitPhoto: UIImage?
    @State private var outfitImageAspectRatio: CGFloat = DesignSystem.imageAspectRatio
    @State private var verdictResult: VerdictResult?
    @State private var isShowingImagePicker = false
    @State private var isShowingMissingUserPhotoAlert = false
    @State private var isPolaroidSettled = false
    @State private var isOutfitImageVisible = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                DesignSystem.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignSystem.stackMd) {
                        VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
                            Text("EDITORIAL ASSISTANT")
                                .font(DesignSystem.labelMd)
                                .foregroundColor(DesignSystem.onSurfaceVariant)
                                .tracking(DesignSystem.trackingLabel)

                            Text("Upload your inspiration")
                                .font(DesignSystem.headlineLgMobile)
                                .foregroundColor(DesignSystem.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isStylistInputFocused = false
                        }

                        Button {
                            isStylistInputFocused = false
                            isShowingImagePicker = true
                        } label: {
                            outfitPreview
                        }
                        .buttonStyle(.plain)

                        Button {
                            isStylistInputFocused = false

                            guard selectedOutfitPhoto != nil else {
                                return
                            }

                            guard userPhoto != nil else {
                                isShowingMissingUserPhotoAlert = true
                                return
                            }

                            path.append(HomeRoute.loading)
                        } label: {
                            Label("ANALYZE OUTFIT", systemImage: "sparkles")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selectedOutfitPhoto == nil)
                        .opacity(selectedOutfitPhoto == nil ? DesignSystem.inactiveOpacity : 1)

                        Text("Our AI will analyze the silhouette and aesthetic to match your profile.")
                            .font(DesignSystem.labelSm)
                            .foregroundColor(DesignSystem.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isStylistInputFocused = false
                            }

                        StylistChatView(
                            userPhoto: userPhoto,
                            isInputFocused: $isStylistInputFocused
                        ) { renderedImage, outfitPhoto in
                            path.append(
                                HomeRoute.tryOnResult(
                                    TryOnResultHolder(image: renderedImage, outfitPhoto: outfitPhoto)
                                )
                            )
                        }
                    }
                    .padding(.top, DesignSystem.headerHeight + DesignSystem.stackMd)
                    .padding(.horizontal, DesignSystem.marginMobile)
                    .padding(.bottom, DesignSystem.bottomTabHeight + DesignSystem.stackLg)
                }
                .scrollDismissesKeyboard(.interactively)

                editorialHeader
                bottomTabBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(selectedImage: Binding(
                    get: { selectedOutfitPhoto },
                    set: { newImage in
                        selectedOutfitPhoto = newImage
                        isOutfitImageVisible = false

                        if let image = newImage {
                            let ratio = image.size.height / image.size.width
                            outfitImageAspectRatio = max(ratio, DesignSystem.imageAspectRatio)

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isOutfitImageVisible = true
                            }
                        }
                    }
                ))
            }
            .alert("No profile photo found. Please set one in Settings.", isPresented: $isShowingMissingUserPhotoAlert) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                userPhoto = UserPhotoStore().loadPhoto()
                isPolaroidSettled = false
            }
            .onChange(of: selectedOutfitPhoto != nil) { _, newValue in
                guard !newValue else { return }

                isOutfitImageVisible = false
                outfitImageAspectRatio = DesignSystem.imageAspectRatio
            }
        }
    }

    private var editorialHeader: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: DesignSystem.stackMd, weight: .medium))
                .foregroundColor(DesignSystem.primary)
                .frame(width: DesignSystem.profileThumbnailSize, height: DesignSystem.profileThumbnailSize)
                .contentShape(Rectangle())
                .onTapGesture {
                    isStylistInputFocused = false
                }

            Spacer()

            Text("Mirror")
                .font(DesignSystem.headlineLgMobile)
                .foregroundColor(DesignSystem.primary)
                .tracking(DesignSystem.trackingWide)
                .contentShape(Rectangle())
                .onTapGesture {
                    isStylistInputFocused = false
                }

            Spacer()

            Button {
                isStylistInputFocused = false
                path.append(HomeRoute.settings)
            } label: {
                profileThumbnail
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, DesignSystem.marginMobile)
        .frame(height: DesignSystem.headerHeight)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.surface)
    }

    private var profileThumbnail: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.surfaceContainerLow)

            if let userPhoto {
                Image(uiImage: userPhoto)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: DesignSystem.stackMd))
                    .foregroundColor(DesignSystem.secondary)
            }
        }
        .frame(width: DesignSystem.profileThumbnailSize, height: DesignSystem.profileThumbnailSize)
        .overlay(Circle().stroke(DesignSystem.surfaceContainerHigh, lineWidth: DesignSystem.dashedLineWidth))
    }

    private var outfitPreview: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: DesignSystem.radiusXl)
                .fill(DesignSystem.surfaceContainerLow)
                .overlay {
                    if selectedOutfitPhoto == nil {
                        DotPatternView()
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
                    }
                }

            RoundedRectangle(cornerRadius: DesignSystem.radiusXl)
                .stroke(
                    selectedOutfitPhoto == nil ? DesignSystem.outlineVariant : DesignSystem.primary,
                    style: StrokeStyle(
                        lineWidth: DesignSystem.dashedLineWidth,
                        dash: [DesignSystem.unit * 1.5, DesignSystem.unit]
                    )
                )

            if let selectedOutfitPhoto {
                Image(uiImage: selectedOutfitPhoto)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(isOutfitImageVisible ? 1 : 0.92)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isOutfitImageVisible)
            } else {
                VStack(spacing: DesignSystem.stackSm) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: DesignSystem.uploadIconSize, weight: .light))
                        .foregroundColor(DesignSystem.onSurfaceVariant)

                    Text("Drop an image here")
                        .font(DesignSystem.bodyLg)
                        .foregroundColor(DesignSystem.onSurface)

                    Text("Pinterest, Instagram, or Gallery")
                        .font(DesignSystem.labelSm)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let userPhoto {
                polaroidThumbnail(userPhoto)
                    .padding(DesignSystem.gutter)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(
            selectedOutfitPhoto != nil ? (1.0 / outfitImageAspectRatio) : DesignSystem.imageAspectRatio,
            contentMode: .fit
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXl))
    }

    private func polaroidThumbnail(_ image: UIImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: DesignSystem.polaroidWidth - DesignSystem.stackSm,
                    height: DesignSystem.polaroidHeight - DesignSystem.stackSm
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusMd))
                .padding(DesignSystem.radiusSm)
                .background(DesignSystem.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLg))
                .modifier(HighFashionShadow())

            Circle()
                .fill(DesignSystem.primary)
                .frame(width: DesignSystem.stackMd, height: DesignSystem.stackMd)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: DesignSystem.unit * 3))
                        .foregroundColor(DesignSystem.onPrimary)
                }
                .offset(x: DesignSystem.unit, y: DesignSystem.unit)
        }
        .frame(width: DesignSystem.polaroidWidth, height: DesignSystem.polaroidHeight)
        .rotationEffect(.degrees(isPolaroidSettled ? 0 : 3))
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                isPolaroidSettled = true
            }
        }
    }

    private var bottomTabBar: some View {
        VStack {
            Spacer()

            HStack {
                tabItem(icon: "camera", label: "Analyze", isActive: true)
                tabItem(icon: "hanger", label: "Wardrobe", isActive: false)
                tabItem(icon: "person", label: "Profile", isActive: false)
            }
            .padding(.horizontal, DesignSystem.marginMobile)
            .frame(height: DesignSystem.bottomTabHeight)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.surface.opacity(DesignSystem.materialOpacity))
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignSystem.surfaceVariant)
                    .frame(height: DesignSystem.hairlineWidth)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func tabItem(icon: String, label: String, isActive: Bool) -> some View {
        VStack(spacing: DesignSystem.unit) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.marginMobile, weight: isActive ? .semibold : .regular))

            Text(label)
                .font(isActive ? DesignSystem.labelMd : DesignSystem.labelSm)
        }
        .foregroundColor(isActive ? DesignSystem.primary : DesignSystem.secondary)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isStylistInputFocused = false
        }
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .loading:
            if let userPhoto, let selectedOutfitPhoto {
                LoadingView(
                    userPhoto: userPhoto,
                    outfitPhoto: selectedOutfitPhoto
                ) { result in
                    switch result {
                    case .success(let verdict):
                        verdictResult = verdict
                        path.append(HomeRoute.verdict(verdict))
                    case .failure:
                        break
                    }
                }
            }
        case .verdict(let verdict):
            if let userPhoto, let outfitPhoto = selectedOutfitPhoto {
                VerdictView(
                    result: verdict,
                    userPhoto: userPhoto,
                    outfitPhoto: outfitPhoto,
                    onTryItOn: { renderedImage in
                        path.append(
                            HomeRoute.tryOnResult(
                                TryOnResultHolder(image: renderedImage, outfitPhoto: outfitPhoto)
                            )
                        )
                    },
                    onAnalyzeAnother: {
                        selectedOutfitPhoto = nil
                        outfitImageAspectRatio = DesignSystem.imageAspectRatio
                        path = NavigationPath()
                    }
                )
            }
        case .tryOnResult(let holder):
            if let userPhoto {
                TryOnResultView(
                    renderedImage: holder.image,
                    userPhoto: userPhoto,
                    outfitPhoto: holder.outfitPhoto
                ) {
                    path = NavigationPath()
                }
            }
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    HomeView()
}

private struct DotPatternView: View {
    var body: some View {
        Canvas { context, size in
            let dotRect = CGRect(
                x: .zero,
                y: .zero,
                width: DesignSystem.dotSize,
                height: DesignSystem.dotSize
            )

            for x in stride(from: CGFloat.zero, through: size.width, by: DesignSystem.dotSpacing) {
                for y in stride(from: CGFloat.zero, through: size.height, by: DesignSystem.dotSpacing) {
                    let rect = dotRect.offsetBy(dx: x, dy: y)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(DesignSystem.primary.opacity(DesignSystem.emptyPatternOpacity))
                    )
                }
            }
        }
    }
}
