#ifndef AUTORAISE_BRIDGE_H
#define AUTORAISE_BRIDGE_H

// Swift-facing surface for AutoRaiseCore — the ObjC++ port of AutoRaise.
// See openspec change integrate-autoraise (design.md §D3–§D5, §D9).

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>

// Configuration passed from Swift (AutoRaiseController) to the bridge at
// start/reload time. Mirrors the [auto-raise] TOML section — see spec
// requirement "Config schema".
//
// The `disableKey` field carries the CGEventFlags mask for the modifier
// (kCGEventFlagMaskControl, kCGEventFlagMaskAlternate, or 0 to disable).
// Swift maps the TOML string ("control" | "option" | "disabled") to the
// numeric mask before constructing this object.
@interface AutoRaiseBridgeConfig : NSObject
@property (nonatomic, assign) int32_t pollMillis;
@property (nonatomic, assign) int32_t disableKey;
@property (nonatomic, assign) BOOL ignoreSpaceChanged;
@property (nonatomic, assign) BOOL invertDisableKey;
@property (nonatomic, assign) BOOL invertIgnoreApps;
@property (nonatomic, copy) NSArray<NSString *> *ignoreApps;
@property (nonatomic, copy) NSArray<NSString *> *ignoreTitles;
@property (nonatomic, copy) NSArray<NSString *> *stayFocusedBundleIds;
@end
#endif

// Route callback — AutoRaiseCore hands a CGWindowID back to the Swift side,
// which maps it to an AeroSpace Window, enforces the current-workspace rule,
// and calls setFocus(to:). Invoked on the main thread because the CGEventTap
// and raise-retry dispatch_after blocks are both pinned to the main run loop
// (design.md §D3.c — no dispatch hop needed).
typedef void (*AutoRaiseRouteRaise)(uint32_t cgWindowId);

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
// Install the CGEventTap, apply config, and begin observing hover events.
// Idempotent: a second call while already running is a no-op and returns true.
// The bridge auto-appends AssistiveControl to ignoreApps (see upstream
// AutoRaise main()). Returns false iff CGEventTapCreate failed — typically
// because the process lacks Accessibility permission. In that case nothing
// is mutated beyond the config globals (applyConfig still ran).
bool autoraise_start(AutoRaiseBridgeConfig *config);

// Re-apply config without tearing down the tap. Runtime-toggle state
// (started / stopped via the commands) is NOT affected by reload —
// enforced on the Swift controller side.
void autoraise_reload(AutoRaiseBridgeConfig *config);
#endif

// Disable + invalidate the tap, clear the AX observer. Idempotent.
void autoraise_stop(void);

// Called by GlobalObserver when macOS active-space or frontmost-app changes.
// These replace AutoRaise's upstream MDWorkspaceWatcher (see design.md §D6).
void autoraise_on_active_space_did_change(void);
void autoraise_on_app_did_activate(void);

// One-shot: install the raise-routing callback before autoraise_start.
void autoraise_set_route_callback(AutoRaiseRouteRaise cb);

// True once autoraise_start has successfully installed the tap.
bool autoraise_is_running(void);

#ifdef __cplusplus
}
#endif

#endif
