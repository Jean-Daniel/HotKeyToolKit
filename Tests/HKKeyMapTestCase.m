/*
 *  HKKeyMapTestCase.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2012 Shadow Lab. All rights reserved.
 */

#import "HKKeyMapTestCase.h"
#import <HotKeyToolKit/HotKeyToolKit.h>

@implementation HKKeyMapTestCase

- (void)setUp {
  /* Load the key Map */
  STAssertNotNil([[HKKeyMap currentKeyMap] identifier], @"Error while loading keymap");
}

- (void)testDeadKeyRepresentation {
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  UInt32 keycode = 33; // ^ key on french keyboard
  UniChar chr = [keymap characterForKeycode:keycode];
  STAssertTrue('^' == chr, @"HKMapGetUnicharForKeycode return '%C' (0x%x) instead of '^'", chr, chr);

  keycode = 42; // ` key on french keyboard
  chr = [keymap characterForKeycode:keycode];
  STAssertTrue('`' == chr, @"HKMapGetUnicharForKeycode return '%C' (0x%x) instead of '`'", chr, chr);

  keycode = kHKVirtualSpaceKey;
  chr = [keymap characterForKeycode:keycode];
  STAssertTrue(' ' == chr, @"HKMapGetUnicharForKeycode return '%C' (0x%x) instead of ' '", chr, chr);
}

- (void)testMapping {
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  UniChar uchr = [keymap characterForKeycode:0];
  STAssertTrue(uchr == 'q', @"mapping does not work");

  uchr = [keymap characterForKeycode:0 modifiers:kCGEventFlagMaskShift];
  STAssertTrue(uchr == 'Q', @"mapping does not work");
}

- (void)testReverseMapping {
  UniChar character = 's';
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  HKKeycode keycode = [keymap keycodeForCharacter:character modifiers:NULL];
  STAssertTrue(keycode != kHKInvalidVirtualKeyCode, @"Reverse mapping does not work");

  UniChar reverseChar = [keymap characterForKeycode:keycode];
  STAssertTrue(reverseChar != kHKNilUnichar, @"Reverse mapping does not work");
  STAssertTrue(reverseChar == character, @"Reverse mapping does not work");

  HKKeycode keycode2 = [keymap keycodeForCharacter:'S' modifiers:NULL];
  STAssertTrue(keycode == keycode2, @"'s'(%d) and 'S'(%d) should have same keycode", keycode, keycode2);

  HKModifier modifier;
  HKKeycode scode = [keymap keycodeForCharacter:'S' modifiers:&modifier];
  STAssertTrue(scode == keycode, @"Invalid keycode for reverse mapping");
  STAssertTrue(modifier == NSShiftKeyMask, @"Invalid modifier for reverse mapping");

  keycode = [keymap keycodeForCharacter:'^' modifiers:NULL];
  STAssertTrue(keycode != kHKInvalidVirtualKeyCode, @"'^'unichar to deadkey does not return a valid keycode");

  keycode = [keymap keycodeForCharacter:' ' modifiers:NULL];
  STAssertTrue(kHKVirtualSpaceKey == keycode, @"'space' mapping does not works");

  /* no break space */
  keycode = [keymap keycodeForCharacter:0xa0 modifiers:NULL];
  STAssertTrue(kHKVirtualSpaceKey == keycode, @"'no break space' mapping does not works");
}

- (void)testAdvancedReverseMapping {
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  HKKeycode keycode = [keymap keycodeForCharacter:'n' modifiers:NULL];
  UniChar character = 0x00D1; /* 'Ñ' */
  HKKeycode keycodes[4];
  HKModifier modifiers[4];
  NSUInteger count = [keymap getKeycodes:keycodes modifiers:modifiers maxLength:4 forCharacter:character];
  STAssertTrue(count == 2, @"Invalid keys count (%d) for reverse mapping", count);

  STAssertTrue(keycodes[0] == keycode, @"Invalid modifier for tilde");
  STAssertTrue(modifiers[0] == kCGEventFlagMaskAlternate, @"Invalid modifier for tilde");

  STAssertTrue(keycodes[1] == keycode, @"Invalid modifier for tilde");
  STAssertTrue(modifiers[1] == kCGEventFlagMaskShift, @"Invalid modifier for tilde");
}

@end
