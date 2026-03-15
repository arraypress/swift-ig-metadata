//
//  IGMetadata.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

@preconcurrency import struct Foundation.URLRequest

#if canImport(FoundationNetworking)
@preconcurrency import FoundationNetworking
#endif

/// Fetch metadata from Instagram posts without authentication.
///
/// `IGMetadata` uses Instagram's public GraphQL endpoint — the same approach as yt-dlp —
/// to fetch comprehensive post metadata. No API key, developer account, or login required.
///
/// The fetch pipeline:
/// 1. Hit Instagram's ruling API to establish a session and obtain a CSRF token
/// 2. Query the GraphQL endpoint with the CSRF token and doc_id `8845758582119845`
/// 3. Fall back to embed page and direct page scraping if GraphQL fails
///
/// ## Quick Start
///
/// ```swift
/// import IGMetadata
///
/// let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")
///
/// print(post.caption ?? "No caption")
/// print(post.author.username ?? "Unknown")
/// print("Likes: \(post.formattedLikeCount ?? "N/A")")
///
/// if let video = post.video {
///     print("Duration: \(video.formattedDuration)")
///     if let url = video.bestUrl {
///         print("Download: \(url)")
///     }
/// }
/// ```
///
/// ## Supported URL Formats
///
/// - `https://www.instagram.com/reel/ABC123/`
/// - `https://www.instagram.com/p/ABC123/`
/// - `https://www.instagram.com/reels/ABC123/`
/// - `https://www.instagram.com/tv/ABC123/`
/// - Raw shortcodes (e.g., `"ABC123DEF"`)
public enum IGMetadata {

    // MARK: - Configuration

    /// Instagram's web application ID, used in all API requests.
    ///
    /// This is the same app ID used by Instagram's web frontend and all major
    /// scraping libraries including yt-dlp.
    private static let appId = "936619743392459"

    /// The GraphQL document ID for fetching post data.
    ///
    /// Mirrors yt-dlp's `doc_id` for the shortcode media query.
    private static let graphqlDocId = "8845758582119845"

    /// The User-Agent header sent with all requests.
    private static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"

    // MARK: - Public API

    /// Fetches metadata for an Instagram post.
    ///
    /// Uses Instagram's GraphQL endpoint to retrieve comprehensive post metadata
    /// including caption, author info, engagement counts, video URLs, photo URLs,
    /// and carousel items. Falls back to embed page and direct page scraping if
    /// the GraphQL endpoint is unavailable.
    ///
    /// Supports all common URL formats:
    /// - `https://www.instagram.com/reel/ABC123/`
    /// - `https://www.instagram.com/p/ABC123/`
    /// - `https://www.instagram.com/reels/ABC123/`
    /// - `https://www.instagram.com/tv/ABC123/`
    /// - `"ABC123DEF"` (raw shortcode)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")
    ///
    /// // Basic info
    /// print(post.caption ?? "No caption")
    /// print(post.author.username ?? "Unknown")
    /// print("Likes: \(post.formattedLikeCount ?? "N/A")")
    ///
    /// // Video download URL (highest quality)
    /// if let videoUrl = post.video?.bestUrl {
    ///     print("Download: \(videoUrl)")
    /// }
    ///
    /// // Photos
    /// for photo in post.photos {
    ///     print("\(photo.url) (\(photo.width)x\(photo.height))")
    /// }
    ///
    /// // Carousel items
    /// for item in post.carouselItems {
    ///     print("\(item.isVideo ? "Video" : "Photo"): \(item.displayUrl)")
    /// }
    ///
    /// // Entities
    /// print(post.hashtags)
    /// print(post.mentions)
    /// ```
    ///
    /// - Parameter input: An Instagram post URL or shortcode.
    /// - Throws: ``IGMetadataError`` if the metadata cannot be retrieved.
    /// - Returns: A ``PostMetadata`` with all available fields populated.
    public static func fetch(_ input: String) async throws -> PostMetadata {
        let shortcode = try Shortcode.extract(from: input)

        // Set up a session with cookie persistence (mirrors yt-dlp's session setup)
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = HTTPCookieStorage.shared
        let session = URLSession(configuration: config)

        // Step 1: Establish session and get CSRF token via ruling API
        let csrfToken = await setupSession(shortcode: shortcode, session: session)

        // Step 2: Query GraphQL with CSRF token
        if let media = try? await fetchGraphQL(shortcode: shortcode, csrfToken: csrfToken, session: session) {
            return media
        }

        // Step 3: Fallback — embed page
        if let media = try? await fetchFromEmbed(shortcode: shortcode) {
            return media
        }

        // Step 4: Fallback — direct page scraping
        if let media = try? await fetchFromDirectPage(shortcode: shortcode) {
            return media
        }

        throw IGMetadataError.postNotFound
    }

