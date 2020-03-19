class JSONUtils {
    enum JSONCanonicalizatoinError: Error {
        case canonicalizationError(String)
    }
    static let hexArray = [
        "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "0A", "0B", "0C", "0D", "0E", "0F",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "1A", "1B", "1C", "1D", "1E", "1F"
    ]
    class func canonicalize(jsonObj: Any?) throws -> String {
        return try canonicalizeInternal(jsonObj: jsonObj)
    }
    
    private class func canonicalizeInternal(jsonObj: Any?) throws -> String {
        var rVal = ""
        if jsonObj == nil {
            rVal = "null"
        } else if let b = jsonObj as? Bool {
            rVal = b ? "true" : "false"
        } else if let s = jsonObj as? String {
            var outputStr = String()
            for c in s {
                if c == "\\" {
                    outputStr += "\\\\"
                } else if c == "\"" {
                    outputStr += "\\\""
                } else if c >= "\u{0000}" && c <= "\u{001F}" {
                    outputStr += "\\u00\(hexArray[Int(c.asciiValue!)])"
                } else {
                    outputStr.append(c)
                }
            }
            rVal = "\"\(s)\""
        } else if let n = jsonObj as? Int {
            rVal = String(n)
        } else if let d = jsonObj as? NSNumber {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            guard let formattedDecimal = formatter.string(from: d) else {
                throw JSONCanonicalizatoinError.canonicalizationError("Could not format decimal value")
            }
            rVal = formattedDecimal
        } else if let arr = jsonObj as? [Any?] {
            var arrStr = "["
            var arrFirst = true
            for x in arr {
                if !arrFirst {
                    arrStr += ","
                }
                arrStr += try canonicalizeInternal(jsonObj: x)
                arrFirst = false
            }
            arrStr += "]"
            rVal = arrStr
        } else if let obj = jsonObj as? [String: Any?] {
            let keys = obj.keys.sorted()
            var objFirst = true
            var objStr = "{"
            for k in keys {
                if !objFirst {
                    objStr += ","
                }
                objStr += "\"\(k)\":"
                objStr += try canonicalizeInternal(jsonObj: obj[k] as Any?)
                objFirst = false
            }
            objStr += "}"
            rVal = objStr
        } else {
            throw JSONCanonicalizatoinError.canonicalizationError("Value of unecpected type")
        }
        return rVal
    }
}
