//
//  VideoVariant.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A single video format variant at a specific resolution.
///
/// Instagram serves videos at multiple resolutions. Each variant includes
/// the direct URL and dimensions.
public struct VideoVariant: Sendable {
    
    /// The direct URL to this variant.
    public let url: String
    
    /// Video width in pixels for this variant.
    public let width: Int
    
    /// Video height in pixels for this variant.
    public let height: Int
    
    /// The variant's identifier, if available.
    public let id: String?
    
    /// The MIME type. Instagram videos are always `"video/mp4"`.
    public var contentType: String { "video/mp4" }
    
}
