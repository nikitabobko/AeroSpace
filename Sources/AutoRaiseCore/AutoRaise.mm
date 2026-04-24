/*
 * AutoRaise - Copyright (C) 2026 sbmpost
 * Some pieces of the code are based on
 * metamove by jmgao as part of XFree86
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

/*
 * Adapted from AutoRaise (https://github.com/AdrianLSY/AutoRaise) for integration
 * into AeroSpace. Licensed under GPL-2.0-or-later; see the notice above.
 *
 * Modifications vs. upstream (openspec change integrate-autoraise):
 *   - Removed main(), NSApplication bootstrap, and CLI/config-file parsing.
 *   - Removed MDWorkspaceWatcher (observers now live in AeroSpace's GlobalObserver,
 *     which calls into this module via AutoRaiseBridge).
 *   - Removed the cmd-tab / cmd-grave mouse-warp and cursor-scale path
 *     (CGSSetCursorScale, warpX/warpY/scale, altTaskSwitcher, get_mousepoint,
 *     is_desktop_window, _previousFinderWindow).
 *   - Removed verbose-logging guards (all NSLog call-sites behind `if (verbose)`).
 *   - Removed OLD_ACTIVATION_METHOD and ALTERNATIVE_TASK_SWITCHER compile flags.
 *   - Removed the 5.x deprecated-key migration path (no equivalent legacy config
 *     in AeroSpace).
 *   - appActivated() becomes a tiny function that only opens the suppression
 *     window; warp behavior is out-of-scope for AeroSpace's integration.
 *   - Config globals (ignoreApps, ignoreTitles, stayFocusedBundleIds,
 *     pollMillis, disableKey, invertDisableKey, invertIgnoreApps,
 *     ignoreSpaceChanged) remain as file-scope state; AutoRaiseBridge.mm
 *     populates them from AutoRaiseConfigC at start/reload time.
 */

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#import "AutoRaiseBridge.h"

// Route callback, set once by AutoRaiseBridge (autoraise_set_route_callback)
// and read from `raiseAndActivate` on the main thread.
extern AutoRaiseRouteRaise routeRaise;

#define STACK_THRESHOLD 20

// It seems OSX Monterey introduced a transparent 3 pixel border around each window. This
// means that when two windows are visually precisely connected and not overlapping, in
// reality they are. Consequently one has to move the mouse 3 pixels further out of the
// visual area to make the connected window raise. This new OSX 'feature' also introduces
// unwanted raising of windows when visually connected to the top menu bar. To solve this
// we correct the mouse position before determining which window is underneath the mouse.
#define WINDOW_CORRECTION 3
#define MENUBAR_CORRECTION 8
#define SCREEN_EDGE_CORRECTION 1 // 1 <= value <= WINDOW_CORRECTION

// Raise retry schedule. These intervals cover app response time (Finder, Electron),
// not polling cadence — decoupled from pollMillis.
#define RAISE_RETRY_1_MS 50
#define RAISE_RETRY_2_MS 100

// Suppression window opened after app activation during which incidental mouse-moved
// events do not trigger raises. Covers the stabilization window before the new app's
// window is settled under the cursor.
#define SUPPRESS_MS 150

extern "C" AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID *out);

// Non-static globals below are read or written by AutoRaiseBridge via `extern`.
// See openspec change integrate-autoraise §D3 ("globals stay globals").
AXObserverRef axObserver = NULL;
uint64_t lastDestroyedMouseWindow_id = kCGNullWindowID;