    // MARK: - Session Setup

    /// Establishes a session with Instagram and retrieves a CSRF token.
    ///
    /// Mirrors yt-dlp's "Setting up session" step. Hits the ruling API endpoint
    /// which sets cookies (including `csrftoken`) needed for subsequent GraphQL requests.
    ///
    /// - Parameters:
    ///   - shortcode: The post shortcode, used to compute the media PK.
    ///   - session: The URLSession with cookie persistence.
    /// - Returns: The CSRF token string, or `nil` if it could not be obtained.
    private static func setupSession(shortcode: String, session: URLSession) async -> String? {
        let pk = Shortcode.toPk(shortcode)
        guard let url = URL(string: "https://i.instagram.com/api/v1/web/get_ruling_for_content/?content_type=MEDIA&target_id=\(pk)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(appId, forHTTPHeaderField: "X-IG-App-ID")
        request.setValue("0", forHTTPHeaderField: "X-IG-WWW-Claim")
        request.setValue("https://www.instagram.com", forHTTPHeaderField: "Origin")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        _ = try? await session.data(for: request)

        // Extract csrftoken from cookies
        guard let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://www.instagram.com")!) else {
            return nil
        }
        return cookies.first(where: { $0.name == "csrftoken" })?.value
    }

    // MARK: - GraphQL Endpoint

