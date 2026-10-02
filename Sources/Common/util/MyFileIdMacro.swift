#if DEBUG
    @freestanding(expression)
    public macro myFileId() -> StaticString = #externalMacro(module: "Macros", type: "FilePathMacro")
#else
    @freestanding(expression)
    public macro myFileId() -> StaticString = #externalMacro(module: "Macros", type: "FileIdMacro")
#endif
