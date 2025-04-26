extension Monitor {
    @MainActor
    var visibleRectPaddedByOuterGaps: Rect {
        let topLeft = visibleRect.topLeftCorner
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: self)
        return Rect(
            topLeftX: topLeft.x + gaps.outer.left.toDouble(),
            topLeftY: topLeft.y + gaps.outer.top.toDouble(),
            width: visibleRect.width - gaps.outer.left.toDouble() - gaps.outer.right.toDouble(),
            height: visibleRect.height - gaps.outer.top.toDouble() - gaps.outer.bottom.toDouble()
        )
    }

    /// todo make 1-based
    /// 0-based index
    var monitorId: Int? {
        let sorted = sortedMonitors
        let origin = self.rect.topLeftCorner
        return sorted.firstIndex { $0.rect.topLeftCorner == origin }
    }
}
