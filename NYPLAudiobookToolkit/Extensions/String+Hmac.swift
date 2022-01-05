import Foundation
import CommonCrypto

extension String {
    func hmac(algorithm: HmacAlgorithm, key: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: algorithm.digestLength)
        if let myData = self.data(using: .utf8) {
            myData.withUnsafeBytes { rawSelfPtr in
                guard let selfPtr = rawSelfPtr.baseAddress else {
                    ATLog(.error, "Unable to get baseAddress for HMAC data string")
                    return
                }

                key.withUnsafeBytes { rawPtr in
                    guard let ptr = rawPtr.baseAddress else {
                        ATLog(.error, "Unable to get baseAddress for HMAC key")
                        return
                    }

                    CCHmac(algorithm.algorithm, ptr, key.count, selfPtr, myData.count, &digest)
                }
            }
        }
        return Data(digest)
    }
}
