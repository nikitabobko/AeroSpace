// This file exists purely because xcode doesn't like header only targets, SPM is fine with them
#import "private.h"
#import <Carbon/Carbon.h> // GetProcessForPID, ProcessSerialNumber
#import <string.h>        // memcpy, memset

// Private SkyLight (WindowServer) symbols. Same key-window sequence used by yabai and Amethyst.
// https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
extern CGError _SLPSSetFrontProcessWithOptions(ProcessSerialNumber *psn, uint32_t wid, uint32_t mode);
extern CGError SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);

void aeroMakeKeyWindow(pid_t pid, uint32_t wid) {
    ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations" // GetProcessForPID is the documented way to obtain a PSN
    if (GetProcessForPID(pid, &psn) != noErr) { return; }
#pragma clang diagnostic pop

    // 0x200 == kCPSUserGenerated: mark the activation as user-initiated.
    _SLPSSetFrontProcessWithOptions(&psn, wid, 0x200);

    // Two synthesized WindowServer key-window events; they differ only in byte 0x08 (0x01 then 0x02).
    uint8_t bytes[0xf8] = {0};
    bytes[0x04] = 0xf8;
    bytes[0x3a] = 0x10;
    memcpy(bytes + 0x3c, &wid, sizeof(uint32_t));
    memset(bytes + 0x20, 0xff, 0x10);
    bytes[0x08] = 0x01;
    SLPSPostEventRecordTo(&psn, bytes);
    bytes[0x08] = 0x02;
    SLPSPostEventRecordTo(&psn, bytes);
}
