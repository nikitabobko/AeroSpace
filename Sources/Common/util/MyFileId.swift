public struct MyFileId {
    public var file: StaticString
    public var line: UInt
    public var column: Int
    public var function: String

    // periphery:ignore - used by macros
    public init(file: StaticString, line: UInt, column: Int, function: String) {
        self.file = file
        self.line = line
        self.column = column
        self.function = function
    }
}

#if DEBUG
    @freestanding(expression)
    public macro myFileId() -> MyFileId = #externalMacro(module: "Macros", type: "FilePathMacro")
#else
    @freestanding(expression)
    public macro myFileId() -> MyFileId = #externalMacro(module: "Macros", type: "FileIdMacro")
#endif
