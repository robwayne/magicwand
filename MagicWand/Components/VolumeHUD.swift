import SwiftUI

/// An iPhone-style volume HUD that only appears inside MagicWand. A tall rounded pill with
/// a white fill that rises/falls with the TV volume, a speaker icon at the bottom, and the
/// volume percentage centered at the top (styled like the icon). Drag up/down on the pill
/// to set the volume directly.
struct VolumeHUD: View {
    @Environment(TVConnectionManager.self) private var connection

    private let size = CGSize(width: 74, height: 230)
    private let corner: CGFloat = 37

    var body: some View {
        let fraction = CGFloat(connection.currentVolume) / 100

        ZStack {
            // Frosted track.
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            // White fill from the bottom.
            VStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(.white)
                    .frame(height: max(corner, size.height * fraction))
            }
            .clipShape(Capsule(style: .continuous))

            // Content (percentage top, speaker bottom), drawn twice so the colour inverts
            // depending on whether it sits over the white fill or the dark track — like iOS.
            content
                .foregroundStyle(.white)
            content
                .foregroundStyle(.black)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: max(corner, size.height * fraction))
                }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            Capsule(style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        .contentShape(Capsule(style: .continuous))
        .gesture(dragGesture)
        .animation(.easeOut(duration: 0.12), value: connection.currentVolume)
    }

    private var content: some View {
        VStack {
            Text("\(connection.currentVolume)%")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Spacer(minLength: 0)
            Image(systemName: "tv")
                .font(.system(size: 20, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: connection.volumeMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    /// Map the touch's vertical position within the pill to a 0–100 volume.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let y = min(max(0, value.location.y), size.height)
                let level = Int(((size.height - y) / size.height * 100).rounded())
                connection.setVolume(level)
            }
    }
}
