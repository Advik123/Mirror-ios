import SwiftUI

enum DesignSystem {

    // MARK: - Colors
    static let background       = Color(hex: "#fbf9f3")
    static let surface          = Color(hex: "#fbf9f3")
    static let surfaceContainerLowest = Color(hex: "#ffffff")
    static let surfaceContainerLow  = Color(hex: "#f5f4ed")
    static let surfaceContainer     = Color(hex: "#efeee7")
    static let surfaceContainerHigh = Color(hex: "#eae8e2")
    static let surfaceVariant       = Color(hex: "#e4e2dc")
    static let surfaceDim           = Color(hex: "#dbdad4")

    static let primary          = Color(hex: "#000000")
    static let onPrimary        = Color(hex: "#ffffff")
    static let primaryContainer = Color(hex: "#1c1b1b")
    static let tertiaryFixed    = Color(hex: "#e3e3df")
    static let tertiaryContainer = Color(hex: "#1a1c1a")

    static let onSurface        = Color(hex: "#1b1c18")
    static let onSurfaceVariant = Color(hex: "#444748")
    static let onBackground     = Color(hex: "#1b1c18")
    static let outline          = Color(hex: "#747878")
    static let outlineVariant   = Color(hex: "#c4c7c7")
    static let secondary        = Color(hex: "#5d5f5d")

    static let verdictYes       = Color(hex: "#059669")
    static let verdictNo        = Color(hex: "#ba1a1a")
    static let chipForeground   = Color(hex: "#464744")

    // MARK: - Typography
    static func playfair(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("PlayfairDisplay-\(weightString(weight))", size: size)
    }

    static func hanken(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("HankenGrotesk-\(weightString(weight))", size: size)
    }

    private static func weightString(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold:     return "Bold"
        case .semibold: return "SemiBold"
        case .medium:   return "Medium"
        default:        return "Regular"
        }
    }

    // MARK: - Named Styles
    static var displayLg:        Font { playfair(48, weight: .bold) }
    static var headlineLgMobile: Font { playfair(28, weight: .semibold) }
    static var headlineLg:       Font { playfair(32, weight: .semibold) }
    static var headlineMd:       Font { playfair(24, weight: .medium) }
    static var bodyLg:           Font { hanken(18) }
    static var bodyMd:           Font { hanken(16) }
    static var labelMd:          Font { hanken(14, weight: .semibold) }
    static var labelSm:          Font { hanken(12, weight: .medium) }

    // MARK: - Spacing
    static let marginMobile: CGFloat = 20
    static let gutter:       CGFloat = 16
    static let stackSm:      CGFloat = 8
    static let stackMd:      CGFloat = 24
    static let stackLg:      CGFloat = 48
    static let unit:         CGFloat = 4

    // MARK: - Corner Radius
    static let radiusSm:   CGFloat = 4
    static let radiusMd:   CGFloat = 8
    static let radiusLg:   CGFloat = 12
    static let radiusXl:   CGFloat = 16
    static let radiusFull: CGFloat = 999

    // MARK: - Layout
    static let heroHeightRatio: CGFloat = 0.7
    static let verdictHeroHeightRatio: CGFloat = 0.42
    static let uploadPreviewHeight: CGFloat = 280
    static let headerHeight: CGFloat = unit * 16
    static let bottomTabHeight: CGFloat = unit * 20
    static let buttonHeight: CGFloat = unit * 14
    static let logoSize: CGFloat = unit * 16
    static let profileThumbnailSize: CGFloat = unit * 10
    static let profilePhotoSize: CGFloat = unit * 30
    static let verdictBadgeSize: CGFloat = unit * 32
    static let gradientHeight: CGFloat = unit * 50
    static let tryOnGradientHeight: CGFloat = unit * 60
    static let bentoImageSize: CGFloat = unit * 24
    static let polaroidWidth: CGFloat = unit * 20
    static let polaroidHeight: CGFloat = unit * 28
    static let uploadIconSize: CGFloat = unit * 9
    static let closeButtonSize: CGFloat = unit * 10
    static let actionButtonSize: CGFloat = unit * 14
    static let contentOverlap: CGFloat = unit * 8
    static let contentCardRadius: CGFloat = unit * 8
    static let dashedLineWidth: CGFloat = 2
    static let hairlineWidth: CGFloat = 1
    static let accentBorderWidth: CGFloat = unit
    static let dotSpacing: CGFloat = unit * 6
    static let dotSize: CGFloat = unit * 0.75
    static let emptyPatternOpacity: CGFloat = 0.05
    static let inactiveOpacity: CGFloat = 0.4
    static let materialOpacity: CGFloat = 0.8
    static let faintMaterialOpacity: CGFloat = 0.2
    static let disclaimerOpacity: CGFloat = 0.1
    static let trackingTightDisplay: CGFloat = -0.02 * 48
    static let trackingWide: CGFloat = unit * 2
    static let trackingLabel: CGFloat = unit
    static let trackingVerdict: CGFloat = unit * 1.5
    static let imageAspectRatio: CGFloat = 0.8
    static let squareAspectRatio: CGFloat = 1
    static let cardHeight: CGFloat = unit * 50
    static let flavorTextInterval: TimeInterval = 2.5

    // MARK: - Shadow
    static func highFashionShadow() -> some ViewModifier {
        HighFashionShadow()
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Shadow Modifier
struct HighFashionShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.labelMd)
            .foregroundColor(DesignSystem.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.buttonHeight)
            .background(DesignSystem.primary)
            .clipShape(Capsule())
            .modifier(HighFashionShadow())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
            .opacity(isLoading ? 0.7 : 1.0)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.labelMd)
            .foregroundColor(DesignSystem.primary)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.buttonHeight)
            .background(DesignSystem.surfaceContainerLowest)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DesignSystem.primary, lineWidth: DesignSystem.hairlineWidth))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Bounded Image Helpers

/// Fills a container while clipping overflow (upload slots, heroes).
struct ClippedFillImage: View {
    let uiImage: UIImage

    var body: some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

/// Shows the full image without cropping (try-on results).
struct ContainedFitImage: View {
    let uiImage: UIImage

    var body: some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full-screen image viewer with a close button in the top-leading corner.
struct FullScreenImageViewer: View {
    let uiImage: UIImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.background
                .ignoresSafeArea()

            ContainedFitImage(uiImage: uiImage)
                .padding(.horizontal, DesignSystem.marginMobile)
                .padding(.top, DesignSystem.headerHeight + DesignSystem.stackMd)
                .padding(.bottom, DesignSystem.stackLg)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onDismiss) {
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
                    .accessibilityLabel("Close full screen image")

                    Spacer()
                }
                .padding(.horizontal, DesignSystem.marginMobile)
                .padding(.top, DesignSystem.stackLg)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Chip Style
struct ChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.labelSm)
            .foregroundColor(DesignSystem.chipForeground)
            .padding(.horizontal, DesignSystem.unit * 3)
            .padding(.vertical, DesignSystem.unit * 1.5)
            .background(DesignSystem.tertiaryFixed)
            .clipShape(Capsule())
    }
}