CFMachPortRef eventTap = NULL;
static AXUIElementRef _accessibility_object = AXUIElementCreateSystemWide();
// `static` stripped so AutoRaiseBridge can release it on stop (see the pattern
// applied to other file-scope state below).
AXUIElementRef _dock_app = NULL;
NSArray * ignoreApps = NULL;
NSArray * ignoreTitles = NULL;
NSArray * stayFocusedBundleIds = NULL;
static NSArray * const mainWindowAppsWithoutTitle = @[
    @"System Settings",
    @"System Information",
    @"Photos",
    @"Calculator",
    @"Podcasts",
    @"Stickies Pro",
    @"Reeder",
];
static NSArray * pwas = @[
    @"Chrome",
    @"Chromium",
    @"Vivaldi",
    @"Brave",
    @"Opera",
    @"edgemac",
    @"helium",
];
static NSString * const DockBundleId = @"com.apple.dock";
static NSString * const AssistiveControl = @"AssistiveControl";
static NSString * const MissionControl = @"Mission Control";
static NSString * const BartenderBar = @"Bartender Bar";
static NSString * const AppStoreSearchResults = @"Search results";
static NSString * const Untitled = @"Untitled"; // OSX Email search
static NSString * const Zim = @"Zim";
static NSString * const XQuartz = @"XQuartz";
static NSString * const Finder = @"Finder";
static NSString * const Pake = @"pake";
static NSString * const NoTitle = @"";
CGPoint desktopOrigin = {0, 0};
CGPoint oldPoint = {0, 0};
bool ignoreSpaceChanged = false;
bool invertDisableKey = false;
bool invertIgnoreApps = false;
int pollMillis = 0;
int disableKey = 0;

// Event-driven throttle + suppression state. All times in milliseconds since process
// start, using a monotonic clock. `raiseGeneration` is incremented every time a raise
// is checked; scheduled retries capture the generation at schedule time and only fire
// if it still matches at execution time.
double lastCheckTime = 0;
double suppressRaisesUntil = 0;
uint64_t raiseGeneration = 0;

static inline double currentTimeMillis() {
    return [[NSProcessInfo processInfo] systemUptime] * 1000.0;
}

//---------------------------------------------helper methods-----------------------------------------------

inline void activate(pid_t pid) {
    // Note activateWithOptions does not work properly on OSX 11.1
    [[NSRunningApplication runningApplicationWithProcessIdentifier: pid]
        activateWithOptions: 0];
}

// AeroSpace integration: route the raise through Swift via the bridge callback.
// Swift resolves the CGWindowID to an AeroSpace Window, enforces the
// current-workspace rule, and calls setFocus(to:).
inline void raiseAndActivate(AXUIElementRef _window) {
    CGWindowID window_id = kCGNullWindowID;
    if (_AXUIElementGetWindow(_window, &window_id) != kAXErrorSuccess) { return; }
    if (routeRaise != NULL) { routeRaise((uint32_t) window_id); }
}

// TODO: does not take into account different languages
inline bool titleEquals(AXUIElementRef _element, NSArray * _titles, NSArray * _patterns = NULL) {
    bool equal = false;
    CFStringRef _elementTitle = NULL;
    AXUIElementCopyAttributeValue(_element, kAXTitleAttribute, (CFTypeRef *) &_elementTitle);
    if (_elementTitle) {
        NSString * _title = (__bridge NSString *) _elementTitle;
        equal = [_titles containsObject: _title];
        if (!equal && _patterns) {
            for (NSString * _pattern in _patterns) {
                equal = [_title rangeOfString: _pattern options: NSRegularExpressionSearch].location != NSNotFound;
                if (equal) { break; }
            }
        }
        CFRelease(_elementTitle);
    } else { equal = [_titles containsObject: NoTitle]; }
    return equal;
}

inline bool dock_active() {
    bool active = false;
    AXUIElementRef _focusedUIElement = NULL;
    AXUIElementCopyAttributeValue(_dock_app, kAXFocusedUIElementAttribute, (CFTypeRef *) &_focusedUIElement);
    if (_focusedUIElement) {
        active = true;
        CFRelease(_focusedUIElement);
    }
    return active;
}

