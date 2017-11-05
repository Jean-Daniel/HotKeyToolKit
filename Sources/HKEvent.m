/*
 *  HKEvent.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKEvent.h"
#import "HKKeyMap.h"

#include <unistd.h>

static pid_t _HKGetProcessWithBundleIdentifier(CFStringRef bundleId);

#pragma mark -
HK_INLINE
void __HKEventPostKeyboardEvent(CGEventSourceRef source, HKKeycode keycode, pid_t pid, bool down, CFIndex latency) {
  CGEventRef event = CGEventCreateKeyboardEvent(source, keycode, down);
  if (pid) {
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber10_11) {
      CGEventPostToPid(pid, event);
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      ProcessSerialNumber psn;
      if (noErr == GetProcessForPID(pid, &psn)) {
        CGEventPostToPSN(&psn, event);
      }
#pragma clang diagnostic pop
    }
  } else {
    CGEventPost(kCGHIDEventTap, event);
  }
  CFRelease(event);
  if (latency > 0) {
    /* Avoid to fast typing (5 ms by default) */
    usleep((useconds_t)latency);
  } else if (latency < 0) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, -latency / 1e6, false);
  }
}

static
void _HKEventPostKeyStroke(HKKeycode keycode, HKModifier modifier, CGEventSourceRef source, pid_t pid, CFIndex latency) {
  /* WARNING: look like CGEvent does not support null source (bug) */
  BOOL isource = NO;
  if (!source) {
    isource = YES;
    source = HKEventCreatePrivateSource();
  }

  /* Sending Modifier Keydown events */
  if (kCGEventFlagMaskAlphaShift & modifier) {
    /* Lock Caps Lock */
    __HKEventPostKeyboardEvent(source, kHKVirtualCapsLockKey, pid, YES, latency);
  }
  if (kCGEventFlagMaskShift & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualShiftKey, pid, YES, latency);
  }
  if (kCGEventFlagMaskControl & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualControlKey, pid, YES, latency);
  }
  if (kCGEventFlagMaskAlternate & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualOptionKey, pid, YES, latency);
  }
  if (kCGEventFlagMaskCommand & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualCommandKey, pid, YES, latency);
  }

  /* Sending Character Key events */
  __HKEventPostKeyboardEvent(source, keycode , pid, YES, latency);
  __HKEventPostKeyboardEvent(source, keycode, pid, NO, latency);

  /* Sending Modifiers Key Up events */
  if (kCGEventFlagMaskCommand & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualCommandKey, pid, NO, latency);
  }
  if (kCGEventFlagMaskAlternate & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualOptionKey, pid, NO, latency);
  }
  if (kCGEventFlagMaskControl & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualControlKey, pid, NO, latency);
  }
  if (kCGEventFlagMaskShift & modifier) {
    __HKEventPostKeyboardEvent(source, kHKVirtualShiftKey, pid, NO, latency);
  }
  if (kCGEventFlagMaskAlphaShift & modifier) {
    /* Unlock Caps Lock */
    __HKEventPostKeyboardEvent(source, kHKVirtualCapsLockKey, pid, NO, latency);
  }

  if (isource && source) {
    CFRelease(source);
  }
}

static
bool _HKEventPostCharacterKeystrokes(UniChar character, CGEventSourceRef source, pid_t pid, CFIndex latency) {
  /* WARNING: look like CGEvent does not support null source (bug) */
  BOOL isource = NO; /* YES if internal source and should be released */
  if (!source) {
    isource = YES;
    source = HKEventCreatePrivateSource();
  }

  HKKeycode keys[8];
  HKModifier mods[8];
  NSUInteger count = [[HKKeyMap currentKeyMap] getKeycodes:keys modifiers:mods maxLength:8 forCharacter:character];
  for (NSUInteger idx = 0; idx < count; idx++) {
    _HKEventPostKeyStroke(keys[idx], mods[idx], source, pid, latency);
  }

  if (isource && source) {
    CFRelease(source);
  }

  return count > 0;
}

#pragma mark API
CGEventSourceRef HKEventCreatePrivateSource(void) {
  return CGEventSourceCreate(kCGEventSourceStatePrivate);
}

void HKEventPostKeystroke(HKKeycode keycode, HKModifier modifier, CGEventSourceRef source, CFIndex latency) {
  _HKEventPostKeyStroke(keycode, modifier, source, 0, latency);
}

bool HKEventPostCharacterKeystrokes(UniChar character, CGEventSourceRef source, CFIndex latency) {
  return _HKEventPostCharacterKeystrokes(character, source, 0, latency);
}

HK_INLINE
pid_t __HKEventGetPSNForTarget(HKEventTarget target, HKEventTargetType type) {
  switch (type) {
    case kHKEventTargetSystem:
      return 0;
    case kHKEventTargetProcess:
      return target.pid;
    case kHKEventTargetBundle:
      return _HKGetProcessWithBundleIdentifier(target.bundle);
  }
}

bool HKEventPostKeystrokeToTarget(HKKeycode keycode, HKModifier modifier, HKEventTarget target, HKEventTargetType type, CGEventSourceRef source, CFIndex latency) {
  pid_t pid = __HKEventGetPSNForTarget(target, type);
  if (pid >= 0) {
    _HKEventPostKeyStroke(keycode, modifier, source, pid, latency);
    return YES;
  }
  return NO;
}

bool HKEventPostCharacterKeystrokesToTarget(UniChar character, HKEventTarget target, HKEventTargetType type, CGEventSourceRef source, CFIndex latency) {
  pid_t pid = __HKEventGetPSNForTarget(target, type);
  if (pid >= 0) {
    _HKEventPostCharacterKeystrokes(character, source, pid, latency);
    return YES;
  }
  return NO;
}

#pragma mark -
#pragma mark Statics Functions Definition
pid_t _HKGetProcessWithBundleIdentifier(CFStringRef bundleId) {
  NSRunningApplication *app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:SPXCFToNSString(bundleId)] firstObject];
  return app ? app.processIdentifier : -1;
}

#pragma mark -
@implementation HKHotKey (HKEventExtension)

- (BOOL)sendKeystroke:(CFIndex)latency {
  if ([self isValid]) {
    HKEventTarget target = {};
    HKEventTargetType type = kHKEventTargetSystem;
    if ([self isRegistred]) {
      target.pid = [NSWorkspace.sharedWorkspace frontmostApplication].processIdentifier;
      type = kHKEventTargetProcess;
    }
    HKEventPostKeystrokeToTarget(self.keycode, self.nativeModifier, target, type, NULL, latency);
  } else {
    return NO;
  }
  return YES;
}

- (BOOL)sendKeystrokeToApplication:(NSString *)bundleId latency:(CFIndex)latency {
  BOOL result = NO;
  if ([self isValid]) {
    /* Find target and target type */
    HKEventTarget target = {};
    HKEventTargetType type = kHKEventTargetSystem;

    if (bundleId) {
      target.bundle = SPXNSToCFString(bundleId);
      type = kHKEventTargetBundle;
    }

    result = HKEventPostKeystrokeToTarget(self.keycode, self.nativeModifier, target, type, NULL, latency);
  }
  return result;
}

@end
