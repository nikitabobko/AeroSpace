import Foundation

struct IntTicker {
    var value: Int

    mutating func incAndGet() -> Int {
        value += 1
        return value
    }
}
