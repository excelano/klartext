// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if canImport(UIKit)

import Foundation

public struct EmailLink: Sendable, Hashable {
    public let url: URL
    public let text: String

    public init(url: URL, text: String) {
        self.url = url
        self.text = text
    }
}

#endif
