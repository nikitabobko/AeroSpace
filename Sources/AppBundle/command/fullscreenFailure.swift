@MainActor
func shouldFailBecauseFullscreen(
    window: Window,
    failIfFullscreen: Bool,
    failIfMacosNativeFullscreen: Bool,
) async throws -> Bool {
    if failIfFullscreen && window.isFullscreen {
        return true
    }
    if failIfMacosNativeFullscreen {
        if try await window.isMacosFullscreen {
            return true
        }
    }
    return false
}
