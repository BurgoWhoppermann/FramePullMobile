import SwiftUI
import AVKit

/// A custom video player that hides all native controls
/// and allows tap-to-play/pause.
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Crucial for clean UI
        controller.videoGravity = .resizeAspect
        
        // Add tap gesture for play/pause
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        controller.view.addGestureRecognizer(tapGesture)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CustomVideoPlayer
        
        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            let player = parent.player
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
    }
}
