// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if canImport(UIKit)

import Foundation

enum TrackingPixel {
    static let maximumArea = 25.0

    private static let imageTag = try! NSRegularExpression(
        pattern: #"<img\b(?:[^>"']|"[^"]*"|'[^']*')*>"#,
        options: .caseInsensitive
    )

    private static let attribute = try! NSRegularExpression(
        pattern: #"([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?"#
    )

    static func neutralized(_ html: String) -> String {
        var result = html
        let tags = imageTag.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for tag in tags.reversed() {
            guard let range = Range(tag.range, in: html) else { continue }
            let neutral = neutralizedTag(String(html[range]))
            if neutral != html[range] { result.replaceSubrange(range, with: neutral) }
        }
        return result
    }

    private static func neutralizedTag(_ tag: String) -> String {
        let body = NSRange(tag.index(tag.startIndex, offsetBy: 4)..., in: tag)
        var attributes: [String: String] = [:]
        var remoteSources: [NSRange] = []
        for match in attribute.matches(in: tag, range: body) {
            guard let name = text(match, 1, in: tag)?.lowercased(), attributes[name] == nil else { continue }
            let value = (2...4).lazy.compactMap { text(match, $0, in: tag) }.first ?? ""
            attributes[name] = value
            if name == "src" && remote(value) || name == "srcset" && value.split(separator: ",").contains(where: remote) {
                remoteSources.append(match.range)
            }
        }
        guard !remoteSources.isEmpty, isTrackingPixel(attributes) else { return tag }
        var result = tag
        for range in remoteSources.reversed() {
            if let range = Range(range, in: result) { result.removeSubrange(range) }
        }
        return result
    }

    static func isTrackingPixel(_ attributes: [String: String]) -> Bool {
        if let width = attributes["width"].flatMap(pixels),
           let height = attributes["height"].flatMap(pixels),
           width * height <= maximumArea {
            return true
        }
        return (attributes["style"] ?? "")
            .split(separator: ";")
            .contains { declaration in
                let pair = declaration.split(separator: ":", maxSplits: 1)
                guard pair.count == 2 else { return false }
                let value = pair[1].trimmingCharacters(in: .whitespaces).lowercased()
                switch pair[0].trimmingCharacters(in: .whitespaces).lowercased() {
                case "width", "height", "max-width", "max-height":
                    return pixels(value).map { $0 <= 1 } ?? false
                case "display":
                    return value == "none"
                case "visibility":
                    return value == "hidden"
                default:
                    return false
                }
            }
    }

    private static func pixels(_ length: String) -> Double? {
        let length = length.trimmingCharacters(in: .whitespaces)
        let number = length.hasSuffix("px") ? String(length.dropLast(2)) : length
        return Double(number.trimmingCharacters(in: .whitespaces))
    }

    private static func remote<S: StringProtocol>(_ source: S) -> Bool {
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return source.hasPrefix("http://") || source.hasPrefix("https://")
    }

    private static func text(_ match: NSTextCheckingResult, _ group: Int, in string: String) -> String? {
        Range(match.range(at: group), in: string).map { String(string[$0]) }
    }
}

#endif
