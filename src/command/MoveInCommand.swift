struct MoveInCommand: Command {
    let direction: CardinalDirection

    func runWithoutRefresh() {
        check(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        guard let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) else { return }
        let moveInTarget = parent.children[ownIndex + direction.focusOffset]
        let prevBinding = moveInTarget.unbindFromParent()
        let newParent = TilingContainer(
            parent: parent,
            adaptiveWeight: prevBinding.adaptiveWeight,
            parent.orientation.opposite,
            .list,
            index: prevBinding.index
        )
        currentWindow.unbindFromParent()

        moveInTarget.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: 0)
        currentWindow.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: direction.isPositive ? 0 : INDEX_BIND_LAST)
    }
}
