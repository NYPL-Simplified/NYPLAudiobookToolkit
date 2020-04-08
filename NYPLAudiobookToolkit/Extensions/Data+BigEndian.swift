import Foundation

extension Data {
    func bigEndianUInt32() throws -> UInt32 {
        if self.count != 4 {
            throw NSError(domain: "InvalidDataException", code: 0, userInfo: ["message": "[Data::bigEndianUInt32] Data length was \(self.count). Expected 4 bytes."])
        }
        return UInt32(bigEndian: self.withUnsafeBytes({ (ptr) -> UInt32 in
            return ptr.load(as: UInt32.self)
        }))
    }
    
    func bigEndianUInt64() throws -> UInt64 {
        if self.count != 8 {
            throw NSError(domain: "InvalidDataException", code: 0, userInfo: ["message": "[Data::bigEndianUInt64] Data length was \(self.count). Expected 8 bytes."])
        }
        return UInt64(bigEndian: self.withUnsafeBytes({ (ptr) -> UInt64 in
            return ptr.load(as: UInt64.self)
        }))
    }
    
    func bigEndianUInt32At(offset: Int) throws -> UInt32 {
        if offset + 4 > self.count {
            throw NSError(domain: "OutOfBounds", code: 0, userInfo: nil)
        }
        return try self.subdata(in: Range(offset...offset+3)).bigEndianUInt32()
    }
    
    func bigEndianUInt64At(offset: Int) throws -> UInt64 {
        if offset + 8 > self.count {
            throw NSError(domain: "OutOfBounds", code: 0, userInfo: nil)
        }
        return try self.subdata(in: Range(offset...offset+7)).bigEndianUInt64()
    }
}
