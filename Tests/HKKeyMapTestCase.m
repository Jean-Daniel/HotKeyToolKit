/*
 *  HKKeyMapTestCase.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKKeyMapTestCase.h"
#import <HotKeyToolKit/HotKeyToolKit.h>

@implementation HKKeyMapTestCase

- (void)setUp {
  /* Load the key Map */
  XCTAssertNotNil([[HKKeyMap currentKeyMap] identifier], @"Error while loading keymap");
}

- (void)testDeadKeyRepresentation {
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  UInt32 keycode = 33; // ^ key on french keyboard
  UniChar chr = [keymap characterForKeycode:keycode];
  XCTAssertTrue('^' == chr, @"HKMapGetUnicharForKeycode return '%C' (0x%x) instead of '^'", chr, chr);

  keycode = 42; // ` key on french keyboard
  chr = [keymap characterForKeycode:keycode];
  XCTAssertTrue('`' == chr, @"HKMapGetUnicharForKeycode return '%C' (0x%x) instead of '`'", chr, chr);

  keycode = kHKVirtualSpaceKey;
  chr = [keymap characterForKeycode:keycode];
  XCTAssertTrue(' ' == chr, @"HKMapGetUnicharForKeycode return '%C' (0x%x) instead of ' '", chr, chr);
}

- (void)testMapping {
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  UniChar uchr = [keymap characterForKeycode:0];
  XCTAssertTrue(uchr == 'q', @"mapping does not work");

  uchr = [keymap characterForKeycode:0 modifiers:kCGEventFlagMaskShift];
  XCTAssertTrue(uchr == 'Q', @"mapping does not work");
}

- (void)testReverseMapping {
  UniChar character = 's';
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  HKKeycode keycode = [keymap keycodeForCharacter:character modifiers:NULL];
  XCTAssertTrue(keycode != kHKInvalidVirtualKeyCode, @"Reverse mapping does not work");

  UniChar reverseChar = [keymap characterForKeycode:keycode];
  XCTAssertTrue(reverseChar != kHKNilUnichar, @"Reverse mapping does not work");
  XCTAssertTrue(reverseChar == character, @"Reverse mapping does not work");

  HKKeycode keycode2 = [keymap keycodeForCharacter:'S' modifiers:NULL];
  XCTAssertTrue(keycode == keycode2, @"'s'(%d) and 'S'(%d) should have same keycode", keycode, keycode2);

  HKModifier modifier;
  HKKeycode scode = [keymap keycodeForCharacter:'S' modifiers:&modifier];
  XCTAssertTrue(scode == keycode, @"Invalid keycode for reverse mapping");
  XCTAssertTrue(modifier == NSShiftKeyMask, @"Invalid modifier for reverse mapping");

  keycode = [keymap keycodeForCharacter:'^' modifiers:NULL];
  XCTAssertTrue(keycode != kHKInvalidVirtualKeyCode, @"'^'unichar to deadkey does not return a valid keycode");

  keycode = [keymap keycodeForCharacter:' ' modifiers:NULL];
  XCTAssertTrue(kHKVirtualSpaceKey == keycode, @"'space' mapping does not works");

  /* no break space */
  keycode = [keymap keycodeForCharacter:0xa0 modifiers:NULL];
  XCTAssertTrue(kHKVirtualSpaceKey == keycode, @"'no break space' mapping does not works");
}

- (void)testAdvancedReverseMapping {
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  HKKeycode keycode = [keymap keycodeForCharacter:'n' modifiers:NULL];
  UniChar character = 0x00D1; /* 'Ñ' */
  HKKeycode keycodes[4];
  HKModifier modifiers[4];
  NSUInteger count = [keymap getKeycodes:keycodes modifiers:modifiers maxLength:4 forCharacter:character];
  XCTAssertTrue(count == 2, @"Invalid keys count (%lu) for reverse mapping", (unsigned long)count);

  XCTAssertTrue(keycodes[0] == keycode, @"Invalid modifier for tilde");
  XCTAssertTrue(modifiers[0] == kCGEventFlagMaskAlternate, @"Invalid modifier for tilde");

  XCTAssertTrue(keycodes[1] == keycode, @"Invalid modifier for tilde");
  XCTAssertTrue(modifiers[1] == kCGEventFlagMaskShift, @"Invalid modifier for tilde");
}

@end
