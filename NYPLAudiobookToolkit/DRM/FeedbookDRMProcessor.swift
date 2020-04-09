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
        guard let metadata = manifest["metadata"] as? [String: Any] else {
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
        
        // Perform Feedbooks manifest validation
        // TODO: SIMPLY-2502
        
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
