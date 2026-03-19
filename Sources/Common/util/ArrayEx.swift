extension Array {
    public func transposed<T>() -> [[T]] where Self.Element == [T] {
        if isEmpty {
            return []
        }
        let table: [[T]] = self
        var result: [[T]] = []
        for columnIndex in 0... {
            if columnIndex < table.first.orDie().count {
                result += [table.map { row in row.getOrNil(atIndex: columnIndex).orDie() }]
            } else {
                break
            }
        }
        return result
    }
}
