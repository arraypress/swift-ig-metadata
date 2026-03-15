//
//  IGMetadataError.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Errors that can occur when fetching Instagram post metadata.
///
/// ```swift
/// do {
///     let post = try await IGMetadata.fetch(url)
/// } catch IGMetadataError.invalidUrl {
///     print("Not a valid Instagram URL")
/// } catch IGMetadataError.postNotFound {
///     print("Post doesn't exist or was deleted")
/// } catch {
///     print(error.localizedDescription)
/// }
/// ```
public enum IGMetadataError: Error, LocalizedError, Equatable, Sendable {

    /// The provided URL is not a valid Instagram post URL.
    case invalidUrl

    /// Could not extract a shortcode from the URL.
    case invalidShortcode

    /// The post was not found (deleted, private, or removed).
    case postNotFound

    /// Instagram is rate-limiting requests from this IP.
    case rateLimited

    /// No video found in this post (expected video but got photo/carousel only).
    case noVideoFound

    /// A network request failed.
    case networkError(String)

    /// Failed to parse response data.
    case parsingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid Instagram URL. Provide a URL like https://www.instagram.com/reel/ABC123/"
        case .invalidShortcode:
            return "Could not extract a shortcode from the URL."
        case .postNotFound:
            return "Post not found. It may have been deleted or set to private."
        case .rateLimited:
            return "Instagram is rate-limiting requests. Try again later."
        case .noVideoFound:
            return "No video found in this post."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        }
    }

}
