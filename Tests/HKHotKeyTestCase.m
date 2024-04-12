/*
 *  HKHotKeyTestCase.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKHotKeyTestCase.h"
#import <HotKeyToolKit/HotKeyToolKit.h>

@implementation HKHotKeyTests

- (void)setUp {
  _hotkey = [[HKHotKey alloc] init];
}

- (void)testHotKeyIsValid {
  [_hotkey setCharacter:kHKNilUnichar];
  XCTAssertFalse([_hotkey isValid], @"Hotkey %@ shouldn't be valid", _hotkey);

  [_hotkey setKeycode:kHKInvalidVirtualKeyCode];
  XCTAssertFalse([_hotkey isValid], @"Hotkey %@ shouldn't be valid", _hotkey);

  [_hotkey setCharacter:'a'];
  XCTAssertTrue([_hotkey isValid], @"Hotkey %@ should be valid", _hotkey);

  [_hotkey setKeycode:0];
  XCTAssertTrue([_hotkey isValid], @"Hotkey %@ should be valid", _hotkey);
}

- (void)testKeycodeCharacterDepedencies {
  [_hotkey setCharacter:kHKNilUnichar];
  XCTAssertTrue([_hotkey keycode] == kHKInvalidVirtualKeyCode, @"%@ keycode should be kHKInvalidVirtualKeyCode", _hotkey);

  [_hotkey setKeycode:kHKInvalidVirtualKeyCode];
  XCTAssertTrue([_hotkey character] == kHKNilUnichar, @"%@ character should be kHKNilUnichar", _hotkey);
}

- (void)testHotKeyRetainCount {
  HKHotKey *key2;
  {
    HKHotKey *key = [[HKHotKey alloc] initWithUnichar:'y' modifier:NSEventModifierFlagOption];
    XCTAssertTrue([key setRegistred:YES], @"%@ should be registred", key);
    /* this test can be innacurate as autorelease will bump the retain count */
    // XCTAssertTrue([key retainCount] == (unsigned)1, @"Registring key shouldn't retain it");

    key2 = [[HKHotKey alloc] initWithUnichar:'y' modifier:NSEventModifierFlagOption];
    XCTAssertFalse([key2 setRegistred:YES], @"%@ shouldn't be registred", key2);
    /* Testing if releasing a key unregister it */
  }
  XCTAssertTrue([key2 setRegistred:YES], @"%@ should registre", key2);
  // Cleanup
  XCTAssertTrue([key2 setRegistred:NO], @"%@ should be registred", key2);
}

- (void)testInvalidAccessException {
  id key = [[HKHotKey alloc] initWithUnichar:'a' modifier:NSEventModifierFlagOption];
  XCTAssertTrue([key setRegistred:YES], @"%@ should be registred", key);
  XCTAssertThrows([key setCharacter:'b'], @"Should throws exception when trying change and registred");
  XCTAssertThrows([key setKeycode:0], @"Should throws exception when trying change and registred");
  XCTAssertThrows([key setModifier:NSEventModifierFlagOption], @"Should throws exception when trying change and registred");
  XCTAssertTrue([key setRegistred:NO], @"%@ should be unregistred", key);
}

- (void)testEqualsKeyRegistring {
  id key1 = [[HKHotKey alloc] initWithUnichar:'a' modifier:NSEventModifierFlagOption];
  id key2 = [[HKHotKey alloc] initWithUnichar:'a' modifier:NSEventModifierFlagOption];
  XCTAssertTrue([key1 setRegistred:YES], @"%@ should be registred", key1);
  XCTAssertFalse([key2 setRegistred:YES], @"%@ shouldn't be registred", key2);

  [key2 setModifier:NSEventModifierFlagShift];
  XCTAssertTrue([key2 setRegistred:YES], @"%@ should be registred", key2);
  XCTAssertTrue([key2 setRegistred:NO], @"%@ should be unregistred", key2);
  XCTAssertTrue([key1 setRegistred:NO], @"%@ should be unregistred", key1);
}

- (void)testReapeatInterval {
  NSTimeInterval inter = HKGetSystemKeyRepeatInterval();
  XCTAssertTrue(inter > 0, @"Cannot retreive repeat interval");
  inter = HKGetSystemInitialKeyRepeatInterval();
  XCTAssertTrue(inter > 0, @"Cannot retreive initial repeat interval");
}

@end
