public typealias Parsed<T> = Result<T, String>
extension String: Error {}

public extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func indexOrPastTheEnd(after i: String.Index) -> String.Index {
        i == endIndex ? endIndex : index(after: i)
    }
}

public extension [[String]] {
    func toPaddingTable(columnSeparator: String = " | ") -> [String] {
        let pads: [Int] = transposed.map { column in column.map { $0.count }.max()! }
        return self.map { (row: [String]) in
            zip(row, pads)
                .map { (elem: String, pad: Int) in
                    elem.padding(toLength: pad, withPad: " ", startingAt: 0)
                }
                .joined(separator: columnSeparator)
        }
    }
}

private extension [[String]] {
    var transposed: [[String]] {
        if isEmpty {
            return []
        }
        let table: [[String]] = self
        var result: [[String]] = []
        for columnIndex in 0... {
            if columnIndex < table.first!.count {
                result += [table.map { row in row[columnIndex] }]
            } else {
                break
            }
        }
        return result
    }
}
