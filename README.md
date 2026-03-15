# Swift IG Metadata

A Swift library for fetching metadata from Instagram posts. No API key, developer account, or authentication required — uses Instagram's public GraphQL endpoint.

## Features

- 🎯 **Simple API** — fetch post metadata with a single async call
- 📊 **Rich metadata** — caption, author, likes, comments, date, location, hashtags, mentions
- 🎬 **Video info** — duration, view count, direct MP4 download URLs at multiple qualities
- 🖼️ **Photo support** — direct image URLs with dimensions
- 🎠 **Carousel support** — all items from carousel/sidecar posts with individual metadata
- 🔒 **No API key required** — uses public GraphQL, embed, and direct page endpoints
- 🍎 **Cross-platform** — macOS, iOS, tvOS, watchOS
- ⚡ **Async/await** native — built for modern Swift concurrency
- 🛡️ **Typed error handling** — specific errors for every failure case
- 🔗 **Flexible input** — supports all Instagram URL formats and raw shortcodes

## Requirements

- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-ig-metadata.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Choose version requirements

## Usage

### Fetch Post Metadata

```swift
import IGMetadata

let post = try await IGMetadata.fetch("https://www.instagram.com/reel/DV1zGAUDzdf/")

print(post.caption ?? "No caption")
print("\(post.author.name ?? "Unknown") (@\(post.author.username ?? ""))")
print("Likes: \(post.formattedLikeCount ?? "N/A")")
print("Date: \(post.formattedDate ?? "N/A")")
print("Type: \(post.mediaType)")
```

### Video Info

```swift
let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")

if let video = post.video {
    print("Duration: \(video.formattedDuration)")
    print("Views: \(video.formattedViewCount ?? "N/A")")

    // Direct MP4 download (best quality) — use this for downloading/transcribing
    if let mp4Url = video.bestUrl {
        print("Download: \(mp4Url)")
    }

    // All available variants
    for variant in video.variants {
        print("\(variant.width)x\(variant.height) — \(variant.url)")
    }
}
```

### Photos

```swift
let post = try await IGMetadata.fetch("https://www.instagram.com/p/ABC123/")

for photo in post.photos {
    print("\(photo.url) (\(photo.width)x\(photo.height))")
}
```

### Carousel Posts

```swift
let post = try await IGMetadata.fetch("https://www.instagram.com/p/ABC123/")

for item in post.carouselItems {
    if item.isVideo {
        print("Video: \(item.videoUrl ?? "N/A") (\(item.width)x\(item.height))")
    } else {
        print("Photo: \(item.displayUrl) (\(item.width)x\(item.height))")
    }
}
```

### Post Entities

```swift
let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")

print("Hashtags: \(post.hashtags)")    // ["swift", "ios"]
print("Mentions: \(post.mentions)")    // ["apple", "xcode"]
print("URLs: \(post.urls)")            // ["https://example.com"]
```

### URL Formats

All common Instagram URL formats are supported:

```swift
// Reel
let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")

// Post
let post = try await IGMetadata.fetch("https://www.instagram.com/p/ABC123/")

// Reels (plural)
let post = try await IGMetadata.fetch("https://www.instagram.com/reels/ABC123/")

// TV/IGTV
let post = try await IGMetadata.fetch("https://www.instagram.com/tv/ABC123/")

// With tracking parameters (stripped automatically)
let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/?igsh=abc123")

// Raw shortcode
let post = try await IGMetadata.fetch("DV1zGAUDzdf")
```

### Error Handling

