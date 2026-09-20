import AppKit

extension MonitorInfo {
    @MainActor
    var visibleRectPaddedByOuterGaps: Rect {
        let topLeft = visibleRect.topLeftCorner
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: self)
        return Rect(
            topLeftX: topLeft.x + gaps.outer.left.toDouble(),
            topLeftY: topLeft.y + gaps.outer.top.toDouble(),
            width: visibleRect.width - gaps.outer.left.toDouble() - gaps.outer.right.toDouble(),
            height: visibleRect.height - gaps.outer.top.toDouble() - gaps.outer.bottom.toDouble(),
        )
    }

    var monitorId_oneBased: Int? {
        let sorted = sortedMonitorInfos
        let origin = self.rect.topLeftCorner
        return sorted.firstIndex { $0.rect.topLeftCorner == origin }.map { $0 + 1 }
    }
}

extension MonitorInfo {
    func optimalHideCorner(monitors: [MonitorInfo]) -> OptimalHideCorner {
        let xOff = width * 0.1
        let yOff = height * 0.1
        // brc = bottomRightCorner
        let brc1 = rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
        let brc2 = rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
        let brc3 = rect.bottomRightCorner + CGPoint(x: 2, y: 2)

        // blc = bottomLeftCorner
        let blc1 = rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
        let blc2 = rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
        let blc3 = rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

        func contains(_ monitor: MonitorInfo, _ point: CGPoint) -> Int { monitor.rect.contains(point) ? 1 : 0 }
        let important = 10

        return monitors.sumOfInt { contains($0, blc1) + contains($0, blc2) + important * contains($0, blc3) } <
            monitors.sumOfInt { contains($0, brc1) + contains($0, brc2) + important * contains($0, brc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
    }
}
