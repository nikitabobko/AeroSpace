import AppKit
import IOKit
import Common

private let kIODisplayMatchingInfo: UInt32 = 0

struct MonitorFingerprint: Equatable, Hashable, Codable {
    let vendorID: UInt32?
    let modelID: UInt32?
    let serialNumber: String?
    let displayName: String?
    let widthPixels: Int?
    let heightPixels: Int?
    
    init(
        vendorID: UInt32? = nil,
        modelID: UInt32? = nil,
        serialNumber: String? = nil,
        displayName: String? = nil,
        widthPixels: Int? = nil,
        heightPixels: Int? = nil
    ) {
        self.vendorID = vendorID
        self.modelID = modelID
        self.serialNumber = serialNumber
        self.displayName = displayName
        self.widthPixels = widthPixels
        self.heightPixels = heightPixels
    }
    
    static func fromScreen(_ screen: NSScreen) -> MonitorFingerprint? {
        guard let displayID = screen.displayID else { return nil }
        
        var vendorID: UInt32?
        var modelID: UInt32?
        var serialNumber: String?
        
        var servicePort: io_object_t = 0
        if CGDisplayGetDisplayIDForService(displayID, &servicePort) == CGError.success && servicePort != 0 {
            defer { IOObjectRelease(servicePort) }
            
            if let vendorIDCF = IORegistryEntryCreateCFProperty(servicePort, "DisplayVendorID" as CFString, kCFAllocatorDefault, 0) {
                vendorID = (vendorIDCF.takeRetainedValue() as? NSNumber)?.uint32Value
            }
            
            if let modelIDCF = IORegistryEntryCreateCFProperty(servicePort, "DisplayProductID" as CFString, kCFAllocatorDefault, 0) {
                modelID = (modelIDCF.takeRetainedValue() as? NSNumber)?.uint32Value
            }
            
            if let serialNumberCF = IORegistryEntryCreateCFProperty(servicePort, "DisplaySerialNumber" as CFString, kCFAllocatorDefault, 0) {
                if let serialData = serialNumberCF.takeRetainedValue() as? Data {
                    serialNumber = String(data: serialData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let serialNum = serialNumberCF.takeRetainedValue() as? NSNumber {
                    serialNumber = String(serialNum.uint32Value)
                }
            }
        }
        
        let displayName = screen.localizedName
        let widthPixels = Int(screen.frame.width * (screen.backingScaleFactor))
        let heightPixels = Int(screen.frame.height * (screen.backingScaleFactor))
        
        return MonitorFingerprint(
            vendorID: vendorID,
            modelID: modelID,
            serialNumber: serialNumber,
            displayName: displayName,
            widthPixels: widthPixels,
            heightPixels: heightPixels
        )
    }
    
    func matches(pattern: MonitorFingerprintPattern) -> Bool {
        if let patternVendorID = pattern.vendorID, vendorID != patternVendorID {
            return false
        }
        if let patternModelID = pattern.modelID, modelID != patternModelID {
            return false
        }
        if let patternSerial = pattern.serialNumber, serialNumber != patternSerial {
            return false
        }
        if let patternDisplayName = pattern.displayNameRegex {
            guard let displayName = displayName else { return false }
            return displayName.contains(patternDisplayName.val)
        }
        if let patternWidth = pattern.widthPixels, widthPixels != patternWidth {
            return false
        }
        if let patternHeight = pattern.heightPixels, heightPixels != patternHeight {
            return false
        }
        return true
    }
    
    func matches(patternData: MonitorFingerprintPatternData) -> Bool {
        if let patternVendorID = patternData.vendorID, vendorID != patternVendorID {
            return false
        }
        if let patternModelID = patternData.modelID, modelID != patternModelID {
            return false
        }
        if let patternSerial = patternData.serialNumber, serialNumber != patternSerial {
            return false
        }
        if let patternDisplayName = patternData.displayNamePattern {
            guard let displayName = displayName else { return false }
            if let regex = try? SendableRegex(patternDisplayName) {
                return displayName.contains(regex.val)
            }
            return displayName.localizedCaseInsensitiveContains(patternDisplayName)
        }
        if let patternWidth = patternData.widthPixels, widthPixels != patternWidth {
            return false
        }
        if let patternHeight = patternData.heightPixels, heightPixels != patternHeight {
            return false
        }
        return true
    }
    
    var description: String {
        var parts: [String] = []
        if let vendorID = vendorID {
            parts.append("vendor:\(String(format: "0x%04X", vendorID))")
        }
        if let modelID = modelID {
            parts.append("model:\(String(format: "0x%04X", modelID))")
        }
        if let serialNumber = serialNumber, !serialNumber.isEmpty {
            parts.append("serial:\(serialNumber)")
        }
        if let displayName = displayName {
            parts.append("name:\(displayName)")
        }
        if let widthPixels = widthPixels, let heightPixels = heightPixels {
            parts.append("resolution:\(widthPixels)x\(heightPixels)")
        }
        return parts.joined(separator: " ")
    }
}

struct MonitorFingerprintPattern: Equatable, Sendable {
    let vendorID: UInt32?
    let modelID: UInt32?
    let serialNumber: String?
    let displayNameRegex: SendableRegex<AnyRegexOutput>?
    let widthPixels: Int?
    let heightPixels: Int?
    
    init(
        vendorID: UInt32? = nil,
        modelID: UInt32? = nil,
        serialNumber: String? = nil,
        displayNameRegex: SendableRegex<AnyRegexOutput>? = nil,
        widthPixels: Int? = nil,
        heightPixels: Int? = nil
    ) {
        self.vendorID = vendorID
        self.modelID = modelID
        self.serialNumber = serialNumber
        self.displayNameRegex = displayNameRegex
        self.widthPixels = widthPixels
        self.heightPixels = heightPixels
    }
    
    static func == (lhs: MonitorFingerprintPattern, rhs: MonitorFingerprintPattern) -> Bool {
        return lhs.vendorID == rhs.vendorID &&
               lhs.modelID == rhs.modelID &&
               lhs.serialNumber == rhs.serialNumber &&
               lhs.widthPixels == rhs.widthPixels &&
               lhs.heightPixels == rhs.heightPixels
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = self.deviceDescription[key] as? NSNumber else { return nil }
        return displayID.uint32Value
    }
}

private func CGDisplayGetDisplayIDForService(_ displayID: CGDirectDisplayID, _ service: inout io_object_t) -> CGError {
    var iter: io_iterator_t = 0
    let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iter)
    guard result == KERN_SUCCESS else { return CGError(rawValue: Int32(result))! }
    defer { IOObjectRelease(iter) }
    
    var serviceObject: io_object_t = IOIteratorNext(iter)
    while serviceObject != 0 {
        defer { IOObjectRelease(serviceObject) }
        
        let infoUnmanaged = IODisplayCreateInfoDictionary(serviceObject, IOOptionBits(kIODisplayMatchingInfo))
        guard let info = infoUnmanaged?.takeRetainedValue() as NSDictionary? else {
            serviceObject = IOIteratorNext(iter)
            continue
        }
        
        if let productID = info["DisplayProductID"] as? NSNumber,
           let vendorID = info["DisplayVendorID"] as? NSNumber {
            let testDisplayID = CGDisplayVendorNumber(displayID) << 16 | CGDisplayModelNumber(displayID)
            let dictDisplayID = vendorID.uint32Value << 16 | productID.uint32Value
            
            if testDisplayID == dictDisplayID {
                service = serviceObject
                IOObjectRetain(serviceObject)
                return CGError.success
            }
        }
        
        serviceObject = IOIteratorNext(iter)
    }
    
    return CGError(rawValue: 1)!
}