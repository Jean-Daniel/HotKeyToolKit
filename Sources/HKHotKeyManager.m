/*
 *  HKHotKeyManager.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKKeyMap.h"

#import "HKHotKey.h"
#import "HKHotKeyManager.h"

#include <Carbon/Carbon.h>

static
const OSType kHKHotKeyEventSignature = 'HkTk';

static
OSStatus _HandleHotKeyEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData);

HK_INLINE
OSStatus _HKRegisterHotKey(HKKeycode keycode, HKModifier modifier, EventHotKeyID hotKeyId, EventHotKeyRef *outRef) {
  /* Convert from cocoa to carbon */
  UInt32 mask = (UInt32)HKModifierConvert(modifier, kHKModifierFormatNative, kHKModifierFormatCarbon);
  return RegisterEventHotKey(keycode, mask,hotKeyId, GetApplicationEventTarget(), 0, outRef);
}

HK_INLINE
OSStatus _HKUnregisterHotKey(EventHotKeyRef ref) {
  return UnregisterEventHotKey(ref);
}

static NSUInteger sHotKeyUID = 0;

static NSMapTable *sHotKeys;
static EventHandlerRef sHandler;
static NSMapTable *sHotKeyReferences;

/* Debugging purpose */
BOOL HKTraceHotKeyEvents = NO;

HK_INLINE
BOOL _HKManagerInstallEventHandler() {
  assert(!sHandler);
  EventHandlerRef ref;
  EventTypeSpec eventTypes[] = {
    { .eventClass = kEventClassKeyboard, .eventKind  = kEventHotKeyPressed },
    { .eventClass = kEventClassKeyboard, .eventKind  = kEventHotKeyReleased },
  };

  OSStatus err = InstallApplicationEventHandler(_HandleHotKeyEvent, GetEventTypeCount(eventTypes), eventTypes, NULL, &ref);
  if (noErr != err) {
    SPXLogError(@"error while installing event handler: %s", GetMacOSStatusCommentString(err));
    return NO;
  }

  sHandler = ref;
  /* UInt32 uid => HKHotKey */
  if (!sHotKeys)
    sHotKeys = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 0);
  /* HKHotKey => EventHotKeyRef */
  if (!sHotKeyReferences)
    sHotKeyReferences = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);

  return YES;
}

static
void _HKManagerUninstallEventHandler(void) {
  assert(sHandler);
  OSStatus err = RemoveEventHandler(sHandler);
  if (noErr != err)
    spx_log_error("error while removing event handler: %s", GetMacOSStatusErrorString(err));
  sHandler = NULL;
}

HK_INLINE
bool _HKHotKeyIsRegistred(HKHotKey *hotkey) {
  return sHotKeyReferences != NULL && NSMapGet(sHotKeyReferences, (__bridge void *)hotkey);
}

BOOL HKHotKeyRegister(HKHotKey *hotkey) {
  // Si la cle est valide est non enregistré
  if ([hotkey isValid] && !_HKHotKeyIsRegistred(hotkey)) {
    NSUInteger uid = ++sHotKeyUID;
    HKKeycode keycode = hotkey.keycode;
    HKModifier mask = hotkey.nativeModifier;

    if (HKTraceHotKeyEvents)
      NSLog(@"Registering HotKey %@", hotkey);

    EventHotKeyRef ref = NULL;
    EventHotKeyID hotKeyId = { kHKHotKeyEventSignature, (UInt32)uid };
    if (noErr == _HKRegisterHotKey(keycode, mask, hotKeyId, &ref)) {
      if (!sHotKeyReferences || 0 == NSCountMapTable(sHotKeyReferences))
        if (!_HKManagerInstallEventHandler()) {
          _HKUnregisterHotKey(ref);
          return NO;
        }

      NSMapInsert(sHotKeyReferences, (__bridge void *)hotkey, ref);
      NSMapInsert(sHotKeys, (void *)uid, (__bridge void *)hotkey);
      return YES;
    }
  }
  return NO;
}