    /// Fetches post metadata from Instagram's GraphQL endpoint.
    ///
    /// This is the primary fetch method. It sends a POST request to Instagram's GraphQL
    /// endpoint with the shortcode and doc_id `8845758582119845`, using the CSRF token
    /// obtained during session setup.
    ///
    /// - Parameters:
    ///   - shortcode: The post shortcode.
    ///   - csrfToken: The CSRF token from session setup.
    ///   - session: The URLSession with cookie persistence.
    /// - Throws: ``IGMetadataError`` on network failure or invalid response.
    /// - Returns: A ``PostMetadata`` with all available fields populated.
    private static func fetchGraphQL(shortcode: String, csrfToken: String?, session: URLSession) async throws -> PostMetadata {
        guard let url = URL(string: "https://www.instagram.com/graphql/query/") else {
            throw IGMetadataError.parsingError("Invalid GraphQL URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(appId, forHTTPHeaderField: "X-IG-App-ID")
        request.setValue("198387", forHTTPHeaderField: "X-ASBD-ID")
        request.setValue("0", forHTTPHeaderField: "X-IG-WWW-Claim")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.instagram.com", forHTTPHeaderField: "Origin")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let csrf = csrfToken {
            request.setValue(csrf, forHTTPHeaderField: "X-CSRFToken")
        }

        let variables: [String: Any] = [
            "shortcode": shortcode,
            "child_comment_count": 3,
            "fetch_comment_count": 40,
            "parent_comment_count": 24,
            "has_threaded_comments": true
        ]
        let variablesData = try JSONSerialization.data(withJSONObject: variables)
        let variablesStr = String(data: variablesData, encoding: .utf8) ?? "{}"
        let body = "variables=\(variablesStr)&doc_id=\(graphqlDocId)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 { throw IGMetadataError.rateLimited }
            if httpResponse.statusCode != 200 {
                throw IGMetadataError.networkError("GraphQL HTTP \(httpResponse.statusCode)")
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            throw IGMetadataError.parsingError("Invalid GraphQL JSON")
        }

        // Navigate: data.xdt_shortcode_media or data.shortcode_media
        guard let media = (dataObj["xdt_shortcode_media"] as? [String: Any])
                ?? (dataObj["shortcode_media"] as? [String: Any]),
              !media.isEmpty else {
            throw IGMetadataError.postNotFound
        }

        return parseGraphQLMedia(media, shortcode: shortcode)
    }

    // MARK: - GraphQL Response Parsing

    /// Parses a GraphQL media dictionary into a ``PostMetadata`` struct.
    ///
    /// Handles all three media types (photo, video, carousel) and extracts all
    /// available metadata fields including caption, author, engagement, dimensions,
    /// video variants, and carousel items.
    ///
    /// - Parameters:
    ///   - media: The media dictionary from the GraphQL response.
    ///   - shortcode: The post shortcode.
    /// - Returns: A fully populated ``PostMetadata`` struct.
    private static func parseGraphQLMedia(_ media: [String: Any], shortcode: String) -> PostMetadata {
        let mediaType = MediaType(media: media)

        // Caption — try edge format first, then direct
        let caption = (media["edge_media_to_caption"] as? [String: Any])
            .flatMap { $0["edges"] as? [[String: Any]] }
            .flatMap { $0.first?["node"] as? [String: Any] }
            .flatMap { $0["text"] as? String }
            ?? media["caption"] as? String

        // Owner/author
        let owner = media["owner"] as? [String: Any] ?? [:]
        let author = AuthorInfo(
            name: owner["full_name"] as? String,
            username: owner["username"] as? String,
            id: owner["id"] as? String,
            profilePicUrl: owner["profile_pic_url"] as? String,
            isVerified: owner["is_verified"] as? Bool ?? false
        )

        // Engagement
        let likeCount = (media["edge_media_preview_like"] as? [String: Any])?["count"] as? Int
            ?? media["like_count"] as? Int
        let commentCount = (media["edge_media_to_comment"] as? [String: Any])?["count"] as? Int
            ?? media["comment_count"] as? Int

        // Dimensions
        let dimensions = media["dimensions"] as? [String: Any]
        let width = dimensions?["width"] as? Int
        let height = dimensions?["height"] as? Int

        // Timestamp
        let timestamp = media["taken_at_timestamp"] as? Double
            ?? media["taken_at"] as? Double
        let createdAt = timestamp.map { Date(timeIntervalSince1970: $0) }

        // Location
        let locationName = (media["location"] as? [String: Any])?["name"] as? String

        // Video info
        var videoInfo: VideoInfo? = nil
        if media["is_video"] as? Bool == true || mediaType.hasVideo {
            let videoUrl = media["video_url"] as? String ?? ""
            let viewCount = media["video_view_count"] as? Int
                ?? media["view_count"] as? Int

            // Video variants from video_versions array
            var variants: [VideoVariant] = []
            if let versions = media["video_versions"] as? [[String: Any]] {
                for version in versions {
                    if let vUrl = version["url"] as? String {
                        variants.append(VideoVariant(
                            url: vUrl,
                            width: version["width"] as? Int ?? 0,
                            height: version["height"] as? Int ?? 0,
                            id: (version["id"] as? Int).map(String.init)
                        ))
                    }
                }
            }

            videoInfo = VideoInfo(
                url: videoUrl,
                durationSeconds: media["video_duration"] as? Double ?? 0,
                width: width ?? 0,
                height: height ?? 0,
                viewCount: viewCount,
                variants: variants
            )
        }

        // Photos — for single image posts
        var photos: [PhotoInfo] = []
        if !mediaType.hasVideo && !mediaType.isCarousel {
            if let displayUrl = media["display_url"] as? String {
                photos.append(PhotoInfo(
                    url: displayUrl,
                    width: width ?? 0,
                    height: height ?? 0,
                    accessibilityCaption: media["accessibility_caption"] as? String
                ))
            }
        }

        // Carousel items
        var carouselItems: [CarouselItem] = []
        if let edges = (media["edge_sidecar_to_children"] as? [String: Any])?["edges"] as? [[String: Any]] {
            for edge in edges {
                guard let node = edge["node"] as? [String: Any] else { continue }
                let isVideo = node["is_video"] as? Bool ?? false
                let itemDimensions = node["dimensions"] as? [String: Any]

                let item = CarouselItem(
                    isVideo: isVideo,
                    displayUrl: node["display_url"] as? String ?? "",
                    videoUrl: isVideo ? node["video_url"] as? String : nil,
                    videoDuration: isVideo ? node["video_duration"] as? Double : nil,
                    width: itemDimensions?["width"] as? Int ?? 0,
                    height: itemDimensions?["height"] as? Int ?? 0,
                    accessibilityCaption: node["accessibility_caption"] as? String
                )
                carouselItems.append(item)

                // Also populate photos array for photo items
                if !isVideo {
                    photos.append(PhotoInfo(
                        url: node["display_url"] as? String ?? "",
                        width: itemDimensions?["width"] as? Int ?? 0,
                        height: itemDimensions?["height"] as? Int ?? 0,
                        accessibilityCaption: node["accessibility_caption"] as? String
                    ))
                }
            }
        }

        return PostMetadata(
            shortcode: shortcode,
            id: media["id"] as? String,
            url: "https://www.instagram.com/p/\(shortcode)/",
            mediaType: mediaType,
            caption: caption,
            accessibilityCaption: media["accessibility_caption"] as? String,
            author: author,
            likeCount: likeCount,
            commentCount: commentCount,
            displayUrl: media["display_url"] as? String,
            video: videoInfo,
            photos: photos,
            carouselItems: carouselItems,
            width: width,
            height: height,
            createdAt: createdAt,
            locationName: locationName
        )
    }

    // MARK: - Embed Fallback

    /// Fetches post metadata from Instagram's embed page.
    ///
    /// Falls back to scraping the embed page (`/reel/ABC123/embed/` or `/p/ABC123/embed/`)
    /// for the video URL when the GraphQL endpoint is unavailable. Returns minimal metadata.
    ///
    /// - Parameter shortcode: The post shortcode.
    /// - Throws: ``IGMetadataError`` if no video URL can be found.
    /// - Returns: A ``PostMetadata`` with minimal fields populated.
    private static func fetchFromEmbed(shortcode: String) async throws -> PostMetadata {
        for pathPrefix in ["reel", "p"] {
            guard let embedUrl = URL(string: "https://www.instagram.com/\(pathPrefix)/\(shortcode)/embed/") else { continue }

            var request = URLRequest(url: embedUrl)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            guard let (data, _) = try? await URLSession.shared.data(for: request) else { continue }
            let html = String(data: data, encoding: .utf8) ?? ""

            // Look for video_url in embedded JSON or script data
            let patterns = [
                #""video_url"\s*:\s*"([^"]+)""#,
                #""contentUrl"\s*:\s*"([^"]+)""#,
                #"video_url=([^&"]+)"#,
                #"<source\s+src="([^"]+)"\s+type="video"#
            ]

            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                      let range = Range(match.range(at: 1), in: html) else { continue }

                let rawUrl = String(html[range])
                    .replacingOccurrences(of: "\\u0026", with: "&")
                    .replacingOccurrences(of: "\\/", with: "/")
                    .removingPercentEncoding ?? String(html[range])

                if rawUrl.contains("video") || rawUrl.contains(".mp4") {
                    return makeMinimalPost(
                        shortcode: shortcode,
                        videoUrl: rawUrl,
                        mediaType: .video
                    )
                }
            }

            // Also try to find display_url for photos
            let photoPattern = #""display_url"\s*:\s*"([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: photoPattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let rawUrl = String(html[range])
                    .replacingOccurrences(of: "\\u0026", with: "&")
                    .replacingOccurrences(of: "\\/", with: "/")
                return makeMinimalPost(
                    shortcode: shortcode,
                    photoUrl: rawUrl,
                    mediaType: .photo
                )
            }
        }

