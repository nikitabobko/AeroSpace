import MachO

// build-release.sh embeds the section with `ld -sectcreate`
private let buildInfo: [String] = {
    var size: UInt = 0
    guard let data = unsafe getsectiondata(#dsohandle.assumingMemoryBound(to: mach_header_64.self), "__TEXT", "__aero_build", &size) else { return [] }
    return unsafe String(decoding: UnsafeBufferPointer(start: data, count: Int(size)), as: UTF8.self).split(separator: "\n").map(String.init)
}()

public let aeroSpaceAppVersion = buildInfo.getOrNil(atIndex: 0) ?? "0.0.0-SNAPSHOT"
public let gitHash = buildInfo.getOrNil(atIndex: 1) ?? "SNAPSHOT"
public let gitShortHash = buildInfo.getOrNil(atIndex: 2) ?? "SNAPSHOT"
