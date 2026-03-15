//
//  AuthorInfo.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Information about the author of an Instagram post.
public struct AuthorInfo: Sendable {
    
    /// The author's display name.
    public let name: String?
    
    /// The author's handle/username (without @).
    public let username: String?
    
    /// The author's numeric user ID.
    public let id: String?
    
    /// URL to the author's profile picture.
    public let profilePicUrl: String?
    
    /// Whether the author is verified.
    public let isVerified: Bool
    
    /// The author's profile URL.
    public var profileUrl: String? {
        guard let username = username else { return nil }
        return "https://www.instagram.com/\(username)/"
    }
    
}
