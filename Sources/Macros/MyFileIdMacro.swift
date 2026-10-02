import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct FileIdMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext,
    ) -> ExprSyntax {
        "#fileID"
    }
}

public struct FilePathMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext,
    ) -> ExprSyntax {
        "#filePath"
    }
}

@main
struct AeroSpaceMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [FileIdMacro.self, FilePathMacro.self]
}