```swift
do {
    let post = try await IGMetadata.fetch(url)
    print(post.caption ?? "No caption")
} catch IGMetadataError.postNotFound {
    print("Post doesn't exist or is private")
} catch IGMetadataError.rateLimited {
    print("Too many requests — try again later")
} catch IGMetadataError.invalidShortcode {
    print("Couldn't extract a shortcode from the URL")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Models

### `PostMetadata`

The main result struct containing all post data.

| Property | Type | Description |
|----------|------|-------------|
| `shortcode` | `String` | The shortcode from the URL |
| `id` | `String?` | Numeric media ID |
| `url` | `String` | Full post URL |
| `mediaType` | `MediaType` | `.photo`, `.video`, `.carousel`, or `.unknown` |
| `caption` | `String?` | Post caption text |
| `accessibilityCaption` | `String?` | AI-generated alt text |
| `author` | `AuthorInfo` | Author details |
| `likeCount` | `Int?` | Number of likes |
| `commentCount` | `Int?` | Number of comments |
| `video` | `VideoInfo?` | Video metadata (if video/reel) |
| `photos` | `[PhotoInfo]` | Photo URLs with dimensions |
| `carouselItems` | `[CarouselItem]` | Carousel items (if sidecar) |
| `width` | `Int?` | Primary display width |
| `height` | `Int?` | Primary display height |
| `createdAt` | `Date?` | Creation date |
| `locationName` | `String?` | Tagged location name |
| `hashtags` | `[String]` | Hashtags from caption |
| `mentions` | `[String]` | Mentions from caption |
| `urls` | `[String]` | URLs from caption |
| `formattedLikeCount` | `String?` | Likes with grouping separators |
| `formattedCommentCount` | `String?` | Comments with grouping separators |
| `formattedDate` | `String?` | Readable date string |

### `VideoInfo`

Video-specific metadata (only present for video/reel posts).

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Direct video URL |
| `durationSeconds` | `Double` | Duration in seconds |
| `formattedDuration` | `String` | Duration as `"M:SS"` or `"H:MM:SS"` |
| `width` | `Int` | Video width in pixels |
| `height` | `Int` | Video height in pixels |
| `viewCount` | `Int?` | Number of views |
| `formattedViewCount` | `String?` | Views with grouping separators |
| `variants` | `[VideoVariant]` | Available quality variants |
| `bestUrl` | `URL?` | Highest-quality direct download URL |

### `VideoVariant`

A single video quality variant.

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Direct URL to this variant |
| `width` | `Int` | Width in pixels |
| `height` | `Int` | Height in pixels |
| `id` | `String?` | Variant identifier |

### `PhotoInfo`

A photo from a post.

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Direct image URL |
| `width` | `Int` | Width in pixels |
| `height` | `Int` | Height in pixels |
| `accessibilityCaption` | `String?` | AI-generated alt text |

### `CarouselItem`

A single item in a carousel/sidecar post.

| Property | Type | Description |
|----------|------|-------------|
| `isVideo` | `Bool` | Whether this item is a video |
| `displayUrl` | `String` | Display URL (photo or video thumbnail) |
| `videoUrl` | `String?` | Video URL (if video) |
| `videoDuration` | `Double?` | Video duration (if video) |
| `width` | `Int` | Width in pixels |
| `height` | `Int` | Height in pixels |
| `accessibilityCaption` | `String?` | AI-generated alt text |

### `AuthorInfo`

Information about the post's author.

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String?` | Display name |
| `username` | `String?` | Handle (without @) |
| `id` | `String?` | Numeric user ID |
| `profilePicUrl` | `String?` | Profile picture URL |
| `isVerified` | `Bool` | Verification status |
| `profileUrl` | `String?` | Profile page URL |

## How It Works

The library mirrors yt-dlp's Instagram extraction approach:

1. **Session setup** (`i.instagram.com/api/v1/web/get_ruling_for_content`) — establishes a session and obtains a CSRF token via cookies. No auth needed.
2. **GraphQL query** (`instagram.com/graphql/query`) — fetches comprehensive post data using doc_id `8845758582119845` with the CSRF token. Returns caption, author, engagement, dimensions, video URLs, carousel items, and more.
3. **Embed fallback** (`instagram.com/reel/ABC/embed/`) — scrapes the embed page for video/photo URLs when GraphQL fails.
4. **Direct page fallback** (`instagram.com/reel/ABC/`) — scrapes og:video and og:image meta tags as a last resort.

For most posts, only the first two requests are made (session setup + GraphQL). Fallbacks are only used if GraphQL returns an error.

## Limitations

- **Rate limiting** — Instagram may rate-limit requests from IPs making too many calls. Reduce frequency if you encounter `rateLimited` errors.
- **Private posts** — Private posts are not accessible without authentication.
- **Login wall** — Instagram may occasionally require login for certain content. The session setup step helps mitigate this.
- **Endpoint stability** — These are unofficial endpoints that Instagram may change at any time. Updates will be provided as needed.

## Testing

```bash
swift test
```

The test suite includes unit tests for shortcode extraction, formatting, and error handling, plus integration tests that hit Instagram's live endpoints.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
