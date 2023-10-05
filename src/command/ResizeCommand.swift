struct ResizeCommand: Command { // todo cover with tests
    enum Dimension {
        case width, height, smart
    }

    let dimension: Dimension
    let units: CGFloat

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let window = focusedWindowOrEffectivelyFocused else { return }

        let orientation: Orientation
        switch dimension {
        case .width:
             orientation = .H
        case .height:
            orientation = .V
        case .smart:
            // todo
            //orientation = window.parent
            orientation = .H
            break
        }

        window.setWeight(orientation, window.getWeight(orientation) + units)
    }
}
