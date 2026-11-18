extension MonitorInfo {
    @MainActor
    var visibleRectPaddedByOuterGaps: Rect {
        visibleRect.paddedByOuterGaps(self)
    }

    var monitorId_oneBased: Int? {
        let sorted = globalSortedMonitorInfos
        let origin = self.rect.topLeftCorner
        return sorted.firstIndex { $0.rect.topLeftCorner == origin }.map { $0 + 1 }
    }
}

extension Rect {
    @MainActor
    func paddedByOuterGaps(_ monitor: MonitorInfo) -> Rect {
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: monitor)
        return Rect(
            topLeftX: topLeftX + gaps.outer.left.toDouble(),
            topLeftY: topLeftY + gaps.outer.top.toDouble(),
            width: width - gaps.outer.left.toDouble() - gaps.outer.right.toDouble(),
            height: height - gaps.outer.top.toDouble() - gaps.outer.bottom.toDouble(),
        )
    }
}
