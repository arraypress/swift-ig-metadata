//
//  Shortcode.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Utility for extracting Instagram shortcodes from various URL formats.
///
/// Supports `/p/`, `/reel/`, `/reels/`, and `/tv/` paths, with optional
/// username prefixes and tracking parameters.
public enum Shortcode {
    
    /// Regex pattern for extracting shortcodes from Instagram URLs.
    ///
    /// Matches paths like:
    /// - `/reel/ABC123/`
    /// - `/p/ABC123/`
    /// - `/reels/ABC123/`
    /// - `/tv/ABC123/`
    /// - `/username/reel/ABC123/`
    private static let pattern = #"instagram\.com/(?:[A-Za-z0-9_.]+/)?(?:p|reels?|tv)/([A-Za-z0-9_-]+)"#
    
    /// Extracts a shortcode from a URL string.
    ///
    /// Accepts:
    /// - `https://www.instagram.com/reel/ABC123/`
    /// - `https://www.instagram.com/p/ABC123/`
    /// - `https://www.instagram.com/reels/ABC123/`
    /// - `https://www.instagram.com/tv/ABC123/`
    /// - URLs with tracking parameters (stripped automatically)
    /// - Raw shortcodes (alphanumeric strings of 8+ characters)
    ///
    /// - Parameter input: An Instagram URL or raw shortcode.
    /// - Throws: ``IGMetadataError/invalidShortcode`` if no valid shortcode can be extracted.
    /// - Returns: The shortcode string.
    public static func extract(from input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try URL pattern first
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = regex.firstMatch(in: trimmed, range: range),
               let codeRange = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[codeRange])
            }
        }
        
        // Raw shortcode (alphanumeric + hyphen/underscore, 8+ chars)
        let shortcodePattern = #"^[A-Za-z0-9_-]{8,}$"#
        if let regex = try? NSRegularExpression(pattern: shortcodePattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return trimmed
        }
        
        throw IGMetadataError.invalidShortcode
    }
    
    /// Extracts the username from an Instagram URL, if present.
    ///
    /// Only works for URLs where the username appears before the path type
    /// (e.g., `instagram.com/username/reel/ABC123/`). Standard URLs like
    /// `instagram.com/reel/ABC123/` will return `nil`.
    ///
    /// - Parameter input: An Instagram URL.
    /// - Returns: The username, or `nil` if not found.
    public static func extractUsername(from input: String) -> String? {
        let pattern = #"instagram\.com/([A-Za-z0-9_.]+)/(?:p|reels?|tv)/"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let match = regex.firstMatch(in: input, range: range),
              let handleRange = Range(match.range(at: 1), in: input) else { return nil }
        let candidate = String(input[handleRange])
        // Filter out path-type words that match the pattern
        let reserved = ["p", "reel", "reels", "tv", "stories", "explore"]
        return reserved.contains(candidate.lowercased()) ? nil : candidate
    }
    
    /// Converts a shortcode to its numeric media PK.
    ///
    /// Uses the same base64-to-integer algorithm as yt-dlp's `_id_to_pk`.
    /// Instagram shortcodes are base64-encoded representations of the numeric
    /// media ID using the alphabet `A-Za-z0-9-_`.
    ///
    /// - Parameter shortcode: The Instagram shortcode.
    /// - Returns: The numeric media PK as a string.
    public static func toPk(_ shortcode: String) -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let code = shortcode.count > 28 ? String(shortcode.prefix(shortcode.count - 28)) : shortcode
        var pk: UInt64 = 0
        for char in code {
            if let index = alphabet.firstIndex(of: char) {
                pk = pk * 64 + UInt64(alphabet.distance(from: alphabet.startIndex, to: index))
            }
        }
        return String(pk)
    }
    
}
