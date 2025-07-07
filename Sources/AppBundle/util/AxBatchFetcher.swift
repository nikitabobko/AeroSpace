import AppKit
import Common

// Batch fetch multiple AX properties in a single call to reduce round trips
struct AxBatchFetcher {
    struct WindowProperties {
        let title: String?
        let size: CGSize?
        let position: CGPoint?
        let rect: Rect?
        let isFullscreen: Bool?
        let isMinimized: Bool?
        let role: String?
        let subrole: String?
    }
    
    static func fetchWindowProperties(
        _ window: AXUIElement,
        attributes: Set<String> = [
            kAXTitleAttribute as String,
            kAXSizeAttribute as String,
            kAXPositionAttribute as String,
            "AXFullScreen" as String,
            kAXMinimizedAttribute as String,
            kAXRoleAttribute as String,
            kAXSubroleAttribute as String
        ]
    ) -> WindowProperties {
        // Batch fetch all attributes at once
        var values: CFArray?
        let attributesArray = attributes.map { $0 as CFString } as CFArray
        
        // Use AXUIElementCopyMultipleAttributeValues for batch fetching
        let result = AXUIElementCopyMultipleAttributeValues(
            window,
            attributesArray,
            .stopOnError,
            &values
        )
        
        guard result == .success, let values = values as? [AnyObject] else {
            // Fallback to individual fetches if batch fetch fails
            return WindowProperties(
                title: window.get(Ax.titleAttr),
                size: window.get(Ax.sizeAttr),
                position: window.get(Ax.topLeftCornerAttr),
                rect: getRect(window),
                isFullscreen: window.get(Ax.isFullscreenAttr),
                isMinimized: window.get(Ax.minimizedAttr),
                role: window.get(Ax.roleAttr),
                subrole: window.get(Ax.subroleAttr)
            )
        }
        
        // Parse batch results
        let attributesList = Array(attributes)
        var results: [String: Any] = [:]
        for (index, value) in values.enumerated() {
            if index < attributesList.count && !(value is NSNull) {
                results[attributesList[index]] = value
            }
        }
        
        let position = results[kAXPositionAttribute as String] as? CGPoint
        let size = results[kAXSizeAttribute as String] as? CGSize
        
        return WindowProperties(
            title: results[kAXTitleAttribute as String] as? String,
            size: size,
            position: position,
            rect: (position != nil && size != nil) 
                ? Rect(topLeftX: position!.x, topLeftY: position!.y, width: size!.width, height: size!.height)
                : nil,
            isFullscreen: results["AXFullScreen"] as? Bool,
            isMinimized: results[kAXMinimizedAttribute as String] as? Bool,
            role: results[kAXRoleAttribute as String] as? String,
            subrole: results[kAXSubroleAttribute as String] as? String
        )
    }
    
    private static func getRect(_ window: AXUIElement) -> Rect? {
        guard let position = window.get(Ax.topLeftCornerAttr),
              let size = window.get(Ax.sizeAttr) else {
            return nil
        }
        return Rect(topLeftX: position.x, topLeftY: position.y, width: size.width, height: size.height)
    }
}