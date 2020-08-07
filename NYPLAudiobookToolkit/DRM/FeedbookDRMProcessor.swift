import CommonCrypto

fileprivate let jwtHeaderObj = [
    "alg" : "HS256",
    "typ" : "JWT"
]

class FeedbookDRMProcessor {
    // Processes the Feedbook manifest and performs any immediate DRM operations we can now
    // Also populates the drmData dictionary with necessary fields for delayed async processing
    // @param manifest the audiobook manifest file
    // @param drmData the audiobook's DRM information dictionary holding relevant information for processing
    // @return true if the DRM processing was successful; false otherwise
    class func processManifest(_ manifest: [String: Any], drmData: inout [String: Any]) -> Bool {
        guard var metadata = manifest["metadata"] as? [String: Any] else {
            ATLog(.info, "[FeedbookDRMProcessor] no metadata in manifest")
            return true
        }
        
        // Perform Feedbooks DRM rights check
        if let feedbooksRights = metadata["http://www.feedbooks.com/audiobooks/rights"] as? [String: Any] {
            if let startDate = DateUtils.parseDate((feedbooksRights["start"] as? String) ?? "") {
                if Date() < startDate {
                    ATLog(.error, "Feedbook DRM rights start date is in the future!")
                    return false
                }
            }
            if let endDate = DateUtils.parseDate((feedbooksRights["end"] as? String) ?? "") {
                if Date() > endDate {
                    ATLog(.error, "Feedbook DRM rights end date is expired!")
                    return false
                }
            }
        }
        
        // Perform Feedbooks DRM license status check
        if let links = manifest["links"] as? [[String: Any]] {
            var href = ""
            var found = false
            for link in links {
                if (link["rel"] as? String) == "license" {
                    if found {
                        ATLog(.warn, "[Feedbook License Status Check] More than one license status link found?! href:\(link["href"] ?? "") type:\(link["type"] ?? "")")
                        continue
                    }
                    found = true
                    href = (link["href"] as? String) ?? ""
                }
            }
            if let licenseCheckUrl = URL(string: href) {
                drmData["licenseCheckUrl"] = licenseCheckUrl
            }
            drmData["status"] = DrmStatus.processing
        }
        
        // Perform Feedbooks signature verification
        guard let signature = metadata.removeValue(forKey: "http://www.feedbooks.com/audiobooks/signature") as? [String:Any],
            let signatureValue = signature["value"] as? String else {
            ATLog(.error, "Feedbook manifest does not contain signature")
            return true
        }
        
        var licenseDocument = manifest
        licenseDocument["metadata"] = metadata

        return verifySignature(signatureValue, forLicenseDoc: licenseDocument)
    }
    
    /**
     Verify the signature within the manifest using the private key from Keychain
     
     - Parameter signatureValue: signature value extracted from the manifest
     - Parameter forLicenseDoc: the manifest(license document) without the signature
     - Returns: Bool representing if the signature is valid
     */
    class private func verifySignature(_ signatureValue: String, forLicenseDoc: [String: Any]) -> Bool {
        guard let privateKeyData = getFeedbookPrivateKeyFromKeychain(forVendor: "cantook") else {
            ATLog(.error, "Private key for Feedbook is not found")
            return false
        }
        
        do {
            let canonicalizedLicense = try JSONUtils.canonicalize(jsonObj: forLicenseDoc)
           
            guard let licenseData = canonicalizedLicense.data(using: .utf8) else {
                ATLog(.error, "Failed to create data from canonicalized license document")
                return false
            }
            
            var error: Unmanaged<CFError>?
            
            let privateSecKeyProperties = [
                kSecAttrKeyType: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate
            ]

            guard let privateSecKey = SecKeyCreateWithData(privateKeyData as NSData,
                                                           privateSecKeyProperties as NSDictionary,
                                                           &error) else {
                ATLog(.error, "Failed to create SecKey from private key - \(error)")
                return false
            }

            guard SecKeyIsAlgorithmSupported(privateSecKey, .sign, SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA256) else {
                ATLog(.error, "Private key does not support algorithm(rsaSignatureDigestPKCS1v15SHA256)")
                return false
            }
            
            let blockSize = SecKeyGetBlockSize(privateSecKey)
            
            guard Int(CC_SHA256_DIGEST_LENGTH) <= blockSize - 11 else {
                ATLog(.error, "Invalid data size, data size cannot be larger or equal to key size - 11 bytes")
                // ref: https://developer.apple.com/documentation/security/1618025-seckeyrawsign
                return false
            }
            
            var digestBytes = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            RSAUtils.SHA256HashedData(from: (licenseData as NSData)).getBytes(&digestBytes, length: Int(CC_SHA256_DIGEST_LENGTH))
            
            var signatureBytes = [UInt8](repeating: 0, count: blockSize)
            var signatureDataLength = blockSize
            
            let status = SecKeyRawSign(privateSecKey,
                                       .PKCS1SHA256,
                                       digestBytes,
                                       digestBytes.count,
                                       &signatureBytes,
                                       &signatureDataLength)
            
            guard status == noErr else {
                ATLog(.error, "Failed to sign data - \(status.description)")
                return false
            }
            
            let signatureData = Data(bytes: signatureBytes, count: signatureBytes.count)
            
            guard signatureData.base64EncodedString() == signatureValue else {
                ATLog(.error, "Signature does not match, DRM check failed")
                return false
            }
            
        } catch {
            ATLog(.error, "Failed to canonicalize license document, \(error)")
            return false
        }
        
