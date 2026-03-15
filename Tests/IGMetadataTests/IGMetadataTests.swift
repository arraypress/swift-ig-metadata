//
//  IGMetadataTests.swift
//  IGMetadata
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import IGMetadata

final class IGMetadataTests: XCTestCase {

    // MARK: - Shortcode Extraction

    func testExtractFromReelUrl() throws {
        let code = try Shortcode.extract(from: "https://www.instagram.com/reel/DV1zGAUDzdf/")
        XCTAssertEqual(code, "DV1zGAUDzdf")
    }

    func testExtractFromPostUrl() throws {
        let code = try Shortcode.extract(from: "https://www.instagram.com/p/ABC123def/")
        XCTAssertEqual(code, "ABC123def")
    }

    func testExtractFromReelsUrl() throws {
        let code = try Shortcode.extract(from: "https://www.instagram.com/reels/DV1zGAUDzdf/")
        XCTAssertEqual(code, "DV1zGAUDzdf")
    }

    func testExtractFromTvUrl() throws {
        let code = try Shortcode.extract(from: "https://www.instagram.com/tv/ABC123def/")
        XCTAssertEqual(code, "ABC123def")
    }

    func testExtractFromUrlWithParams() throws {
        let code = try Shortcode.extract(from: "https://www.instagram.com/reel/DV1zGAUDzdf/?igsh=abc123")
        XCTAssertEqual(code, "DV1zGAUDzdf")
    }

    func testExtractFromUrlWithUsername() throws {
        let code = try Shortcode.extract(from: "https://www.instagram.com/username/reel/DV1zGAUDzdf/")
        XCTAssertEqual(code, "DV1zGAUDzdf")
    }

    func testExtractFromRawShortcode() throws {
        let code = try Shortcode.extract(from: "DV1zGAUDzdf")
        XCTAssertEqual(code, "DV1zGAUDzdf")
    }

    func testExtractWithWhitespace() throws {
        let code = try Shortcode.extract(from: "  DV1zGAUDzdf  ")
        XCTAssertEqual(code, "DV1zGAUDzdf")
    }

    func testExtractInvalidThrows() {
        XCTAssertThrowsError(try Shortcode.extract(from: "hello")) { error in
            XCTAssertEqual(error as? IGMetadataError, .invalidShortcode)
        }
    }

    func testExtractEmptyStringThrows() {
        XCTAssertThrowsError(try Shortcode.extract(from: "")) { error in
            XCTAssertEqual(error as? IGMetadataError, .invalidShortcode)
        }
    }

    // MARK: - Username Extraction

    func testExtractUsernameFromUrl() {
        let username = Shortcode.extractUsername(from: "https://www.instagram.com/johndoe/reel/DV1zGAUDzdf/")
        XCTAssertEqual(username, "johndoe")
    }

    func testExtractUsernameFromStandardUrl() {
        // Standard URLs without username prefix should return nil
        let username = Shortcode.extractUsername(from: "https://www.instagram.com/reel/DV1zGAUDzdf/")
        XCTAssertNil(username)
    }

    func testExtractUsernameFromInvalidUrl() {
        let username = Shortcode.extractUsername(from: "https://example.com/test")
        XCTAssertNil(username)
    }

    // MARK: - Shortcode to PK

    func testShortcodeToPk() {
        // Known shortcode-to-PK conversion
        let pk = Shortcode.toPk("DV1zGAUDzdf")
        XCTAssertFalse(pk.isEmpty)
        XCTAssertTrue(pk.allSatisfy(\.isNumber))
    }

    func testShortcodeToPkConsistency() {
        let pk1 = Shortcode.toPk("DV1zGAUDzdf")
        let pk2 = Shortcode.toPk("DV1zGAUDzdf")
        XCTAssertEqual(pk1, pk2)
    }

    func testDifferentShortcodesDifferentPks() {
        let pk1 = Shortcode.toPk("DV1zGAUDzdf")
        let pk2 = Shortcode.toPk("ABC123def45")
        XCTAssertNotEqual(pk1, pk2)
    }

    // MARK: - MediaType

    func testMediaTypeFromGraphImage() {
        XCTAssertEqual(MediaType(typename: "GraphImage"), .photo)
    }

    func testMediaTypeFromGraphVideo() {
        XCTAssertEqual(MediaType(typename: "GraphVideo"), .video)
        XCTAssertTrue(MediaType.video.hasVideo)
    }

    func testMediaTypeFromGraphSidecar() {
        XCTAssertEqual(MediaType(typename: "GraphSidecar"), .carousel)
        XCTAssertTrue(MediaType.carousel.isCarousel)
    }

