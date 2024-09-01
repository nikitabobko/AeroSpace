extension Monitor {
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

    var visibleRectWithoutOuterGaps: Rect {
        return Rect(
            topLeftX: visibleRect.topLeftCorner.x,
            topLeftY: visibleRect.topLeftCorner.y,
            width: visibleRect.width,
            height: visibleRect.height
        )
    }

    var monitorId: Int? {
        let sorted = sortedMonitors
        let origin = self.rect.topLeftCorner
        return sorted.firstIndex { $0.rect.topLeftCorner == origin }
    }
}