        throw IGMetadataError.postNotFound
    }

    // MARK: - Direct Page Fallback

    /// Fetches post metadata from Instagram's direct page.
    ///
    /// Falls back to scraping the full page for `og:video` meta tags and JSON blobs
    /// when both GraphQL and embed page are unavailable. Returns minimal metadata.
    ///
    /// - Parameter shortcode: The post shortcode.
    /// - Throws: ``IGMetadataError`` if no media URL can be found.
    /// - Returns: A ``PostMetadata`` with minimal fields populated.
    private static func fetchFromDirectPage(shortcode: String) async throws -> PostMetadata {
        for pathPrefix in ["reel", "p"] {
            guard let pageUrl = URL(string: "https://www.instagram.com/\(pathPrefix)/\(shortcode)/") else { continue }

            var request = URLRequest(url: pageUrl)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            guard let (data, _) = try? await URLSession.shared.data(for: request) else { continue }
            let html = String(data: data, encoding: .utf8) ?? ""

            // Look for og:video meta tag
            let ogVideoPattern = #"<meta\s+(?:property|name)="og:video(?::url)?"\s+content="([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: ogVideoPattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let rawUrl = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                return makeMinimalPost(
                    shortcode: shortcode,
                    videoUrl: rawUrl,
                    mediaType: .video
                )
            }

            // Look for og:image meta tag
            let ogImagePattern = #"<meta\s+(?:property|name)="og:image"\s+content="([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: ogImagePattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let rawUrl = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                return makeMinimalPost(
                    shortcode: shortcode,
                    photoUrl: rawUrl,
                    mediaType: .photo
                )
            }

            // Also look for video_url in any JSON blob on the page
            let videoJsonPattern = #""video_url"\s*:\s*"([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: videoJsonPattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let rawUrl = String(html[range])
                    .replacingOccurrences(of: "\\u0026", with: "&")
                    .replacingOccurrences(of: "\\/", with: "/")
                return makeMinimalPost(
                    shortcode: shortcode,
                    videoUrl: rawUrl,
                    mediaType: .video
                )
            }
        }

        throw IGMetadataError.postNotFound
    }

    // MARK: - Helpers

    /// Creates a minimal ``PostMetadata`` for fallback fetchers with limited data.
    private static func makeMinimalPost(
        shortcode: String,
        videoUrl: String? = nil,
        photoUrl: String? = nil,
        mediaType: MediaType
    ) -> PostMetadata {
        let video: VideoInfo? = videoUrl.map {
            VideoInfo(url: $0, durationSeconds: 0, width: 0, height: 0, viewCount: nil, variants: [])
        }
        let photos: [PhotoInfo] = photoUrl.map {
            [PhotoInfo(url: $0, width: 0, height: 0, accessibilityCaption: nil)]
        } ?? []

        return PostMetadata(
            shortcode: shortcode,
            id: nil,
            url: "https://www.instagram.com/p/\(shortcode)/",
            mediaType: mediaType,
            caption: nil,
            accessibilityCaption: nil,
            author: AuthorInfo(name: nil, username: nil, id: nil, profilePicUrl: nil, isVerified: false),
            likeCount: nil,
            commentCount: nil,
            displayUrl: photoUrl,
            video: video,
            photos: photos,
            carouselItems: [],
            width: nil,
            height: nil,
            createdAt: nil,
            locationName: nil
        )
    }

}