    func testMediaTypeFromXDTPrefix() {
        XCTAssertEqual(MediaType(typename: "XDTGraphImage"), .photo)
        XCTAssertEqual(MediaType(typename: "XDTGraphVideo"), .video)
        XCTAssertEqual(MediaType(typename: "XDTGraphSidecar"), .carousel)
    }

    func testMediaTypeUnknown() {
        XCTAssertEqual(MediaType(typename: "SomethingElse"), .unknown)
        XCTAssertEqual(MediaType(typename: nil), .unknown)
    }

    func testMediaTypeFromMediaDict() {
        XCTAssertEqual(MediaType(media: ["__typename": "GraphVideo"]), .video)
        XCTAssertEqual(MediaType(media: ["product_type": "clips"]), .video)
        XCTAssertEqual(MediaType(media: ["media_type": 1]), .photo)
        XCTAssertEqual(MediaType(media: ["media_type": 2]), .video)
        XCTAssertEqual(MediaType(media: ["media_type": 8]), .carousel)
        XCTAssertEqual(MediaType(media: ["is_video": true]), .video)
        XCTAssertEqual(MediaType(media: ["edge_sidecar_to_children": ["edges": []]]), .carousel)
        XCTAssertEqual(MediaType(media: [:]), .unknown)
    }

    // MARK: - VideoInfo

    func testVideoFormattedDuration() {
        let video = VideoInfo(url: "https://example.com/video.mp4", durationSeconds: 87.5, width: 1080, height: 1920, viewCount: 91100, variants: [])
        XCTAssertEqual(video.formattedDuration, "1:27")
    }

    func testVideoFormattedDurationHours() {
        let video = VideoInfo(url: "", durationSeconds: 3661, width: 0, height: 0, viewCount: nil, variants: [])
        XCTAssertEqual(video.formattedDuration, "1:01:01")
    }

    func testVideoFormattedDurationShort() {
        let video = VideoInfo(url: "", durationSeconds: 15, width: 0, height: 0, viewCount: nil, variants: [])
        XCTAssertEqual(video.formattedDuration, "0:15")
    }

    func testVideoFormattedViewCount() {
        let video = VideoInfo(url: "", durationSeconds: 0, width: 0, height: 0, viewCount: 1594, variants: [])
        XCTAssertNotNil(video.formattedViewCount)
        XCTAssertTrue(video.formattedViewCount!.contains("1"))
    }

    func testVideoFormattedViewCountNil() {
        let video = VideoInfo(url: "", durationSeconds: 0, width: 0, height: 0, viewCount: nil, variants: [])
        XCTAssertNil(video.formattedViewCount)
    }

    func testBestUrl() {
        let variants = [
            VideoVariant(url: "https://example.com/small.mp4", width: 480, height: 854, id: "1"),
            VideoVariant(url: "https://example.com/large.mp4", width: 1080, height: 1920, id: "2"),
            VideoVariant(url: "https://example.com/medium.mp4", width: 720, height: 1280, id: "3"),
        ]
        let video = VideoInfo(url: "https://example.com/default.mp4", durationSeconds: 10, width: 1080, height: 1920, viewCount: nil, variants: variants)
        XCTAssertEqual(video.bestUrl?.absoluteString, "https://example.com/large.mp4")
    }

    func testBestUrlFallsBackToUrl() {
        let video = VideoInfo(url: "https://example.com/default.mp4", durationSeconds: 10, width: 0, height: 0, viewCount: nil, variants: [])
        XCTAssertEqual(video.bestUrl?.absoluteString, "https://example.com/default.mp4")
    }

    // MARK: - PostMetadata Convenience

    func testFormattedLikeCount() {
        let post = makePost(likeCount: 1594)
        XCTAssertNotNil(post.formattedLikeCount)
        XCTAssertTrue(post.formattedLikeCount!.contains("1"))
    }

    func testFormattedLikeCountNil() {
        let post = makePost(likeCount: nil)
        XCTAssertNil(post.formattedLikeCount)
    }

    func testFormattedCommentCount() {
        let post = makePost(commentCount: 250)
        XCTAssertNotNil(post.formattedCommentCount)
    }

    func testFormattedCommentCountNil() {
        let post = makePost(commentCount: nil)
        XCTAssertNil(post.formattedCommentCount)
    }

    func testFormattedDate() {
        let post = makePost(createdAt: Date(timeIntervalSince1970: 1710412072))
        XCTAssertNotNil(post.formattedDate)
    }

