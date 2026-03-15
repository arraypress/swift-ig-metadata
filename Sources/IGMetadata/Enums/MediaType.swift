//
//  MediaType.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The type of Instagram media.
public enum MediaType: String, Sendable {

    /// A single photo post.
    case photo = "GraphImage"

    /// A single video post (reel, IGTV, or video post).
    case video = "GraphVideo"

    /// A carousel/sidecar post containing multiple photos and/or videos.
    case carousel = "GraphSidecar"

    /// Unknown or unsupported media type.
    case unknown

    /// Initialize from Instagram's `__typename` field.
    ///
    /// - Parameter typename: The GraphQL typename string.
    init(typename: String?) {
        switch typename {
        case "GraphImage", "XDTGraphImage":
            self = .photo
        case "GraphVideo", "XDTGraphVideo":
            self = .video
        case "GraphSidecar", "XDTGraphSidecar":
            self = .carousel
        default:
            self = .unknown
        }
    }

    /// Initialize from a media dictionary, checking multiple fields.
    ///
    /// Falls back through `__typename`, `product_type`, `media_type`, and `is_video`
    /// to determine the correct type.
    ///
    /// - Parameter media: The media dictionary from the GraphQL response.
    init(media: [String: Any]) {
        if let typename = media["__typename"] as? String {
            self = MediaType(typename: typename)
            if self != .unknown { return }
        }

        // product_type: "clips" = reel, "feed" = photo/carousel, "igtv" = IGTV
        if let productType = media["product_type"] as? String {
            switch productType {
            case "clips", "igtv":
                self = .video
                return
            default:
                break
            }
        }

        // media_type: 1 = photo, 2 = video, 8 = carousel
        if let mediaTypeInt = media["media_type"] as? Int {
            switch mediaTypeInt {
            case 1: self = .photo; return
            case 2: self = .video; return
            case 8: self = .carousel; return
            default: break
            }
        }

        // is_video boolean
        if media["is_video"] as? Bool == true {
            self = .video
            return
        }

        // edge_sidecar_to_children presence indicates carousel
        if media["edge_sidecar_to_children"] != nil {
            self = .carousel
            return
        }

        self = .unknown
    }

    /// Whether this media type contains video.
    public var hasVideo: Bool {
        self == .video
    }

    /// Whether this media type is a carousel.
    public var isCarousel: Bool {
        self == .carousel
    }

}