BOOL HKHotKeyUnregister(HKHotKey *hotkey) {
  if (!_HKHotKeyIsRegistred(hotkey))
    return NO;

  EventHotKeyRef ref = NSMapGet(sHotKeyReferences, (__bridge void *)hotkey);
  NSCAssert(ref != nil, @"Unable to find Carbon HotKey Handler");
  if (!ref)
    return NO;

  OSStatus err = _HKUnregisterHotKey(ref);
  if (noErr != err) {
    SPXLogError(@"error while unregistering hotkey %@ : %s", hotkey, GetMacOSStatusErrorString(err));
    return NO;
  }

  if (HKTraceHotKeyEvents)
    NSLog(@"Unregister HotKey: %@", hotkey);

  NSMapRemove(sHotKeyReferences, (__bridge void *)hotkey);

  /* Remove from keys record */
  intptr_t uid = 0;
  void *hkeyptr = nil;
  NSMapEnumerator refs = NSEnumerateMapTable(sHotKeys);
  while (NSNextMapEnumeratorPair(&refs, (void **)&uid, &hkeyptr)) {
    HKHotKey *hkey = (__bridge HKHotKey *)hkeyptr;
    if (hkey == hotkey) {
      NSMapRemove(sHotKeys, (void *)uid);
      break;
    }
  }
  NSEndMapTableEnumeration(&refs);
  if (0 == NSCountMapTable(sHotKeyReferences))
    _HKManagerUninstallEventHandler();
  return YES;
}

BOOL HKHotKeyUnregisterAll(void) {
  if (NSCountMapTable(sHotKeyReferences)) {
    EventHotKeyRef ref = NULL;
    NSMapEnumerator refs = NSEnumerateMapTable(sHotKeyReferences);
    while (NSNextMapEnumeratorPair(&refs, NULL, (void **)&ref)) {
      if (ref)
        _HKUnregisterHotKey(ref);
    }
    NSEndMapTableEnumeration(&refs);
    NSResetMapTable(sHotKeyReferences);
    NSResetMapTable(sHotKeys);

    _HKManagerUninstallEventHandler();
  }
  return YES;
}

//MARK: -
BOOL HKHotKeyCheckKeyCodeAndModifier(HKKeycode code, HKModifier modifier) {
  BOOL isValid = NO;
  EventHotKeyRef key;
  EventHotKeyID hotKeyId = { 'Test', 0 };
  if (noErr == _HKRegisterHotKey(code, modifier, hotKeyId, &key)) {
    verify_noerr(_HKUnregisterHotKey(key));
    isValid = YES;
  }
  return isValid;
}

//MARK: Carbon Event Handler
OSStatus _HandleHotKeyEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
  NSCAssert(GetEventClass(theEvent) == kEventClassKeyboard, @"Unknown event class");

  EventHotKeyID hotKeyID;
  OSStatus err = GetEventParameter(theEvent,
                                   kEventParamDirectObject,
                                   typeEventHotKeyID,
                                   NULL,
                                   sizeof(EventHotKeyID),
                                   NULL,
                                   &hotKeyID);
  if(noErr == err) {
    NSCAssert(hotKeyID.id != 0, @"Invalid hot key id");
    NSCAssert(hotKeyID.signature == kHKHotKeyEventSignature, @"Invalid hot key signature");

    if (HKTraceHotKeyEvents) {
      NSLog(@"HKManagerEvent {class:%@ kind:%lu signature:%@ id:0x%lx }",
            NSFileTypeForHFSTypeCode(GetEventClass(theEvent)),
            (long)GetEventKind(theEvent),
            NSFileTypeForHFSTypeCode(hotKeyID.signature),
            (long)hotKeyID.id);
    }
    HKHotKey *hotKey = (__bridge HKHotKey *)NSMapGet(sHotKeys, (void *)(intptr_t)hotKeyID.id);
    if (hotKey) {
      switch(GetEventKind(theEvent)) {
        case kEventHotKeyPressed:
          [hotKey keyPressed:GetEventTime(theEvent)];
          break;
        case kEventHotKeyReleased:
          [hotKey keyReleased:GetEventTime(theEvent)];
          break;
        default:
          SPXDebug(@"Unknown event kind");
          break;
      }
    } else {
      SPXDebug(@"Invalid hotkey id!");
    }
  }
  return err;
}
