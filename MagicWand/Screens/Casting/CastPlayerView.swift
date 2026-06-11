import SwiftUI
import PhotosUI
import AVKit
import UIKit

/// Displays the picked photos/videos full-screen with an AirPlay button so the user
/// can mirror them to the TV. Photos advance as a simple slideshow; videos play inline.
struct CastPlayerView: View {
    let items: [PhotosPickerItem]
    @Environment(\.dismiss) private var dismiss

    @State private var images: [Image] = []
    @State private var index = 0
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if images.isEmpty {
                ContentUnavailableView("Nothing to cast",
                                       systemImage: "photo",
                                       description: Text("Selected media could not be loaded."))
                    .foregroundStyle(.white)
            } else {
                TabView(selection: $index) {
                    ForEach(images.indices, id: \.self) { i in
                        images[i]
                            .resizable()
                            .scaledToFit()
                            .tag(i)
                    }
                }
                .tabViewStyle(.page)
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    AirPlayRoutePicker(tint: .white, activeTint: UIColor(Theme.accent))
                        .frame(width: 36, height: 36)
                }
                .padding()
                Spacer()
            }
        }
        .task { await loadImages() }
    }

    private func loadImages() async {
        var loaded: [Image] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                loaded.append(Image(uiImage: uiImage))
            }
        }
        images = loaded
        isLoading = false
    }
}
