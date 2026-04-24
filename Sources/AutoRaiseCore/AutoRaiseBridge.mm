// AutoRaiseBridge.mm — Swift-facing surface for AutoRaiseCore.
// See openspec change integrate-autoraise (design.md §D3–§D5, §D9).
//
// Licensed under GPL-2.0-or-later (same as AutoRaise.mm). The combined
// AeroSpace binary is distributed under GPL-2.0-or-later because AutoRaise's
// copyleft propagates once linked.

#import "AutoRaiseBridge.h"

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>

// Externs into AutoRaise.mm globals (see §D3 "globals stay globals"). The
// bridge is the sole writer for the config-owned fields and resets the
// runtime-state fields on start.
extern "C" {
    extern CFMachPortRef eventTap;
    extern AXObserverRef axObserver;
    extern AXUIElementRef _dock_app;
    extern uint64_t lastDestroyedMouseWindow_id;
    extern NSArray * ignoreApps;
    extern NSArray * ignoreTitles;
    extern NSArray * stayFocusedBundleIds;
    extern CGPoint desktopOrigin;
    extern CGPoint oldPoint;
    extern bool ignoreSpaceChanged;
    extern bool invertDisableKey;
    extern bool invertIgnoreApps;
    extern int pollMillis;
    extern int disableKey;
    extern double lastCheckTime;
    extern double suppressRaisesUntil;
    extern uint64_t raiseGeneration;
}

// Functions defined in AutoRaise.mm. External linkage by default (the port
// has no `static` qualifier on any of these).
extern void findDockApplication(void);
extern void findDesktopOrigin(void);
extern void spaceChanged(void);
extern void appActivated(void);
extern CGEventRef eventTapHandler(CGEventTapProxy proxy, CGEventType type,
                                  CGEventRef event, void *userInfo);

// Route callback storage. Declared extern in AutoRaise.mm; the bridge owns
// the definition.
AutoRaiseRouteRaise routeRaise = NULL;

// Tap-installation state. The tap itself lives in AutoRaise.mm's `eventTap`
// global so eventTapHandler can re-enable it under kCGEventTapDisabledBy*.
static CFRunLoopSourceRef eventTapRunLoopSource = NULL;
static BOOL bridgeRunning = NO;

//-------------------------------------------AutoRaiseBridgeConfig------------------------------------------------

@implementation AutoRaiseBridgeConfig
- (instancetype)init {
    if ((self = [super init])) {
        _ignoreApps = @[];
        _ignoreTitles = @[];
        _stayFocusedBundleIds = @[];
    }
    return self;
}
@end

//------------------------------------------bridge internals------------------------------------------------

// Apply config to AutoRaise.mm globals. Used by both start and reload.
// Appends AssistiveControl to ignoreApps (design.md §D3.d — upstream
// AutoRaise main() does the same).
static void applyConfig(AutoRaiseBridgeConfig *config) {
    pollMillis = config.pollMillis;
    disableKey = config.disableKey;
    ignoreSpaceChanged = config.ignoreSpaceChanged;
    invertDisableKey = config.invertDisableKey;
    invertIgnoreApps = config.invertIgnoreApps;

    NSMutableArray<NSString *> *apps = [config.ignoreApps mutableCopy];
    if (![apps containsObject: @"AssistiveControl"]) {
        [apps addObject: @"AssistiveControl"];
    }
    ignoreApps = [apps copy];
    ignoreTitles = [config.ignoreTitles copy];
    stayFocusedBundleIds = [config.stayFocusedBundleIds copy];
}

// Reset runtime-state fields so a restart starts from a clean slate.
// Does NOT reset config fields — those are owned by applyConfig.
static void resetRuntimeState(void) {
    lastCheckTime = 0;
    suppressRaisesUntil = 0;
    raiseGeneration = 0;
    oldPoint = CGPointMake(0, 0);
    lastDestroyedMouseWindow_id = kCGNullWindowID;
    desktopOrigin = CGPointMake(0, 0);
}

//------------------------------------------public C API----------------------------------------------------

void autoraise_set_route_callback(AutoRaiseRouteRaise cb) {
    routeRaise = cb;
}

bool autoraise_is_running(void) {
    return bridgeRunning ? true : false;
}

bool autoraise_start(AutoRaiseBridgeConfig *config) {
    if (bridgeRunning) { return true; }

    applyConfig(config);
    resetRuntimeState();
    findDockApplication();
    findDesktopOrigin();

    // Install the tap on the MAIN run loop — design.md §D3.c. Everything
    // downstream (raiseAndActivate → routeRaise → Swift @MainActor) can then
    // run synchronously without a dispatch hop.
    CGEventMask mask = CGEventMaskBit(kCGEventMouseMoved);
    eventTap = CGEventTapCreate(
        kCGHIDEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionListenOnly,
        mask,
        eventTapHandler,
        NULL
    );
    if (eventTap == NULL) {
        // Tap creation failed — typically Accessibility permission not granted
        // yet. Leave bridgeRunning false; Swift side surfaces the failure via
        // the return value so the enable-auto-raise command can report it.
        return false;
    }

    eventTapRunLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(
        CFRunLoopGetMain(),
        eventTapRunLoopSource,
        kCFRunLoopCommonModes
    );
    CGEventTapEnable(eventTap, true);

    bridgeRunning = YES;
    return true;
}

void autoraise_stop(void) {
    if (!bridgeRunning) { return; }

    if (eventTap != NULL) {
        CGEventTapEnable(eventTap, false);
    }
    if (eventTapRunLoopSource != NULL) {
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            eventTapRunLoopSource,
            kCFRunLoopCommonModes
        );
        CFRelease(eventTapRunLoopSource);
        eventTapRunLoopSource = NULL;
    }
    if (eventTap != NULL) {
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = NULL;
    }
    if (axObserver != NULL) {
        // Remove the run-loop source before releasing the observer. The source
        // was added to CFRunLoopGetCurrent() (= main run loop, since the tap
        // runs there) in performRaiseCheck; dropping the observer without
        // removing the source leaves a zombie source attached to the loop.
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(axObserver),
            kCFRunLoopCommonModes
        );
        CFRelease(axObserver);
        axObserver = NULL;
    }
    // findDockApplication on next start unconditionally overwrites _dock_app
    // without a release, so we drop the previous one here to avoid leaking one
    // AX reference per stop/restart cycle.
    if (_dock_app != NULL) {
        CFRelease(_dock_app);
        _dock_app = NULL;
    }

    // Bump the generation so any in-flight retries that captured a pre-stop
    // value will no-op when they fire.
    raiseGeneration++;

    bridgeRunning = NO;
}

void autoraise_reload(AutoRaiseBridgeConfig *config) {
    // Reload is config-only — does not tear down the tap. If the bridge isn't
    // running, apply config anyway so a subsequent start sees fresh values.
    applyConfig(config);
}

void autoraise_on_active_space_did_change(void) {
    if (!bridgeRunning) { return; }
    spaceChanged();
}

void autoraise_on_app_did_activate(void) {
    if (!bridgeRunning) { return; }
    appActivated();
}