inline bool mc_active() {
    bool active = false;
    CFArrayRef _children = NULL;
    AXUIElementCopyAttributeValue(_dock_app, kAXChildrenAttribute, (CFTypeRef *) &_children);
    if (_children) {
        CFIndex count = CFArrayGetCount(_children);
        for (CFIndex i=0;!active && i != count;i++) {
            CFStringRef _element_role = NULL;
            AXUIElementRef _element = (AXUIElementRef) CFArrayGetValueAtIndex(_children, i);
            AXUIElementCopyAttributeValue(_element, kAXRoleAttribute, (CFTypeRef *) &_element_role);
            if (_element_role) {
                active = CFEqual(_element_role, kAXGroupRole) && titleEquals(_element, @[MissionControl]);
                CFRelease(_element_role);
            }
        }
        CFRelease(_children);
    }
    return active;
}

NSDictionary * topwindow(CGPoint point) {
    NSDictionary * top_window = NULL;
    NSArray * window_list = (NSArray *) CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID));

    for (NSDictionary * window in window_list) {
        NSDictionary * window_bounds_dict = window[(NSString *) CFBridgingRelease(kCGWindowBounds)];

        if (![window[(__bridge id) kCGWindowLayer] isEqual: @0]) { continue; }

        NSRect window_bounds = NSMakeRect(
            [window_bounds_dict[@"X"] intValue],
            [window_bounds_dict[@"Y"] intValue],
            [window_bounds_dict[@"Width"] intValue],
            [window_bounds_dict[@"Height"] intValue]);

        if (NSPointInRect(NSPointFromCGPoint(point), window_bounds)) {
            top_window = window;
            break;
        }
    }

    return top_window;
}

AXUIElementRef fallback(CGPoint point) {
    AXUIElementRef _window = NULL;
    NSDictionary * top_window = topwindow(point);
    if (top_window) {
        CFTypeRef _windows_cf = NULL;
        pid_t pid = [top_window[(__bridge id) kCGWindowOwnerPID] intValue];
        AXUIElementRef _window_owner = AXUIElementCreateApplication(pid);
        AXUIElementCopyAttributeValue(_window_owner, kAXWindowsAttribute, &_windows_cf);
        CFRelease(_window_owner);
        if (_windows_cf) {
            NSArray * application_windows = (NSArray *) CFBridgingRelease(_windows_cf);
            CGWindowID top_window_id = [top_window[(__bridge id) kCGWindowNumber] intValue];
            if (top_window_id) {
                for (id application_window in application_windows) {
                    CGWindowID application_window_id;
                    AXUIElementRef application_window_ax =
                        (__bridge AXUIElementRef) application_window;
                    if (_AXUIElementGetWindow(
                        application_window_ax,
                        &application_window_id) == kAXErrorSuccess) {
                        if (application_window_id == top_window_id) {
                            _window = application_window_ax;
                            CFRetain(_window);
                            break;
                        }
                    }
                }
            }
        } else {
            activate(pid);
        }
    }

    return _window;
}

AXUIElementRef get_raisable_window(AXUIElementRef _element, CGPoint point, int count) {
    AXUIElementRef _window = NULL;
    if (_element) {
        if (count >= STACK_THRESHOLD) {
            CFRelease(_element);
        } else {
            CFStringRef _element_role = NULL;
            AXUIElementCopyAttributeValue(_element, kAXRoleAttribute, (CFTypeRef *) &_element_role);
            bool check_attributes = !_element_role;
            if (_element_role) {
                if (CFEqual(_element_role, kAXDockItemRole) ||
                    CFEqual(_element_role, kAXMenuItemRole) ||
                    CFEqual(_element_role, kAXMenuRole) ||
                    CFEqual(_element_role, kAXMenuBarRole) ||
                    CFEqual(_element_role, kAXMenuBarItemRole)) {
                    CFRelease(_element_role);
                    CFRelease(_element);
                } else if (
                    CFEqual(_element_role, kAXWindowRole) ||
                    CFEqual(_element_role, kAXSheetRole) ||
                    CFEqual(_element_role, kAXDrawerRole)) {
                    CFRelease(_element_role);
                    _window = _element;
                } else if (CFEqual(_element_role, kAXApplicationRole)) {
                    CFRelease(_element_role);
                    if (titleEquals(_element, @[XQuartz])) {
                        pid_t application_pid;
                        if (AXUIElementGetPid(_element, &application_pid) == kAXErrorSuccess) {
                            pid_t frontmost_pid = [[[NSWorkspace sharedWorkspace]
                                frontmostApplication] processIdentifier];
                            if (application_pid != frontmost_pid) {
                                // Focus and/or raising is the responsibility of XQuartz.
                                activate(application_pid);
                            }
                        }
                        CFRelease(_element);
                    } else { check_attributes = true; }
                } else {
                    CFRelease(_element_role);
                    check_attributes = true;
                }
            }

            if (check_attributes) {
                AXUIElementCopyAttributeValue(_element, kAXParentAttribute, (CFTypeRef *) &_window);
                bool no_parent = !_window;
                _window = get_raisable_window(_window, point, ++count);
                if (!_window) {
                    AXUIElementCopyAttributeValue(_element, kAXWindowAttribute, (CFTypeRef *) &_window);
                    if (!_window && no_parent) { _window = fallback(point); }
                }
                CFRelease(_element);
            }
        }
    }

    return _window;
}

