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

    /// Whether another monitor intersects the infinite strip that extends rightwards from this monitor's physical
    /// right edge, within this monitor's vertical band.
    ///
    /// The scrolling layout's peek page is the only page that is allowed to overflow the workspace rect on purpose.
    /// A window manager sets AX frames, it cannot clip, so that overflow is real pixels. The check is deliberately
    /// conservative: distance doesn't make a right hand side monitor safe, because apps may refuse the requested
    /// width and end up much wider than the peek reserves. Overflowing into this monitor's own outer gap is fine,
    /// that's why the physical ``rect`` is used rather than ``visibleRect``.
    func hasMonitorInRightSpillBand(monitors: [MonitorInfo]) -> Bool {
        let ownRect = rect
        return monitors.contains { monitor in
            let otherRect = monitor.rect
            // MonitorInfo isn't Equatable. Identify self by origin, same as optimalHideCorner does
            guard otherRect.topLeftCorner != ownRect.topLeftCorner else { return false }
            return max(ownRect.maxX, otherRect.minX) < otherRect.maxX
                && max(ownRect.minY, otherRect.minY) < min(ownRect.maxY, otherRect.maxY)
        }
    }
}
