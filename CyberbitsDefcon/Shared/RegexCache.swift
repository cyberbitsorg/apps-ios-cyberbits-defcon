import Foundation

/// Shared thread-safe pattern cache for `NSRegularExpression`. Compile-once,
/// reuse-everywhere — one mechanism for the whole pipeline instead of per-file copies.
extension NSRegularExpression {
    private static var cache: [String: NSRegularExpression] = [:]
    private static let cacheLock = NSLock()

    static func cached(_ pattern: String) -> NSRegularExpression {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let r = cache[pattern] { return r }
        let r = (try? NSRegularExpression(pattern: pattern,
                                          options: [.caseInsensitive, .dotMatchesLineSeparators]))
            ?? NSRegularExpression()
        cache[pattern] = r
        return r
    }
}
