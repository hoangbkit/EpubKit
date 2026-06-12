import Foundation

enum EPUBPathResolver {
    static func dirname(_ path: String) -> String {
        let nsPath = path as NSString
        let dir = nsPath.deletingLastPathComponent
        return dir == "." ? "" : dir
    }

    static func resolve(basePath: String, href: String) -> String {
        let hrefWithoutFragment = stripFragment(href)
        let decodedHref = hrefWithoutFragment.removingPercentEncoding ?? hrefWithoutFragment

        let combined: String
        if basePath.isEmpty {
            combined = decodedHref
        } else {
            combined = (basePath as NSString).appendingPathComponent(decodedHref)
        }

        let standardized = URL(fileURLWithPath: "/" + combined).standardizedFileURL.path
        return String(standardized.drop(while: { $0 == "/" }))
    }

    static func stripFragment(_ href: String) -> String {
        href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
    }

    static func canonicalForMatching(_ pathOrHref: String) -> String {
        stripFragment(pathOrHref)
            .removingPercentEncodingOrSelf
            .lowercased()
    }
}

private extension String {
    var removingPercentEncodingOrSelf: String {
        removingPercentEncoding ?? self
    }
}
