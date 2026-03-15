//
//  PostMetadata.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Metadata about an Instagram post.
///
/// Fetched from Instagram's public GraphQL endpoint without authentication.
/// Supports reels, photos, and carousel/sidecar posts.
///
/// ```swift
/// let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")
/// print(post.caption ?? "No caption")
/// print("\(post.author.name ?? "Unknown") (@\(post.author.username ?? ""))")
/// print("Likes: \(post.formattedLikeCount ?? "N/A")")
///
/// if let video = post.video {
///     print("Duration: \(video.formattedDuration)")
///     print("Views: \(video.formattedViewCount ?? "N/A")")
/// }
/// ```
public struct PostMetadata: Sendable {
    
    /// The post's shortcode (the alphanumeric ID in the URL).
    public let shortcode: String
    
    /// The post's numeric media ID.
    public let id: String?
    
    /// The full URL of the post.
    public let url: String
    
    /// The media type of the post.
    public let mediaType: MediaType
    
    // MARK: - Content
    
    /// The caption text of the post.
    public let caption: String?
    
    /// Instagram's AI-generated accessibility caption.
    public let accessibilityCaption: String?
    
    // MARK: - Author
    
    /// Information about the post's author.
    public let author: AuthorInfo
    
    // MARK: - Engagement
    
    /// Number of likes.
    public let likeCount: Int?
    
    /// Number of comments.
    public let commentCount: Int?
    
    // MARK: - Media
    
    /// The display/thumbnail URL for the post.
    ///
    /// For video posts, this is the video thumbnail. For photo posts, this is
    /// the main image URL. Useful for previews without loading the full media.
    public let displayUrl: String?
    
    /// Video metadata, if the post is a video/reel.
    public let video: VideoInfo?
    
    /// Photos in the post.
    ///
    /// For single photo posts, contains one item. For carousels, contains
    /// all photo items. Empty for video-only posts.
    public let photos: [PhotoInfo]
    
    /// Carousel items, if the post is a carousel/sidecar.
    ///
    /// Empty for single photo or video posts.
    public let carouselItems: [CarouselItem]
    
    // MARK: - Dimensions
    
    /// The primary display width in pixels.
    public let width: Int?
    
    /// The primary display height in pixels.
    public let height: Int?
    
    // MARK: - Metadata
    
    /// When the post was created.
    public let createdAt: Date?
    
    /// The location name tagged in the post.
    public let locationName: String?
    
    // MARK: - Computed Properties
    
    /// Hashtags extracted from the caption.
    public var hashtags: [String] {
        guard let caption = caption else { return [] }
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: caption, range: NSRange(caption.startIndex..., in: caption))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: caption) else { return nil }
            return String(caption[range])
        }
    }
    
    /// User mentions extracted from the caption.
    public var mentions: [String] {
        guard let caption = caption else { return [] }
        let pattern = #"@(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: caption, range: NSRange(caption.startIndex..., in: caption))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: caption) else { return nil }
            return String(caption[range])
        }
    }
    
    /// URLs extracted from the caption.
    public var urls: [String] {
        guard let caption = caption else { return [] }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: caption, range: NSRange(caption.startIndex..., in: caption)) ?? []
        return matches.compactMap { $0.url?.absoluteString }
    }
    
    /// The like count formatted with locale-appropriate grouping separators.
    ///
    /// Returns `nil` if the like count is unavailable.
    public var formattedLikeCount: String? {
        guard let count = likeCount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count))
    }
    
    /// The comment count formatted with locale-appropriate grouping separators.
    ///
    /// Returns `nil` if the comment count is unavailable.
    public var formattedCommentCount: String? {
        guard let count = commentCount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count))
    }
    
    /// The creation date formatted as a readable string.
    ///
    /// Returns `nil` if the creation date is unavailable.
    public var formattedDate: String? {
        guard let date = createdAt else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    
}
