@testable import AppBundle
import Common
import Foundation
import TOMLKit

extension [TomlParseError] {
    var descriptions: [String] { map(\.description) }
}