        return true
    }
    
    // Performs asynchronous DRM checks that couldn't be performed statically
    // @param book the audiobook
    // @param drmData the book's DRM data dictionary holding relevant info
    class func performAsyncDrm(book: OpenAccessAudiobook, drmData: [String: Any]) {
        if let licenseCheckUrl = drmData["licenseCheckUrl"] as? URL {
            weak var weakBook = book
            URLSession.shared.dataTask(with: licenseCheckUrl) { (data, response, error) in
                // Errors automatically mean success
                // In practice, network errors should not prevent us from playing a book,
                // especially since the point is to be able to listen offline
                if error != nil {
                    weakBook?.drmStatus = .succeeded
                    ATLog(.debug, "feedbooks::performAsyncDrm licenseCheck skip due to error: \(error!)")
                    return
                }
                
                // Explicitly check status value
                if let licenseData = data,
                    let jsonObj = try? JSONSerialization.jsonObject(with: licenseData, options: JSONSerialization.ReadingOptions()) as? [String: Any],
                    let statusString = jsonObj?["status"] as? String {
                    
                    if statusString != "ready" && statusString != "active" {
                        ATLog(.debug, "feedbooks::performAsyncDrm licenseCheck failed: \((try? JSONUtils.canonicalize(jsonObj: jsonObj) as String) ?? "")")
                        weakBook?.drmStatus = .failed
                        return
                    }
                }

                // Fallthrough on all other cases
                weakBook?.drmStatus = .succeeded
                ATLog(.debug, "feedbooks::performAsyncDrm licenseCheck fallthrough")
            }
        } else {
            book.drmStatus = .succeeded
            ATLog(.debug, "feedbooks::performAsyncDrm licenseCheck not needed")
        }
    }
    
    class func getFeedbookSecret(profile: String) -> String {
        let tag = "feedbook_drm_profile_\(profile)"
        let tagData = tag.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecReturnData as String: true
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            if item == nil {
                ATLog(.error, "Keychain item is nil for profile: \(profile)")
            } else if let sItem = item as? String {
                return sItem
            } else if let dItem = item as? Data {
                return String.init(data: dItem, encoding: .utf8) ?? ""
            } else {
                ATLog(.error, "Keychain item unknown error for profile: \(profile)")
            }
        } else {
            ATLog(.error, "Could not fetch keychain item for profile: \(profile)")
        }
        return ""
    }
    
    class private func getFeedbookPrivateKeyFromKeychain(forVendor: String) -> Data? {
        let tag = FeedbookDRMPrivateKeyTag + forVendor
        guard let tagData = tag.data(using: .utf8) else {
            ATLog(.error, "Failed to get Feedbook DRM private key tag data for Keychain access")
            return nil
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: tagData,
            kSecReturnData as String: true
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            if item == nil {
                ATLog(.error, "Keychain item is nil for vendor: \(forVendor)")
            } else if let sItem = item as? String {
                return Data(base64Encoded:sItem)
            } else if let dItem = item as? Data {
                return dItem
            } else {
                ATLog(.error, "Keychain item unknown error for vendor: \(forVendor)")
            }
        } else {
            ATLog(.error, "Could not fetch keychain item for vendor: \(forVendor)")
        }
        return nil
    }
    
    class func getJWTToken(profile: String, resourceUri: String) -> String? {
        let claimsObj = [
            "iss" : "https://librarysimplified.org/products/SimplyE",
            "sub" : resourceUri,
            "jti" : UUID.init().uuidString
        ]
        
        // JWT doesn't explicitly require canonicalization but it makes testing/confirmation easier
        guard let headerJSON = try? JSONUtils.canonicalize(jsonObj: jwtHeaderObj),
            let claimsJSON = try? JSONUtils.canonicalize(jsonObj: claimsObj),
            let header = headerJSON.data(using: .utf8)?.urlSafeBase64(padding: false),
            let claims = claimsJSON.data(using: .utf8)?.urlSafeBase64(padding: false) else {
                
            return nil
        }
        
        let preSigned = "\(header).\(claims)"
        
        let signed = preSigned.hmac(algorithm: .sha256, key: Data.init(base64Encoded: getFeedbookSecret(profile: profile)) ?? Data()).urlSafeBase64(padding: false)
        return "\(header).\(claims).\(signed)"
    }
}
