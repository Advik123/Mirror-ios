import SwiftUI

struct StyleProfileOnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var selectedVibes: Set<StyleProfile.StyleVibe> = []
    @State private var selectedPriority: StyleProfile.StylePriority?
    @State private var selectedBodyType: StyleProfile.BodyType?
    @State private var selectedGender: StyleProfile.Gender?

    private var isComplete: Bool {
        !selectedVibes.isEmpty && selectedPriority != nil && selectedBodyType != nil && selectedGender != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingProgressDots(currentStep: 2)

                    Text("STEP 2 OF 2")
                        .font(DesignSystem.labelSm)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                        .textCase(.uppercase)
                        .tracking(DesignSystem.trackingLabel)
                        .padding(.top, DesignSystem.stackMd)

                    Text("Tell us your style")
                        .font(DesignSystem.headlineLgMobile)
                        .foregroundColor(DesignSystem.primary)
                        .padding(.top, DesignSystem.stackSm)

                    Text("This helps our AI give you more accurate verdicts.")
                        .font(DesignSystem.bodyMd)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                        .padding(.top, DesignSystem.stackSm)

                    Spacer().frame(height: DesignSystem.stackLg)

                    questionSection(
                        label: "YOUR STYLE VIBE",
                        content: {
                            StyleChipGrid(
                                options: StyleProfile.StyleVibe.allCases,
                                label: { $0.rawValue },
                                isSelected: { selectedVibes.contains($0) },
                                onTap: { vibe in
                                    if selectedVibes.contains(vibe) {
                                        selectedVibes.remove(vibe)
                                    } else if selectedVibes.count < 2 {
                                        selectedVibes.insert(vibe)
                                    }
                                }
                            )
                        }
                    )

                    Spacer().frame(height: DesignSystem.stackMd + DesignSystem.stackSm)

                    questionSection(
                        label: "WHAT MATTERS MOST",
                        content: {
                            StyleChipGrid(
                                options: StyleProfile.StylePriority.allCases,
                                label: { $0.rawValue },
                                isSelected: { selectedPriority == $0 },
                                onTap: { selectedPriority = $0 }
                            )
                        }
                    )

                    Spacer().frame(height: DesignSystem.stackMd + DesignSystem.stackSm)

                    questionSection(
                        label: "SHOP FOR",
                        content: {
                            StyleChipGrid(
                                options: StyleProfile.Gender.allCases,
                                label: { $0.rawValue },
                                isSelected: { selectedGender == $0 },
                                onTap: { selectedGender = $0 }
                            )
                        }
                    )

                    Spacer().frame(height: DesignSystem.stackMd + DesignSystem.stackSm)

                    questionSection(
                        label: "YOUR BODY TYPE",
                        content: {
                            StyleChipGrid(
                                options: StyleProfile.BodyType.allCases,
                                label: { $0.rawValue },
                                isSelected: { selectedBodyType == $0 },
                                onTap: { selectedBodyType = $0 }
                            )
                        }
                    )

                    Spacer().frame(height: DesignSystem.stackLg)

                    Button("Finish Setup") {
                        finishSetup()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isComplete)
                    .opacity(isComplete ? 1.0 : DesignSystem.inactiveOpacity)
                }
                .padding(.horizontal, DesignSystem.marginMobile)
                .padding(.bottom, DesignSystem.stackLg)
            }
        }
        .background(DesignSystem.background)
    }

    private var headerBar: some View {
        Text("Mirror")
            .font(DesignSystem.labelMd)
            .foregroundColor(DesignSystem.primary)
            .textCase(.uppercase)
            .tracking(DesignSystem.trackingWide)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.headerHeight)
    }

    private func questionSection<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.stackSm) {
            Text(label)
                .font(DesignSystem.labelMd)
                .foregroundColor(DesignSystem.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(DesignSystem.trackingLabel)

            content()
        }
    }

    private func finishSetup() {
        guard let priority = selectedPriority, let bodyType = selectedBodyType, let gender = selectedGender else {
            return
        }

        let profile = StyleProfile(
            styleVibes: Array(selectedVibes),
            priority: priority,
            bodyType: bodyType,
            gender: gender
        )

        StyleProfileStore().save(profile)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
    }
}

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: DesignSystem.stackSm) {
            ForEach(1...2, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? DesignSystem.primary : DesignSystem.outlineVariant)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Chip Grid

struct StyleChipGrid<Option: Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    let isSelected: (Option) -> Bool
    let onTap: (Option) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: DesignSystem.stackSm)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: DesignSystem.stackSm) {
            ForEach(options, id: \.self) { option in
                StyleChip(
                    title: label(option),
                    isSelected: isSelected(option),
                    action: { onTap(option) }
                )
            }
        }
    }
}

struct StyleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.labelMd)
                .foregroundColor(isSelected ? DesignSystem.onPrimary : DesignSystem.onSurfaceVariant)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? DesignSystem.primary : DesignSystem.surfaceContainerLow)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule()
                            .stroke(DesignSystem.outlineVariant, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(StyleChipButtonStyle())
    }
}

struct StyleChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    StyleProfileOnboardingView(hasCompletedOnboarding: .constant(false))
}
