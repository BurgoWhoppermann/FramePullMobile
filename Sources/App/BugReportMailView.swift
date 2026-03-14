import SwiftUI
import MessageUI

struct BugReportMailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let screenshot: UIImage
    let bodyText: String
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: BugReportMailView
        
        init(_ parent: BugReportMailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        guard MFMailComposeViewController.canSendMail() else {
            // Fallback if mail is not configured
            return MFMailComposeViewController()
        }
        
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["mail@carlooppermann.com"])
        vc.setSubject("FramePull Mobile Bug Report")
        vc.setMessageBody(bodyText, isHTML: false)
        
        if let jpegData = screenshot.jpegData(compressionQuality: 0.8) {
            vc.addAttachmentData(jpegData, mimeType: "image/jpeg", fileName: "screenshot.jpg")
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
