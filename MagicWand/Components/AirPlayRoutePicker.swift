import SwiftUI
import AVKit
import UIKit

/// A SwiftUI wrapper around `AVRoutePickerView` so users can pick the TV as an
/// AirPlay destination for the casting tab. This is the supported way for a
/// third-party app to route media/screen to an LG TV over AirPlay.
struct AirPlayRoutePicker: UIViewRepresentable {
    var tint: UIColor = UIColor(Theme.textSecondary)
    var activeTint: UIColor = UIColor(Theme.accent)

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = tint
        picker.activeTintColor = activeTint
        picker.prioritizesVideoDevices = true
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
        uiView.activeTintColor = activeTint
    }
}