AXUIElementRef get_mousewindow(CGPoint point) {
    AXUIElementRef _element = NULL;
    AXError error = AXUIElementCopyElementAtPosition(_accessibility_object, point.x, point.y, &_element);

    AXUIElementRef _window = NULL;
    if (_element) {
        _window = get_raisable_window(_element, point, 0);
    } else if (error == kAXErrorCannotComplete || error == kAXErrorNotImplemented) {
        // fallback, happens for apps that do not support the Accessibility API
        _window = fallback(point);
    } else if (error == kAXErrorIllegalArgument) {
        // fallback, happens for Progressive Web Apps (PWAs)
        _window = fallback(point);
    } else if (error == kAXErrorNoValue) {
        // fallback, happens sometimes when switching to another app (with cmd-tab)
        _window = fallback(point);
    }
    // kAXErrorAttributeUnsupported (volume/WiFi menubar) and kAXErrorFailure (menubar
    // itself) fall through with _window == NULL; nothing to raise.

    return _window;
}

bool contained_within(AXUIElementRef _window1, AXUIElementRef _window2) {
    bool contained = false;
    AXValueRef _size1 = NULL;
    AXValueRef _size2 = NULL;
    AXValueRef _pos1 = NULL;
    AXValueRef _pos2 = NULL;

    AXUIElementCopyAttributeValue(_window1, kAXSizeAttribute, (CFTypeRef *) &_size1);
    if (_size1) {
        AXUIElementCopyAttributeValue(_window1, kAXPositionAttribute, (CFTypeRef *) &_pos1);
        if (_pos1) {
            AXUIElementCopyAttributeValue(_window2, kAXSizeAttribute, (CFTypeRef *) &_size2);
            if (_size2) {
                AXUIElementCopyAttributeValue(_window2, kAXPositionAttribute, (CFTypeRef *) &_pos2);
                if (_pos2) {
                    CGSize cg_size1;
                    CGSize cg_size2;
                    CGPoint cg_pos1;
                    CGPoint cg_pos2;
                    if (AXValueGetValue(_size1, kAXValueTypeCGSize, &cg_size1) &&
                        AXValueGetValue(_pos1, kAXValueTypeCGPoint, &cg_pos1) &&
                        AXValueGetValue(_size2, kAXValueTypeCGSize, &cg_size2) &&
                        AXValueGetValue(_pos2, kAXValueTypeCGPoint, &cg_pos2)) {
                        contained = cg_pos1.x > cg_pos2.x && cg_pos1.y > cg_pos2.y &&
                            cg_pos1.x + cg_size1.width < cg_pos2.x + cg_size2.width &&
                            cg_pos1.y + cg_size1.height < cg_pos2.y + cg_size2.height;
                    }
                    CFRelease(_pos2);
                }
                CFRelease(_size2);
            }
            CFRelease(_pos1);
        }
        CFRelease(_size1);
    }

    return contained;
}

