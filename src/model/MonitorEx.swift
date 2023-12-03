extension Monitor {
    var rectWithGaps: Rect {
        let topLeft = visibleRect.topLeftCorner
        return Rect(
            topLeftX: topLeft.x + config.gaps.outer.left.toDouble(),
            topLeftY: topLeft.y + config.gaps.outer.top.toDouble(),
            width: visibleRect.width - config.gaps.outer.left.toDouble() - config.gaps.outer.right.toDouble(),
            height: visibleRect.height - config.gaps.outer.top.toDouble() - config.gaps.outer.bottom.toDouble()
        )
    }
}
