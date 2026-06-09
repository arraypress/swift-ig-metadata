# Swift IG Metadata

Fetch metadata from Instagram posts, reels, and IGTV without authentication. `IGMetadata` queries Instagram's public GraphQL endpoint — the same approach used by yt-dlp — to retrieve captions, author info, engagement counts, video and photo URLs, and carousel items. No API key, developer account, or login required.

## Features

- 🎯 **No authentication** — uses Instagram's public web API; no API key, login, or developer account
- 🔗 **Flexible input** — accepts reel, post, reels, and IGTV URLs, or a raw shortcode
- 🎬 **Video download URLs** — exposes all available variants plus a `bestUrl` convenience for the highest-quality stream
- 🖼️ **Photos & carousels** — extracts single images and every item of a multi-photo/video carousel
- 👤 **Author details** — username, display name, profile picture, verification status, and profile URL
- 📊 **Engagement metrics** — like and comment counts, with human-readable formatted variants
- 🏷️ **Caption parsing** — derives hashtags, mentions, and URLs directly from the caption
- 📅 **Rich metadata** — media type, creation date, location, dimensions, and accessibility captions
- 🔁 **Resilient fetch pipeline** — falls back from GraphQL to embed-page and direct-page scraping
- 🧱 **Typed errors** — descriptive `IGMetadataError` cases for invalid URLs, rate limiting, and missing posts
- ⚡ **Async/await** — a single `async throws` entry point
- 📦 **Zero dependencies** — pure Foundation, fully `Sendable`

## Requirements

- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 26.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-ig-metadata.git", from: "1.0.0")
]
```

## Usage

### Fetching post metadata

```swift
import IGMetadata

let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")

print(post.caption ?? "No caption")
print(post.author.username ?? "Unknown")
print("Likes: \(post.formattedLikeCount ?? "N/A")")
```

### Downloading video

```swift
let post = try await IGMetadata.fetch("https://www.instagram.com/reel/ABC123/")

if let video = post.video {
    print("Duration: \(video.formattedDuration)")
    if let url = video.bestUrl {
        print("Download: \(url)")
    }
}
```

### Photos and carousels

```swift
let post = try await IGMetadata.fetch("ABC123DEF") // raw shortcode

for photo in post.photos {
    print("\(photo.url) (\(photo.width)x\(photo.height))")
}

for item in post.carouselItems {
    print("\(item.isVideo ? "Video" : "Photo"): \(item.displayUrl)")
}
```

### Caption entities

```swift
let post = try await IGMetadata.fetch(url)

print(post.hashtags) // ["sunset", "photography"]
print(post.mentions) // ["someuser"]
print(post.urls)     // ["https://example.com"]
```

### Error handling

```swift
do {
    let post = try await IGMetadata.fetch(url)
    print(post.shortcode)
} catch let error as IGMetadataError {
    switch error {
    case .invalidUrl, .invalidShortcode:
        print("Could not parse the input")
    case .postNotFound:
        print("Post not found or private")
    case .rateLimited:
        print("Rate limited — try again later")
    case .noVideoFound:
        print("This post has no video")
    case .networkError(let message), .parsingError(let message):
        print("Failed: \(message)")
    }
}
```

## How It Works

`IGMetadata.fetch` resolves the input to a shortcode, then runs a multi-stage pipeline:

1. Establishes a session against Instagram's ruling API to obtain a CSRF token.
2. Queries the GraphQL endpoint (using the same `doc_id` as yt-dlp) for the post data.
3. Falls back to the embed page and then direct page scraping if GraphQL is unavailable.

## Models

| Model | Description |
|-------|-------------|
| `PostMetadata` | Top-level result: shortcode, media type, caption, author, counts, media, dimensions, date, location, plus derived `hashtags` / `mentions` / `urls` and `formatted*` helpers |
| `AuthorInfo` | Username, name, id, profile picture, `isVerified`, and computed `profileUrl` |
| `VideoInfo` | Primary video URL, dimensions, duration, view count, `variants`, `bestUrl`, and formatted helpers |
| `VideoVariant` | A single video rendition: URL, width, height, id, content type |
| `PhotoInfo` | Image URL, dimensions, and accessibility caption |
| `CarouselItem` | A single carousel slide: `isVideo`, display/video URLs, duration, dimensions |
| `MediaType` | `.photo`, `.video`, `.carousel`, `.unknown`, with `hasVideo` / `isCarousel` helpers |
| `IGMetadataError` | Typed errors with `LocalizedError` descriptions |

## Use Cases

- Building download tools for public Instagram media
- Aggregating and archiving post metadata
- Extracting hashtags and mentions for analytics
- Previewing Instagram links inside an app

## Testing

```bash
swift test
```

Tests cover shortcode extraction, URL parsing, and model decoding.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
