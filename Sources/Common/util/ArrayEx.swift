extension Array {
    public func transposed<T>() -> [[T]] where Self.Element == [T] {
        if isEmpty {
            return []
        }
        let table: [[T]] = self
        var result: [[T]] = []
        loop: for columnIndex in 0... {
            switch columnIndex < table.first.orDie().count {
                case true: result += [table.map { row in row.getOrNil(atIndex: columnIndex).orDie() }]
                case false: break loop
            }
        }
        return result
    }
}
