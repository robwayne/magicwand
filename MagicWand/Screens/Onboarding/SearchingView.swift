import SwiftUI

/// "Setting up" / searching screen (IMG_9691). Shows an animated phone illustration
/// and an indeterminate progress bar while SSDP discovery runs.
struct SearchingView: View {
    @State private var progress: CGFloat = 0.1
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            StepDots(total: 4, current: 1)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Setting up")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Please wait while the application finishes the configuration process")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 40)
            }

            Spacer()

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Theme.accent.opacity(0.18), lineWidth: 1)
                        .frame(width: 180 + CGFloat(i) * 50, height: 180 + CGFloat(i) * 50)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .opacity(pulse ? 0.8 : 0.4)
                }

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 120, height: 230)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(
                        VStack(spacing: 10) {
                            Text("U")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Searching for TVs…")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    )
            }
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

            Spacer()

            ProgressBar(progress: progress)
                .frame(height: 52)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
        }
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 3.2)) { progress = 0.92 }
        }
    }
}

/// The filled rounded progress bar with a percentage label.
private struct ProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(40, geo.size.width * progress))
                    .overlay(
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}
