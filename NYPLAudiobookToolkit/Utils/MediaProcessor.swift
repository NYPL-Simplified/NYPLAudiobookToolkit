import AVFoundation
import Foundation

let allowableRootAtomTypes: [String] = [
    "ftyp",
    "moov",
    "mdat",
    "stts",
    "stsc",
    "stsz",
    "meta",
    "free",
    "skip",
    "wide",
]

let skippableAtomTypes: [String] = [
    "free",
    "skip",
    "wide",
]

struct QTAtomMetadata {
    var offset: UInt64
    var size: UInt64
    var type: String
    
    var description: String {
        return "Offset: \(offset), Size: \(size), Type: \(type)"
    }
}

class MediaProcessor {
    static func fileNeedsOptimization(url: URL) -> Bool {
        let atoms = getAtomsFor(url: url)
        for atom in atoms {
            ATLog(.debug, atom.description)
        }
        
        if let mdat = atoms.first(where: { $0.type == "mdat" }),
            let moov = atoms.first(where: { $0.type == "moov" }) {
            return mdat.offset < moov.offset
        }
        
        return false
    }
    
    static func optimizeQTFile(input: URL, output: URL, completionHandler: @escaping (Bool)->(Void)) {
        var rootAtoms = getAtomsFor(url: input)
        guard let mdatIndex = rootAtoms.firstIndex(where: { $0.type == "mdat" }),
          let moov = rootAtoms.first(where: { $0.type == "moov" }) else {
            ATLog(.error, "Could not find moov or mdat atoms")
            completionHandler(false)
            return
        }
        
        var finalSuccess = true
        do {
            let fh = try FileHandle(forReadingFrom: input)
            if #available(iOS 13.0, *) {
                try fh.seek(toOffset: moov.offset)
            } else {
                fh.seek(toFileOffset: moov.offset)
            }
            
            var moovData = fh.readData(ofLength: Int(moov.size))
            let success = patchMoovData(data: &moovData, moov: moov)
            if success {
                rootAtoms.append(rootAtoms.remove(at: mdatIndex))
                if !FileManager.default.fileExists(atPath: output.path) {
                    FileManager.default.createFile(atPath: output.path, contents: nil, attributes: nil)
                }
                if let outFh = FileHandle.init(forWritingAtPath: output.path) {
                    for atom in rootAtoms {
                        if atom.type == "moov" {
                            outFh.write(moovData)
                        } else {
                            if #available(iOS 13.0, *) {
                                try fh.seek(toOffset: atom.offset)
                            } else {
                                fh.seek(toFileOffset: atom.offset)
                            }
                            outFh.write(fh.readData(ofLength: Int(atom.size)))
                        }
                    }
                    outFh.closeFile()
                } else {
                    ATLog(.error, "Unable to get file handle for output target \(output.path)")
                    finalSuccess = false
                }
            } else {
                finalSuccess = false
            }
            fh.closeFile()
        } catch {
            ATLog(.error, "Error optimizing file: \(error)")
            finalSuccess = false
        }
        
        completionHandler(finalSuccess)
    }
    
    private static func getAtomsFor(url: URL) -> [QTAtomMetadata] {
        var atoms: [QTAtomMetadata] = []
        guard let fh = try? FileHandle(forReadingFrom: url) else {
            ATLog(.error, "Could not get file handle for \(url.absoluteString)")
            return atoms
        }
        
        while true {
            let offset: UInt64
            if #available(iOS 13.0, *) {
                guard let guardedOffset = try? fh.offset() else {
                    ATLog(.error, "Could not get file offset for \(url.absoluteString)")
                    atoms = []
                    break
                }
                offset = guardedOffset
            } else {
                offset = fh.offsetInFile
            }
            let sizeData = fh.readData(ofLength: 4)
            
            // Success/break condition!
            if sizeData.count == 0 {
                break
            }
            
            var size: UInt64
            do {
                size = UInt64(try sizeData.bigEndianUInt32())
            } catch {
                ATLog(.warn, "Could not read atom size")
                atoms = []
                break
            }
            let type = String(data: fh.readData(ofLength: 4), encoding: .ascii) ?? ""
            if !allowableRootAtomTypes.contains(type) {
                ATLog(.warn, "Found invalid atom type: \(type)")
                atoms = []
                break
            }
            if size == 1 {
                do {
                    size = try fh.readData(ofLength: 8).bigEndianUInt64()
                } catch {
                    ATLog(.warn, "Could not read atom ext size")
                    atoms = []
                    break
                }
            }
            atoms.append(QTAtomMetadata(offset: offset, size: size, type: type))
            if #available(iOS 13.0, *) {
                do {
                    try fh.seek(toOffset: offset + size)
                } catch {
                    ATLog(.error, "Could not seek for \(url.absoluteString)")
                    atoms = []
                    break
                }
            } else {
                fh.seek(toFileOffset: offset + size)
            }
        }
        fh.closeFile()
        return atoms
    }
    
    private static func getAtoms(data: Data, offset: UInt64) -> [QTAtomMetadata] {
        var localOffset: UInt64 = offset + 8
        var atoms: [QTAtomMetadata] = []
        
        while localOffset < data.count {
            var size: UInt64
            do {
                size = try UInt64(data.bigEndianUInt32At(offset: Int(localOffset)))
            } catch {
                print("Could not read atom size")
                atoms = []
                break
            }
            
            let type = String(data: data.subdata(in: Range(Int(localOffset+4)...Int(localOffset+7))), encoding: .ascii) ?? ""
            if size == 1 {
                do {
                    size = try data.bigEndianUInt64At(offset: Int(localOffset+8))
                } catch {
                    print("Could not read atom ext size")
                    atoms = []
                    break
                }
            }
            atoms.append(QTAtomMetadata(offset: localOffset, size: size, type: type))
            localOffset += size
        }
        return atoms
    }
    
    private static func patchMoovData(data: inout Data, moov: QTAtomMetadata) -> Bool {
        let moovChildren = getAtoms(data: data, offset: 0)
        guard let trakAtom = moovChildren.first(where: { $0.type == "trak" }) else {
            ATLog(.warn, "No trak atom found")
            return false
        }
        
        let trakChildren = getAtoms(data: data, offset: trakAtom.offset)
        guard let mdiaAtom = trakChildren.first(where: { $0.type == "mdia" }) else {
            ATLog(.warn, "No mdia atom found")
            return false
        }
        
        let mdiaChildren = getAtoms(data: data, offset: mdiaAtom.offset)
        guard let minfAtom = mdiaChildren.first(where: { $0.type == "minf" }) else {
            ATLog(.warn, "No minf atom found")
            return false
        }
        
        let minfChildren = getAtoms(data: data, offset: minfAtom.offset)
        guard let stblAtom = minfChildren.first(where: { $0.type == "stbl" }) else {
            ATLog(.warn, "No stbl atom found")
            return false
        }
        
        let stblChildren = getAtoms(data: data, offset: stblAtom.offset)
        for c in stblChildren {
            if c.type == "stco" || c.type == "co64" {
                do {
                    try patchChunkOffsetAtom(data: &data, atom: c, moovSize: Int(moov.size))
                } catch {
                    ATLog(.warn, "Error patching chunk offset atom. \(error)")
                    return false
                }
            }
        }
        return true
    }
    
    private static func patchChunkOffsetAtom(data: inout Data, atom: QTAtomMetadata, moovSize: Int) throws {
        let entryCount = try data.bigEndianUInt32At(offset: Int(atom.offset+12))
        let tableOffset = Int(atom.offset + 16)
        let is64 = atom.type == "co64"
        if is64 {
            for i in 0...(Int(entryCount) - 1) {
                let entryOffset = tableOffset + (i * 8)
                var entryVal = try data.bigEndianUInt64At(offset: entryOffset)
                entryVal += UInt64(moovSize)
                entryVal = entryVal.byteSwapped
                data.replaceSubrange(Range(entryOffset...entryOffset+7), with: &entryVal, count: 8)
            }
        } else {
            for i in 0...(Int(entryCount) - 1) {
                let entryOffset = tableOffset + (i * 4)
                var entryVal = try data.bigEndianUInt32At(offset: entryOffset)
                entryVal += UInt32(moovSize)
                entryVal = entryVal.byteSwapped
                data.replaceSubrange(Range(entryOffset...entryOffset+3), with: &entryVal, count: 4)
            }
        }
    }
}
