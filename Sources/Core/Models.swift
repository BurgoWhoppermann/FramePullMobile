import Foundation
import CoreGraphics
import AVFoundation
import SwiftUI

enum OutputFormat: String, CaseIterable {
    case mp4 = "MP4"

    var fileType: String {
        switch self {
        case .mp4: return "mp4"
        }
    }
}

enum GIFResolution: String, CaseIterable {
    case small = "480w"
    case hd720 = "720p"
    case hd1080 = "1080p"

    var maxWidth: Int {
        switch self {
        case .small: return 480
        case .hd720: return 1280
        case .hd1080: return 1920
        }
    }

    var displayName: String {
        switch self {
        case .small: return "480w (Small)"
        case .hd720: return "720p (HD)"
        case .hd1080: return "1080p (Full HD)"
        }
    }
}

enum StillFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case png = "PNG"
    case tiff = "TIFF"

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .tiff: return "tiff"
        }
    }
}

enum ClipQuality: String, CaseIterable {
    case sd480 = "480p"
    case hd720 = "720p"
    case fullHD = "1080p"
    case uhd = "4K (UHD)"
    case source = "Source"

    var exportPreset: String {
        switch self {
        case .sd480: return AVAssetExportPreset640x480
        case .hd720: return AVAssetExportPreset1280x720
        case .fullHD: return AVAssetExportPreset1920x1080
        case .uhd: return AVAssetExportPreset3840x2160
        case .source: return AVAssetExportPresetHighestQuality
        }
    }
    
    var displayName: String { rawValue }
}

extension Color {
    static let framePullNavy   = Color(red: 0.039, green: 0.122, blue: 0.247) // #0A1F3F Deep Navy
    static let framePullAmber  = Color(red: 0.949, green: 0.620, blue: 0.173) // #F29E2C Warm Amber
    static let framePullSilver = Color(red: 0.875, green: 0.902, blue: 0.929) // #DFE6ED Light Silver
    static let framePullBlue      = Color(red: 0.29, green: 0.56, blue: 0.85)   // #4A90D9
    static let framePullLightBlue = Color(red: 0.29, green: 0.56, blue: 0.85).opacity(0.1)
}