void findDockApplication() {
    NSArray * _apps = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication * app in _apps) {
        if ([app.bundleIdentifier isEqual: DockBundleId]) {
            _dock_app = AXUIElementCreateApplication(app.processIdentifier);
            break;
        }
    }
}

void findDesktopOrigin() {
    NSScreen * main_screen = NSScreen.screens[0];
    float mainScreenTop = NSMaxY(main_screen.frame);
    for (NSScreen * screen in [NSScreen screens]) {
        float screenOriginY = mainScreenTop - NSMaxY(screen.frame);
        if (screenOriginY < desktopOrigin.y) { desktopOrigin.y = screenOriginY; }
        if (screen.frame.origin.x < desktopOrigin.x) { desktopOrigin.x = screen.frame.origin.x; }
    }
}

inline NSScreen * findScreen(CGPoint point) {
    NSScreen * main_screen = NSScreen.screens[0];
    point.y = NSMaxY(main_screen.frame) - point.y;
    for (NSScreen * screen in [NSScreen screens]) {
        NSRect screen_bounds = NSMakeRect(
            screen.frame.origin.x,
            screen.frame.origin.y,
            NSWidth(screen.frame) + 1,
            NSHeight(screen.frame) + 1
        );
        if (NSPointInRect(NSPointFromCGPoint(point), screen_bounds)) {
            return screen;
        }
    }
    return NULL;
}

inline bool is_full_screen(AXUIElementRef _window) {
    bool full_screen = false;
    AXValueRef _pos = NULL;
    AXUIElementCopyAttributeValue(_window, kAXPositionAttribute, (CFTypeRef *) &_pos);
    if (_pos) {
        CGPoint cg_pos;
        if (AXValueGetValue(_pos, kAXValueTypeCGPoint, &cg_pos)) {
            NSScreen * screen = findScreen(cg_pos);
            if (screen) {
                AXValueRef _size = NULL;
                AXUIElementCopyAttributeValue(_window, kAXSizeAttribute, (CFTypeRef *) &_size);
                if (_size) {
                    CGSize cg_size;
                    if (AXValueGetValue(_size, kAXValueTypeCGSize, &cg_size)) {
                        float menuBarHeight =
                            fmax(0, NSMaxY(screen.frame) - NSMaxY(screen.visibleFrame) - 1);
                        NSScreen * main_screen = NSScreen.screens[0];
                        float screenOriginY = NSMaxY(main_screen.frame) - NSMaxY(screen.frame);
                        full_screen = cg_pos.x == NSMinX(screen.frame) &&
                                      cg_pos.y == screenOriginY + menuBarHeight &&
                                      cg_size.width == NSWidth(screen.frame) &&
                                      cg_size.height == NSHeight(screen.frame) - menuBarHeight;
                    }
                    CFRelease(_size);
                }
            }
        }
        CFRelease(_pos);
    }
    return full_screen;
}

inline bool is_main_window(AXUIElementRef _app, AXUIElementRef _window, bool chrome_app) {
    bool main_window = false;
    CFBooleanRef _result = NULL;
    AXUIElementCopyAttributeValue(_window, kAXMainAttribute, (CFTypeRef *) &_result);
    if (_result) {
        main_window = CFEqual(_result, kCFBooleanTrue);
        if (main_window) {
            CFStringRef _element_sub_role = NULL;
            AXUIElementCopyAttributeValue(_window, kAXSubroleAttribute, (CFTypeRef *) &_element_sub_role);
            if (_element_sub_role) {
                main_window = !CFEqual(_element_sub_role, kAXDialogSubrole);
                CFRelease(_element_sub_role);
            }
        }
        CFRelease(_result);
    }

    bool finder_app = titleEquals(_app, @[Finder]);
    main_window = main_window && (chrome_app || finder_app ||
        !titleEquals(_window, @[NoTitle]) ||
        titleEquals(_app, mainWindowAppsWithoutTitle));

    main_window = main_window || (!finder_app && is_full_screen(_window));

    return main_window;
}

