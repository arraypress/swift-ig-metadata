//
//  VideoInfo.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Metadata about a video from an Instagram post.
public struct VideoInfo: Sendable {
    
    /// The direct video URL (highest quality available).
    public let url: String
    
    /// Video duration in seconds.
    public let durationSeconds: Double
    
    /// Video width in pixels.
    public let width: Int
    
    /// Video height in pixels.
    public let height: Int
    
    /// Number of video views.
    public let viewCount: Int?
    
    /// Available video format variants at different qualities.
    ///
    /// Instagram's GraphQL response may include multiple `video_versions`
    /// at different resolutions. Use ``bestUrl`` for the highest quality.
    public let variants: [VideoVariant]
    
    /// The highest-quality direct MP4 download URL.
    ///
    /// Returns the variant with the largest dimensions, falling back to
    /// the primary ``url`` if no variants are available.
    public var bestUrl: URL? {
        let best = variants
            .sorted { ($0.width * $0.height) > ($1.width * $1.height) }
            .first
        
        return URL(string: best?.url ?? url)
    }
    
    /// The duration formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedDuration: String {
        let total = Int(durationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
    }
    
    /// The view count formatted with locale-appropriate grouping separators.
    ///
    /// Returns `nil` if the view count is unavailable.
    public var formattedViewCount: String? {
        guard let count = viewCount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count))
    }
    
}
