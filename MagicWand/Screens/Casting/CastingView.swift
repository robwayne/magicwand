import SwiftUI
import PhotosUI

/// The media-casting tab. Presents the "Media casting" hero card and a button to
/// pick photos/videos from the library. Actual streaming to the TV is performed via
/// AirPlay (the user routes output through the AirPlay picker in the header / system).
struct CastingView: View {
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            Theme.castGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                ConnectionHeader()
                Spacer()
                heroCard
                Spacer()
            }
        }
        .sheet(isPresented: $showPlayer) {
            CastPlayerView(items: pickedItems)
        }
        .onChange(of: pickedItems) { _, newValue in
            if !newValue.isEmpty { showPlayer = true }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 20) {
            PhotoStackArt()
                .frame(height: 150)

            VStack(spacing: 10) {
                Text("Media casting")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Seamlessly stream photos from your phone to the big TV screen with real-time casting")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 24)
            }

            PhotosPicker(
                selection: $pickedItems,
                maxSelectionCount: 20,
                matching: .any(of: [.images, .videos])
            ) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photos & Videos")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("from your gallery")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .padding(.horizontal, 18)
    }
}

/// The stacked-photos illustration on the casting card.
private struct PhotoStackArt: View {
    var body: some View {
        ZStack {
            tile(color: .green, rotation: -12, offset: CGSize(width: -36, height: 18))
            tile(color: .blue, rotation: 8, offset: CGSize(width: 36, height: 10))
            tile(color: .pink, rotation: -2, offset: CGSize(width: 0, height: -10))
        }
    }

    private func tile(color: Color, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(color.opacity(0.85))
            .frame(width: 88, height: 88)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

#Preview {
    CastingView()
        .environment(TVConnectionManager())
        .environment(TVStore())
}
