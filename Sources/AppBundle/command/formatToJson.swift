import Common
import Foundation

extension [AeroObj] {
    @MainActor
    func formatToJson(_ format: [StringInterToken], ignoreRightPaddingVar: Bool) -> Result<String, String> {
        var list: [[String: Primitive]] = []
        for richObj in self {
            var rawObj: [String: Primitive] = [:]
            for token in format {
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
