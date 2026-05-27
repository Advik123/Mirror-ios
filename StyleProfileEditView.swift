import SwiftUI

struct StyleProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVibes: Set<StyleProfile.StyleVibe> = []
    @State private var selectedPriority: StyleProfile.StylePriority?
    @State private var selectedBodyType: StyleProfile.BodyType?
    @State private var selectedGender: StyleProfile.Gender?

    private var isComplete: Bool {
        !selectedVibes.isEmpty && selectedPriority != nil && selectedBodyType != nil && selectedGender != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Edit Style Profile")
                        .font(DesignSystem.headlineMd)
                        .foregroundColor(DesignSystem.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("This helps our AI give you more accurate verdicts.")
                        .font(DesignSystem.bodyMd)
                        .foregroundColor(DesignSystem.onSurfaceVariant)
                        .padding(.top, DesignSystem.stackSm)

                    Spacer().frame(height: DesignSystem.stackLg)

                    editQuestionSection(
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

                    editQuestionSection(
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

                    editQuestionSection(
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

                    editQuestionSection(
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

                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isComplete)
                    .opacity(isComplete ? 1.0 : DesignSystem.inactiveOpacity)
                }
                .padding(DesignSystem.marginMobile)
            }
            .background(DesignSystem.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(DesignSystem.labelMd)
                    .foregroundColor(DesignSystem.primary)
                }
            }
        }
        .onAppear {
            loadExistingProfile()
        }
    }

    private func editQuestionSection<Content: View>(
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

    private func loadExistingProfile() {
        guard let profile = StyleProfileStore().load() else {
            return
        }

        selectedVibes = Set(profile.styleVibes)
        selectedPriority = profile.priority
        selectedBodyType = profile.bodyType
        selectedGender = profile.gender
    }

    private func saveChanges() {
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
        dismiss()
    }
}

#Preview {
    StyleProfileEditView()
}