inline bool is_pwa(NSString * bundleIdentifier) {
    NSArray * components = [bundleIdentifier componentsSeparatedByString: @"."];
    bool pake = components.count == 3 && [components[1] isEqual: Pake];
    bool pwa = pake || (components.count > 4 &&
        [pwas containsObject: components[2]] && [components[3] isEqual: @"app"]);
    return pwa;
}

//-----------------------------------------------notifications----------------------------------------------

void spaceChanged();
void appActivated();
void performRaiseCheck(CGPoint mousePoint);

//------------------------------------------where it all happens--------------------------------------------

void spaceChanged() {
    if (ignoreSpaceChanged) { return; }

    CGEventRef _event = CGEventCreate(NULL);
    CGPoint mousePoint = CGEventGetLocation(_event);
    if (_event) { CFRelease(_event); }

    // Reset oldPoint so the next performRaiseCheck treats this as a fresh position,
    // matching upstream behavior (otherwise the WINDOW_CORRECTION direction
    // heuristic would use a stale delta from the last move on the prior space).
    oldPoint.x = oldPoint.y = 0;

    performRaiseCheck(mousePoint);
}

void appActivated() {
    // Open a suppression window so the hover-raise path doesn't fire on the cursor's
    // stale position while the system is still switching apps (cmd-tab, dock click,
    // etc.). The warp path that used to live here is out of scope for AeroSpace's
    // integration — see the modification notice at the top of this file.
    suppressRaisesUntil = currentTimeMillis() + SUPPRESS_MS;
}

void AXCallback(AXObserverRef observer, AXUIElementRef _element, CFStringRef notification, void * destroyedMouseWindow_id) {
    if (CFEqual(notification, kAXUIElementDestroyedNotification)) {
        lastDestroyedMouseWindow_id = (uint64_t) destroyedMouseWindow_id;
    }
}

