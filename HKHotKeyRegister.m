//
//  SKHotKeyRegister.m
//  Spark
//
//  Created by Fox on Sun Dec 14 2003.
//  Copyright (c) 2004 Shadow Lab. All rights reserved.
//

#include <Carbon/Carbon.h>
#import "HKHotKeyRegister.h"
#import "HKKeyMap.h"

EventHotKeyRef HKRegisterHotKey(UInt16 keycode, UInt32 modifier, EventHotKeyID hotKeyId) {
  EventHotKeyRef outRef;
  /* Convert from cocoa to carbon */
  UInt32 mask = HKUtilsConvertModifier(modifier, kHKModifierFormatCocoa, kHKModifierFormatCarbon);
  OSStatus err = RegisterEventHotKey (keycode,
                                      mask,
                                      hotKeyId,
                                      GetApplicationEventTarget(),
                                      0,
                                      &outRef);
#if defined(DEBUG)
  switch (err) {
    case noErr:
      NSLog(@"HotKey Registred");
      break;
    case eventHotKeyExistsErr:
      NSLog(@"HotKey Exists");
      break;
    case eventHotKeyInvalidErr:
      NSLog(@"Invalid Hot Key");
      break;
    default:
      NSLog(@"Undefined error RegisterEventHotKey: %i", err);
  }
#else
#pragma unused(err)
#endif
  return outRef;
}

BOOL HKUnregisterHotKey(EventHotKeyRef ref) {
  NSCParameterAssert(nil != ref);
  OSStatus err = UnregisterEventHotKey(ref);
#if defined(DEBUG)
  switch (err) {
    case noErr:
      NSLog(@"HotKey Unregistred");
      break;
    case eventHotKeyInvalidErr:
      NSLog(@"Invalid Hot Key");
      break;
    default:
      NSLog(@"Error %i during UnregisterEventHotKey", err);
  }
#endif
  return err == noErr;
}