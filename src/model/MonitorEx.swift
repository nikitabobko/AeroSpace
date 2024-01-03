import AppKit

extension Monitor {
    var visibleRectPaddedByOuterGaps: Rect {
        // When the system menu bar is visible, add gap to the visible area, otherwise add it to the top of the screen.
        let visibleAreaTopOffset = visibleRect.topLeftY - rect.topLeftY
        let adjustedTopOffset = (NSMenu.menuBarVisible() ? visibleAreaTopOffset : 0.0) + config.gaps.outer.top.toDouble()
        let visibleAreaBottomOffset = rect.bottomLeftCorner.y - visibleRect.bottomLeftCorner.y
        let height = rect.height - visibleAreaBottomOffset - adjustedTopOffset - config.gaps.outer.bottom.toDouble()

        return Rect(
            topLeftX: visibleRect.topLeftX + config.gaps.outer.left.toDouble(),
            topLeftY: rect.topLeftY + adjustedTopOffset,
            width: visibleRect.width - config.gaps.outer.left.toDouble() - config.gaps.outer.right.toDouble(),
            height: height
        )
    }
}
