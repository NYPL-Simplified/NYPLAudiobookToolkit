extension Data {
    func urlSafeBase64(padding: Bool) -> String {
        let s = self.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        return padding ? s : s.replacingOccurrences(of: "=", with: "")
    }
}
