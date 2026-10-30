import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct FileIdMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext,
    ) -> ExprSyntax {
        "MyFileId.init(file: #fileID, line: #line, column: #column, function: #function)"
    }
}

public struct FilePathMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext,
    ) -> ExprSyntax {
        "MyFileId.init(file: #filePath, line: #line, column: #column, function: #function)"
    }
}

@main
struct AeroSpaceMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [FileIdMacro.self, FilePathMacro.self]
}
