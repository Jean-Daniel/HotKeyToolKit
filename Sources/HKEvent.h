/*
 *  HKEvent.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import <ApplicationServices/ApplicationServices.h>

#import <HotKeyToolKit/HKBase.h>
#import <HotKeyToolKit/HKHotKey.h>

HK_EXPORT
CGEventSourceRef HKEventCreatePrivateSource(void);

HK_EXPORT
void HKEventPostKeystroke(HKKeycode keycode, HKModifier modifier, CGEventSourceRef source, CFIndex latency);

HK_EXPORT
bool HKEventPostCharacterKeystrokes(UniChar character, CGEventSourceRef source, CFIndex latency);

typedef union {
  OSType signature;
  CFStringRef bundle;
  ProcessSerialNumber *psn;
} HKEventTarget;

typedef NS_ENUM(NSInteger, HKEventTargetType) {
  kHKEventTargetSystem = 0,
  kHKEventTargetBundle,
  kHKEventTargetProcess,
  kHKEventTargetSignature,
};

/* 3 ms should be a good default */
enum {
  kHKEventDefaultLatency = 3000,
};

/*!
@function
 @abstract   Send a keyboard shortcut event to a running process.
 @param      keycode If you don't know it or you want the keycode be resolved at run time, use <i>kHKInvalidVirtualKeyCode</i>.
 @param      modifier A combination of Quartz Modifier constants.
 @param      usLatency micro seconds. < 0 means process events, else if > 0, uses sleep.
 @result     Returns true of successfully sent.
 */
HK_EXPORT
bool HKEventPostKeystrokeToTarget(HKKeycode keycode, HKModifier modifier, HKEventTarget target, HKEventTargetType type, CGEventSourceRef source, CFIndex usLatency);

HK_EXPORT
bool HKEventPostCharacterKeystrokesToTarget(UniChar character, HKEventTarget target, HKEventTargetType type, CGEventSourceRef source, CFIndex usLatency);

@interface HKHotKey (HKEventExtension)

- (BOOL)sendKeystroke:(CFIndex)latency;

  /*!
  @method
   @abstract Perform the receiver HotKey on the application specified by <i>signature</i> or <i>bundleId</i>.
   @discussion If you want to send event system wide, pass '????' or 0 as signature and nil and bundle identifier, or use -sendKeystroke method.
   @param signature The target application process signature (creator).
   @param bundleId The Bundle identifier of the target process.
   @result YES.
   */
- (BOOL)sendKeystrokeToApplication:(OSType)signature bundle:(NSString *)bundleId latency:(CFIndex)latency;

@end
