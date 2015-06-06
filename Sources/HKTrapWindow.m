/*
 *  HKTrapWindow.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKKeyMap.h"
#import "HKHotKey.h"
#import "HKTrapWindow.h"
#import "HKHotKeyManager.h"

#pragma mark Constants Definition
NSString * const kHKEventKeyCodeKey = @"EventKeycode";
NSString * const kHKEventModifierKey = @"EventModifier";
NSString * const kHKEventCharacterKey = @"EventCharacter";
NSString * const kHKTrapWindowDidCatchKeyNotification = @"kHKTrapWindowKeyCaught";

#pragma mark -
@implementation HKTrapWindow {
@private
  struct _hk_twFlags {
    unsigned int trap:1;
    unsigned int resend:1;
    unsigned int skipverify:1;
    unsigned int :29;
  } _twFlags;
}

- (id<HKTrapWindowDelegate>)delegate {
  return (id<HKTrapWindowDelegate>)[super delegate];
}
- (void)setDelegate:(id<HKTrapWindowDelegate>)delegate {
  id previous = [super delegate];
  if (previous) {
    SPXDelegateUnregisterNotification(previous, @selector(trapWindowDidCatchHotKey:), kHKTrapWindowDidCatchKeyNotification);
  }
  [super setDelegate:delegate];
  if (delegate) {
    SPXDelegateRegisterNotification(delegate, @selector(trapWindowDidCatchHotKey:), kHKTrapWindowDidCatchKeyNotification);
  }
}
#pragma mark -
#pragma mark Trap accessor
- (BOOL)trapping {
  return _twFlags.trap;
}

- (void)setTrapping:(BOOL)flag {
  SPXFlagSet(_twFlags.trap, flag);
}

- (BOOL)verifyHotKey {
  return !_twFlags.skipverify;
}
- (void)setVerifyHotKey:(BOOL)flag {
  SPXFlagSet(_twFlags.skipverify, !flag);
}

#pragma mark -
#pragma mark Event Trap.
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
  if (_twFlags.trap && !_twFlags.resend) {
    if (!SPXDelegateHandle([self delegate], trapWindow:shouldTrapKeyEquivalent:)
        || [[self delegate] trapWindow:self shouldTrapKeyEquivalent:theEvent])  {
      _twFlags.resend = 1;
      [self sendEvent:theEvent];
      _twFlags.resend = 0;
      return YES;
    }
  }
  return [super performKeyEquivalent:theEvent];
}

- (void)handleHotKey:(HKHotKey *)aKey {
  if (_twFlags.trap) {
    bool valid = true;
    if ([[self delegate] respondsToSelector:@selector(trapWindow:isValidHotKey:modifier:)])
      valid = [[self delegate] trapWindow:self isValidHotKey:aKey.keycode modifier:aKey.nativeModifier];

    if (valid) {
      NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                @(aKey.keycode), kHKEventKeyCodeKey,
                                @(aKey.modifier), kHKEventModifierKey,
                                @(aKey.character), kHKEventCharacterKey,
                                nil];
      [[NSNotificationCenter defaultCenter] postNotificationName:kHKTrapWindowDidCatchKeyNotification
                                                          object:self
                                                        userInfo:userInfo];
    }
  }
}

- (void)sendEvent:(NSEvent *)theEvent {
  if (!_twFlags.trap || [theEvent type] != NSKeyDown)
    return [super sendEvent:theEvent];

  if (!_twFlags.resend && SPXDelegateHandle([self delegate], trapWindow:shouldTrapKeyEvent:)) {
    if (![[self delegate] trapWindow:self shouldTrapKeyEvent:theEvent])
      return [super sendEvent:theEvent];
  }

  HKKeycode code = [theEvent keyCode];
  NSUInteger mask = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask; //0x00ff0000;
  unichar character = 0;
  //      SPXDebug(@"Code: %u, modifier: %x", code, mask);
  //      if (mask & NSNumericPadKeyMask) {
  //        SPXDebug(@"NumericPad");
  //      }
  if (mask & NSAlphaShiftKeyMask) {
    // ignore caps lock modifier
    mask &= ~NSAlphaShiftKeyMask;
  }
  /* If verify keycode and modifier */
  bool valid = true;
  HKModifier modifier = (HKModifier)HKModifierConvert(mask, kHKModifierFormatCocoa, kHKModifierFormatNative);
  if ([self verifyHotKey]) {
    /* ask delegate if he want to filter the keycode and modifier */
    if ([[self delegate] respondsToSelector:@selector(trapWindow:isValidHotKey:modifier:)])
      valid = [[self delegate] trapWindow:self isValidHotKey:code modifier:modifier];
    /* ask hotkey manager */
    if (valid)
      valid = HKHotKeyCheckKeyCodeAndModifier(code, modifier);
  }
  if (valid) {
    character = [[HKKeyMap currentKeyMap] characterForKeycode:code];
    if (kHKNilUnichar == character) {
      code = kHKInvalidVirtualKeyCode;
      modifier = 0;
      NSBeep();
    }
  } else {
    NSBeep();
    modifier = 0;
    character = kHKNilUnichar;
    code = kHKInvalidVirtualKeyCode;
  }
  if (code != kHKInvalidVirtualKeyCode) {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @(code), kHKEventKeyCodeKey,
                              @(modifier), kHKEventModifierKey,
                              @(character), kHKEventCharacterKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kHKTrapWindowDidCatchKeyNotification
                                                        object:self
                                                      userInfo:userInfo];
  }
}

@end
