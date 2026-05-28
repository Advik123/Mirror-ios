import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profileImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var styleProfile: StyleProfile?
    @State private var isShowingStyleProfileEdit = false

    var body: some View {
        VStack(spacing: DesignSystem.stackMd) {
            Capsule()
                .fill(DesignSystem.surfaceDim)
                .frame(width: DesignSystem.stackLg, height: DesignSystem.radiusSm)
                .padding(.top, DesignSystem.stackSm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignSystem.stackMd) {
                    profilePhotoSection
                    Divider()
                    styleProfileSection
                }
            }

            Button("DONE") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(DesignSystem.marginMobile)
        .background(DesignSystem.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: {
                    profileImage
                },
                set: { newImage in
                    profileImage = newImage

                    if let newImage {
                        UserPhotoStore().savePhoto(newImage)
                    }
                }
            ))
        }
        .sheet(isPresented: $isShowingStyleProfileEdit, onDismiss: reloadStyleProfile) {
            StyleProfileEditView()
        }
        .onAppear {
            profileImage = UserPhotoStore().loadPhoto()
            reloadStyleProfile()
        }
    }

    private var profilePhotoSection: some View {
        VStack(spacing: DesignSystem.stackMd) {
            Text("PROFILE PHOTO")
                .font(DesignSystem.headlineMd)
                .foregroundColor(DesignSystem.primary)
                .tracking(DesignSystem.trackingLabel)
                .multilineTextAlignment(.center)

            profilePhotoPreview

            Button("CHANGE PHOTO") {
                isShowingImagePicker = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var styleProfileSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.stackMd) {
            Text("YOUR STYLE PROFILE")
                .font(DesignSystem.labelMd)
                .foregroundColor(DesignSystem.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(DesignSystem.trackingLabel)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let styleProfile {
                VStack(alignment: .leading, spacing: DesignSystem.gutter) {
                    styleProfileRow(
                        label: "VIBE",
                        value: styleProfile.styleVibes.map(\.rawValue).joined(separator: ", ")
                    )
                    styleProfileRow(
                        label: "PRIORITY",
                        value: styleProfile.priority.rawValue
                    )
                    styleProfileRow(
                        label: "SHOP FOR",
                        value: styleProfile.gender?.rawValue ?? "Not set"
                    )
                    styleProfileRow(
                        label: "BODY TYPE",
                        value: styleProfile.bodyType.rawValue
                    )
                }

                Button("Edit Style Profile") {
                    isShowingStyleProfileEdit = true
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("Set Up Style Profile") {
                    isShowingStyleProfileEdit = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func styleProfileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.labelMd)
                .foregroundColor(DesignSystem.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(DesignSystem.trackingLabel)

            Spacer()

            Text(value)
                .font(DesignSystem.labelMd)
                .foregroundColor(DesignSystem.onPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DesignSystem.primary)
                .clipShape(Capsule())
        }
    }

    private func reloadStyleProfile() {
        styleProfile = StyleProfileStore().load()
    }

    private var profilePhotoPreview: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.surfaceContainerLow)
                .frame(width: DesignSystem.profilePhotoSize, height: DesignSystem.profilePhotoSize)

            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DesignSystem.profilePhotoSize, height: DesignSystem.profilePhotoSize)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: DesignSystem.stackLg))
                    .foregroundColor(DesignSystem.secondary)
            }
        }
        .overlay(Circle().stroke(DesignSystem.primary, lineWidth: DesignSystem.dashedLineWidth))
        .modifier(HighFashionShadow())
    }
}

#Preview {
    SettingsView()
}
