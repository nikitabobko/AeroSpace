@testable import AppBundle
import Common
import Foundation
import TOMLKit

extension [ConfigParseError] {
    var descriptions: [String] { map(\.description) }
}
