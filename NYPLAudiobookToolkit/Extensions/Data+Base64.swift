import Foundation

extension Data {
    // Encodes data into URL-safe Base64
    // see RFC4648 Section 5
    // Effectively replaces "+" with "-" and "/" with "_"
    // @param padding flag to determine if the padding is left at the end or not
    // @return a URL-safe Base64 string representation of the data
    func urlSafeBase64(padding: Bool) -> String {
        let s = self.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        return padding ? s : s.replacingOccurrences(of: "=", with: "")
    }
}
