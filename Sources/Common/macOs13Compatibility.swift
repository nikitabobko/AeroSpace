import AppKit
import os

// This file allows to compile against macOS 13 SDK & Xcode 15
extension NSRunningApplication: @unchecked @retroactive Sendable {}
extension OSSignposter: @unchecked @retroactive Sendable {}
