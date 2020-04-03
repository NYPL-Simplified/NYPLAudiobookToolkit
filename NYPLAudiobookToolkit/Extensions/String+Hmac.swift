import CommonCrypto

extension String {
    func hmac(algorithm: HmacAlgorithm, key: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: algorithm.digestLength)
        if let myData = self.data(using: .utf8) {
            myData.withUnsafeBytes { (selfPtr) -> Void in
                key.withUnsafeBytes { (ptr) -> Void in
                  CCHmac(algorithm.algorithm, ptr, key.count, selfPtr, myData.count, &digest)
                }
            }
        }
        return Data(bytes: digest)
    }
}