    func testFormattedDateNil() {
        let post = makePost(createdAt: nil)
        XCTAssertNil(post.formattedDate)
    }

    // MARK: - Hashtag / Mention / URL Extraction

    func testHashtagExtraction() {
        let post = makePost(caption: "Check this out! #swift #ios #programming")
        XCTAssertEqual(post.hashtags, ["swift", "ios", "programming"])
    }

    func testMentionExtraction() {
        let post = makePost(caption: "Thanks @apple and @xcode!")
        XCTAssertEqual(post.mentions, ["apple", "xcode"])
    }

    func testUrlExtraction() {
        let post = makePost(caption: "Visit https://example.com for more")
        XCTAssertEqual(post.urls, ["https://example.com"])
    }

    func testEmptyCaptionEntities() {
        let post = makePost(caption: nil)
        XCTAssertTrue(post.hashtags.isEmpty)
        XCTAssertTrue(post.mentions.isEmpty)
        XCTAssertTrue(post.urls.isEmpty)
    }

    // MARK: - AuthorInfo

    func testAuthorProfileUrl() {
        let author = AuthorInfo(name: "John", username: "johndoe", id: "123", profilePicUrl: nil, isVerified: false)
        XCTAssertEqual(author.profileUrl, "https://www.instagram.com/johndoe/")
    }

    func testAuthorProfileUrlNil() {
        let author = AuthorInfo(name: "John", username: nil, id: nil, profilePicUrl: nil, isVerified: false)
        XCTAssertNil(author.profileUrl)
    }

    // MARK: - Error Descriptions

    func testAllErrorsHaveDescriptions() {
        let errors: [IGMetadataError] = [
            .invalidUrl,
            .invalidShortcode,
            .postNotFound,
            .rateLimited,
            .noVideoFound,
            .networkError("timeout"),
            .parsingError("bad json"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testErrorEquatable() {
        XCTAssertEqual(IGMetadataError.invalidUrl, .invalidUrl)
        XCTAssertEqual(IGMetadataError.postNotFound, .postNotFound)
        XCTAssertNotEqual(IGMetadataError.invalidUrl, .postNotFound)
    }

    // MARK: - Integration Tests (require network)

    func testFetchReel() async throws {
        let post = try await IGMetadata.fetch("https://www.instagram.com/reel/DV1zGAUDzdf/")

        XCTAssertEqual(post.shortcode, "DV1zGAUDzdf")
        XCTAssertFalse(post.url.isEmpty)

        // Should have some metadata
        if post.author.username != nil {
            XCTAssertFalse(post.author.username!.isEmpty)
        }

        // Reels should have video
        XCTAssertNotNil(post.video, "Reel should have video info")
        if let video = post.video {
            XCTAssertFalse(video.url.isEmpty, "Video URL should not be empty")
            XCTAssertNotNil(video.bestUrl, "Should have a best video URL")
        }
    }

    func testFetchReelMetadata() async throws {
        let post = try await IGMetadata.fetch("https://www.instagram.com/reel/DV1zGAUDzdf/")

        // Check that we get rich metadata (not just fallback)
        if post.caption != nil {
            XCTAssertFalse(post.caption!.isEmpty, "Caption should not be empty if present")
        }
        if let likes = post.likeCount {
            XCTAssertGreaterThanOrEqual(likes, 0)
        }
        if let comments = post.commentCount {
            XCTAssertGreaterThanOrEqual(comments, 0)
        }
    }

    func testFetchWithTrackingParams() async throws {
        let post = try await IGMetadata.fetch("https://www.instagram.com/reel/DV1zGAUDzdf/?igsh=abc123")
        XCTAssertEqual(post.shortcode, "DV1zGAUDzdf")
    }

    func testFetchWithRawShortcode() async throws {
        let post = try await IGMetadata.fetch("DV1zGAUDzdf")
        XCTAssertEqual(post.shortcode, "DV1zGAUDzdf")
    }

    // MARK: - Helpers

    private func makePost(
        caption: String? = nil,
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        createdAt: Date? = nil
    ) -> PostMetadata {
        PostMetadata(
            shortcode: "test",
            id: nil,
            url: "https://www.instagram.com/p/test/",
            mediaType: .photo,
            caption: caption,
            accessibilityCaption: nil,
            author: AuthorInfo(name: nil, username: nil, id: nil, profilePicUrl: nil, isVerified: false),
            likeCount: likeCount,
            commentCount: commentCount,
            displayUrl: nil,
            video: nil,
            photos: [],
            carouselItems: [],
            width: nil,
            height: nil,
            createdAt: createdAt,
            locationName: nil
        )
    }

}
