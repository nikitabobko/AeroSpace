import Common
import Foundation

extension [AeroObj] {
    @MainActor
    func formatToJson(_ format: [StringInterToken], ignoreRightPaddingVar: Bool) -> Result<
        String, String
    > {
        var list: [[String: Primitive]] = []
        for richObj in self {
            var rawObj: [String: Primitive] = [:]

            // Check if %{all} is in the format
            let returnAllVars = format.contains { $0 == .interVar("all") }

            let expandedFormat =
                returnAllVars
                ? getAvailableInterVars(for: richObj.kind)
                    .filter {
                        $0 != "right-padding"
                        && $0 != "newline"
                        && $0 != "tab"
                    } // Exclude non-data vars
                    .map { StringInterToken.interVar($0) }
                : format

            // Process format normally
            for token in expandedFormat {
                switch token {
                    case .interVar(PlainInterVar.rightPadding.rawValue) where ignoreRightPaddingVar:
                        break
                    case .literal:
                        break // should be spaces
                    case .interVar(let varName):
                        switch varName.expandFormatVar(obj: richObj) {
                            case .success(let expanded): rawObj[varName] = expanded
                            case .failure(let error): return .failure(error)
                        }
                }

            }
            list.append(rawObj)
        }
        return JSONEncoder.aeroSpaceDefault.encodeToString(list).map(Result.success)
            ?? .failure("Can't encode '\(list)' to JSON")
    }
}