void performRaiseCheck(CGPoint mousePoint) {
    // Every call increments the generation counter — including calls that abort
    // early or find no raise needed. This cancels any in-flight retries from a
    // previous window as soon as the cursor moves onto a different area
    // (ignored app, current frontmost, disableKey held, dock/mc active, etc.),
    // preventing stale retries from stealing focus back to an old window.
    uint64_t gen = ++raiseGeneration;

    // Corner correction (macOS 12+): direction based on delta from previous point.
    float mouse_x_diff = mousePoint.x - oldPoint.x;
    float mouse_y_diff = mousePoint.y - oldPoint.y;
    oldPoint = mousePoint;

    if (@available(macOS 12.00, *)) {
        if (fabs(mouse_x_diff) > 0 || fabs(mouse_y_diff) > 0) {
            NSScreen * screen = findScreen(mousePoint);
            mousePoint.x += mouse_x_diff > 0 ? WINDOW_CORRECTION : -WINDOW_CORRECTION;
            mousePoint.y += mouse_y_diff > 0 ? WINDOW_CORRECTION : -WINDOW_CORRECTION;
            if (screen) {
                NSScreen * main_screen = NSScreen.screens[0];
                float screenOriginX = NSMinX(screen.frame) - NSMinX(main_screen.frame);
                float screenOriginY = NSMaxY(main_screen.frame) - NSMaxY(screen.frame);

                if (oldPoint.x > screenOriginX + NSWidth(screen.frame) - WINDOW_CORRECTION) {
                    mousePoint.x = screenOriginX + NSWidth(screen.frame) - SCREEN_EDGE_CORRECTION;
                } else if (oldPoint.x < screenOriginX + WINDOW_CORRECTION - 1) {
                    mousePoint.x = screenOriginX + SCREEN_EDGE_CORRECTION;
                }

                if (oldPoint.y > screenOriginY + NSHeight(screen.frame) - WINDOW_CORRECTION) {
                    mousePoint.y = screenOriginY + NSHeight(screen.frame) - SCREEN_EDGE_CORRECTION;
                } else {
                    float menuBarHeight = fmax(0, NSMaxY(screen.frame) - NSMaxY(screen.visibleFrame) - 1);
                    if (mousePoint.y < screenOriginY + menuBarHeight + MENUBAR_CORRECTION) {
                        mousePoint.y = screenOriginY;
                    }
                }
            }
        }
    }

    // Abort: drag in progress, Dock/Mission Control active, disableKey held,
    // or frontmost app is pinned via stayFocusedBundleIds.
    bool abort = CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft) ||
        CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight) ||
        dock_active() || mc_active();

    if (!abort && disableKey) {
        CGEventRef _keyDownEvent = CGEventCreateKeyboardEvent(NULL, 0, true);
        CGEventFlags flags = CGEventGetFlags(_keyDownEvent);
        if (_keyDownEvent) { CFRelease(_keyDownEvent); }
        abort = (flags & disableKey) == disableKey;
        abort = abort != invertDisableKey;
    }

    NSRunningApplication *frontmostApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    abort = abort || [stayFocusedBundleIds containsObject: frontmostApp.bundleIdentifier];

    if (abort) { return; }

    AXUIElementRef _mouseWindow = get_mousewindow(mousePoint);
    if (!_mouseWindow) { return; }

    pid_t mouseWindow_pid;
    if (AXUIElementGetPid(_mouseWindow, &mouseWindow_pid) != kAXErrorSuccess) {
        CFRelease(_mouseWindow);
        return;
    }

    // AeroSpace deviation from upstream: upstream ignores _AXUIElementGetWindow's
    // return value, so on failure `mouseWindow_id` is uninitialized stack garbage
    // and the subsequent equality checks silently misbehave. Guard the read.
    CGWindowID mouseWindow_id;
    if (_AXUIElementGetWindow(_mouseWindow, &mouseWindow_id) != kAXErrorSuccess) {
        CFRelease(_mouseWindow);
        return;
    }
    bool mouseWindowPresent = mouseWindow_id != lastDestroyedMouseWindow_id;

    if (mouseWindowPresent) {
        static CGWindowID previous_id = kCGNullWindowID;
        if (mouseWindow_id != previous_id) {
            previous_id = mouseWindow_id;
            lastDestroyedMouseWindow_id = kCGNullWindowID;

            if (axObserver) {
                // Remove the run-loop source before releasing the observer.
                // Upstream doesn't do this — the zombie source stays attached
                // to the run loop until process exit. Mirror the cleanup we do
                // in autoraise_stop so stop/restart cycles don't accumulate
                // them either.
                CFRunLoopRemoveSource(
                    CFRunLoopGetMain(),
                    AXObserverGetRunLoopSource(axObserver),
                    kCFRunLoopCommonModes
                );
                CFRelease(axObserver);
                axObserver = NULL;
            }

            // AeroSpace deviation from upstream: upstream ignores AXObserverCreate's
            // return value. On failure axObserver stays NULL and the subsequent
            // AXObserverAddNotification + CFRunLoopAddSource(NULL) path can crash.
            // Skip observer setup on failure; the window will fall through to the
            // lastDestroyedMouseWindow_id check next tick.
            if (AXObserverCreate(
                mouseWindow_pid,
                AXCallback,
                &axObserver
            ) == kAXErrorSuccess) {
                AXObserverAddNotification(
                    axObserver,
                    _mouseWindow,
                    kAXUIElementDestroyedNotification,
                    (void *) ((uint64_t) mouseWindow_id)
                );

                CFRunLoopAddSource(
                    CFRunLoopGetMain(),
                    AXObserverGetRunLoopSource(axObserver),
                    kCFRunLoopCommonModes
                );
            }
        }
    }

    bool needs_raise = !invertIgnoreApps && mouseWindowPresent;
    AXUIElementRef _mouseWindowApp = AXUIElementCreateApplication(mouseWindow_pid);
    if (needs_raise && titleEquals(_mouseWindow, @[NoTitle, Untitled])) {
        needs_raise = is_main_window(_mouseWindowApp, _mouseWindow, is_pwa(
            [NSRunningApplication runningApplicationWithProcessIdentifier:
            mouseWindow_pid].bundleIdentifier));
    } else if (needs_raise &&
        titleEquals(_mouseWindow, @[BartenderBar, Zim, AppStoreSearchResults], ignoreTitles)) {
        needs_raise = false;
    } else if (mouseWindowPresent) {
        if (titleEquals(_mouseWindowApp, ignoreApps)) {
            needs_raise = invertIgnoreApps;
        }
    }
    CFRelease(_mouseWindowApp);

    if (needs_raise) {
        pid_t frontmost_pid = frontmostApp.processIdentifier;
        AXUIElementRef _frontmostApp = AXUIElementCreateApplication(frontmost_pid);
        AXUIElementRef _focusedWindow = NULL;
        AXUIElementCopyAttributeValue(
            _frontmostApp,
            kAXFocusedWindowAttribute,
            (CFTypeRef *) &_focusedWindow);
        if (_focusedWindow) {
            // AeroSpace deviation from upstream: guard the private-API read so an
            // uninitialized `focusedWindow_id` doesn't coincidentally match
            // `mouseWindow_id` (would suppress a legitimate raise) or mismatch it
            // (would trigger a spurious raise).
            CGWindowID focusedWindow_id;
            if (_AXUIElementGetWindow(_focusedWindow, &focusedWindow_id) == kAXErrorSuccess) {
                needs_raise = mouseWindow_id != focusedWindow_id;
                needs_raise = needs_raise && !contained_within(_focusedWindow, _mouseWindow);
            } else {
                needs_raise = false;
            }
            CFRelease(_focusedWindow);
        } else {
            AXUIElementRef _activatedWindow = NULL;
            AXUIElementCopyAttributeValue(_frontmostApp,
                kAXMainWindowAttribute, (CFTypeRef *) &_activatedWindow);
            if (_activatedWindow) {
              needs_raise = false;
              CFRelease(_activatedWindow);
            }
        }
        CFRelease(_frontmostApp);
    }

    if (needs_raise) {
        raiseAndActivate(_mouseWindow);

        // Schedule two retry raises for apps that don't respect the first one
        // (Finder, some Electron apps). Each retry captures `gen` and only fires
        // if no newer raise has been issued in the meantime.
        AXUIElementRef _win1 = (AXUIElementRef) CFRetain(_mouseWindow);
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t) RAISE_RETRY_1_MS * NSEC_PER_MSEC),
            dispatch_get_main_queue(),
            ^{
                if (gen == raiseGeneration) {
                    raiseAndActivate(_win1);
                }
                CFRelease(_win1);
            }
        );

        AXUIElementRef _win2 = (AXUIElementRef) CFRetain(_mouseWindow);
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t) RAISE_RETRY_2_MS * NSEC_PER_MSEC),
            dispatch_get_main_queue(),
            ^{
                if (gen == raiseGeneration) {
                    raiseAndActivate(_win2);
                }
                CFRelease(_win2);
            }
        );
    }

    CFRelease(_mouseWindow);
}

CGEventRef eventTapHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    // Mouse-moved: throttled + suppression-gated raise check.
    // IMPORTANT: always return `event` unmodified. This tap is listen-only; dropping
    // or mutating the event would break the user's mouse.
    if (type == kCGEventMouseMoved) {
        double now = currentTimeMillis();
        if (now - lastCheckTime < (double) pollMillis) { return event; }
        if (now < suppressRaisesUntil) { return event; }
        lastCheckTime = now;
        CGPoint mousePoint = CGEventGetLocation(event);
        performRaiseCheck(mousePoint);
        return event;
    }

    // Re-enable the tap if the system disabled it (timeout or user input during
    // a long handler run).
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        CGEventTapEnable(eventTap, true);
    }

    return event;
}
