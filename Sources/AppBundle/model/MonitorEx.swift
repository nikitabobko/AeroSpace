extension Monitor {
    @MainActor
    func visibleRectPaddedByOuterGaps(forWorkspace workspaceName: String? = nil) -> Rect {
        let gapsConfig: Gaps
        if let workspaceName, let wsGaps = config.workspaceGaps[workspaceName] {
            gapsConfig = wsGaps
        } else {
            gapsConfig = config.gaps
        }
        let topLeft = visibleRect.topLeftCorner
        let gaps = ResolvedGaps(gaps: gapsConfig, monitor: self)
        return Rect(
            topLeftX: topLeft.x + gaps.outer.left.toDouble(),
            topLeftY: topLeft.y + gaps.outer.top.toDouble(),
            width: visibleRect.width - gaps.outer.left.toDouble() - gaps.outer.right.toDouble(),
            height: visibleRect.height - gaps.outer.top.toDouble() - gaps.outer.bottom.toDouble(),
        )
    }

    var monitorId_oneBased: Int? {
        let sorted = sortedMonitors
        let origin = self.rect.topLeftCorner
        return sorted.firstIndex { $0.rect.topLeftCorner == origin }.map { $0 + 1 }
    }
}
