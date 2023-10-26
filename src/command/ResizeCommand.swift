struct ResizeCommand: Command { // todo cover with tests
    enum Dimension: String {
        case width, height, smart
    }

    let dimension: Dimension
    let diff: Int

    func runWithoutRefresh() { // todo support key repeat
        check(Thread.current.isMainThread)
        guard let window = focusedWindowOrEffectivelyFocused else { return }

        switch window.parent.kind {
        case .tilingContainer(let directParent):
            let orientation: Orientation
            let parent: TilingContainer
            switch dimension {
            case .width:
                orientation = .h
                guard let first = window.parents.filterIsInstance(of: TilingContainer.self)
                    .first(where: { $0.orientation == orientation }) else { return }
                parent = first
            case .height:
                orientation = .v
                guard let first = window.parents.filterIsInstance(of: TilingContainer.self)
                    .first(where: { $0.orientation == orientation }) else { return }
                parent = first
            case .smart:
                parent = directParent
                orientation = parent.orientation
            }
            let diff = CGFloat(diff)

            guard let childDiff = diff.div(parent.children.count - 1) else { return }
            parent.children.lazy
                .filter { $0 != window }
                .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

            window.setWeight(orientation, window.getWeight(orientation) + diff)
        case .workspace:
            return // todo support floating windows
        }
    }
}
