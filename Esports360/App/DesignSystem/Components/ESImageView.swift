import SwiftUI
import WebKit

enum E360ImageAsset {
    static let teamPlaceholder = "team_placeholder"
    static let playerPlaceholder = "player_placeholder"
    static let tournamentPlaceholder = "tournament_placeholder"
    static let gamePlaceholder = "game_placeholder"
}

struct ESImageView: View {
    let url: URL?
    let fallbackAsset: String
    var contentMode: ContentMode = .fit
    var fallbackText: String? = nil

    var body: some View {
        Group {
            if let url {
                if url.pathExtension.lowercased() == "svg" || url.absoluteString.lowercased().contains(".svg") {
                    CachedSVGView(remoteURL: url)
                        .aspectRatio(contentMode: contentMode)
                } else {
                    CachedAsyncImage(url: url, contentMode: contentMode, fallback: fallback)
                }
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        ZStack {
            Image(fallbackAsset)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .opacity(fallbackText == nil ? 1 : 0.24)

            if let fallbackText {
                Text(String(fallbackText.prefix(2)).uppercased())
                    .font(E360Font.mono(12, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .minimumScaleFactor(0.65)
            }
        }
    }
}

// MARK: - Cached SVG (loads from disk cache → WKWebView)

private struct CachedSVGView: View {
    let remoteURL: URL
    @State private var resolvedURL: URL?
    @State private var isLoaded = false

    var body: some View {
        Group {
            if let resolvedURL {
                SVGWebView(url: resolvedURL)
                    .opacity(isLoaded ? 1 : 0)
                    .onAppear { withAnimation(.easeIn(duration: 0.15)) { isLoaded = true } }
            } else {
                Color.clear
            }
        }
        .task {
            // Try to get a local cached copy first; fall back to remote URL
            if let localURL = await ImageDiskCache.shared.localURL(for: remoteURL) {
                resolvedURL = localURL
            } else {
                resolvedURL = remoteURL
            }
        }
    }
}

// MARK: - Cached Async Image (checks disk cache before network)

private struct CachedAsyncImage<Fallback: View>: View {
    let url: URL
    let contentMode: ContentMode
    let fallback: Fallback

    @State private var loadedImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            } else if isLoading {
                Color.clear
            } else {
                fallback
            }
        }
        .task {
            // 1. Check disk cache synchronously
            if let data = await ImageDiskCache.shared.cachedData(for: url),
               let image = UIImage(data: data) {
                loadedImage = image
                isLoading = false
                return
            }

            // 2. Download and cache
            if let localURL = await ImageDiskCache.shared.localURL(for: url),
               let data = try? Data(contentsOf: localURL),
               let image = UIImage(data: data) {
                loadedImage = image
            }
            isLoading = false
        }
    }
}

// MARK: - SVG WebView

struct SVGWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if url.isFileURL {
            // Load directly from local disk cache
            uiView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            uiView.load(request)
        }
    }
}
