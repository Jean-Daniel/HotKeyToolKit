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

#import <unordered_map>

#include <Carbon/Carbon.h>

static inline const char *_OSStatusToStr(OSStatus err) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  return GetMacOSStatusErrorString(err);
#pragma clang diagnostic pop
}

static
const OSType kHKHotKeyEventSignature = 'HkTk';

static
OSStatus _HandleHotKeyEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData);

HK_INLINE
OSStatus _HKRegisterHotKey(HKKeycode keycode, HKModifier modifier, EventHotKeyID hotKeyId, EventHotKeyRef *outRef) {
  /* Convert from cocoa to carbon */
  UInt32 mask = static_cast<UInt32>(HKModifierConvert(modifier, kHKModifierFormatNative, kHKModifierFormatCarbon));
  return RegisterEventHotKey(keycode, mask,hotKeyId, GetApplicationEventTarget(), 0, outRef);
}

HK_INLINE
OSStatus _HKUnregisterHotKey(EventHotKeyRef ref) {
  return UnregisterEventHotKey(ref);
}

static uint32_t sHotKeyUID = 0;
static EventHandlerRef sHandler;

static
std::unordered_map<uint32_t, __unsafe_unretained HKHotKey *>&HotKeyMap() {
  static auto *sHotKeys = new std::unordered_map<uint32_t, __unsafe_unretained HKHotKey *>;
  return *sHotKeys;
}

static
std::unordered_map<__unsafe_unretained HKHotKey *, EventHotKeyRef, spx::hash> &HotKeyReferencesMap() {
    static auto *sHotKeyReferences = new std::unordered_map<__unsafe_unretained HKHotKey *, EventHotKeyRef, spx::hash>;
    return *sHotKeyReferences;
}

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
    SPXLogError(@"error while installing event handler: %s", _OSStatusToStr(err));
    return NO;
  }

  sHandler = ref;
  return YES;
}

static
void _HKManagerUninstallEventHandler(void) {
  assert(sHandler);
  OSStatus err = RemoveEventHandler(sHandler);
  if (noErr != err)
    spx_log_error("error while removing event handler: %s", _OSStatusToStr(err));
  sHandler = NULL;
}

HK_INLINE
bool _HKHotKeyIsRegistred(HKHotKey *hotkey) {
  const auto &map = HotKeyReferencesMap();
  return map.find(hotkey) != map.end();
}

BOOL HKHotKeyRegister(HKHotKey *hotkey) {
  // Si la cle est valide est non enregistré
  if ([hotkey isValid] && !_HKHotKeyIsRegistred(hotkey)) {
    uint32_t uid = ++sHotKeyUID;
    HKKeycode keycode = hotkey.keycode;
    HKModifier mask = hotkey.nativeModifier;

    if (HKTraceHotKeyEvents)
      NSLog(@"Registering HotKey %@", hotkey);

    EventHotKeyRef ref = NULL;
    EventHotKeyID hotKeyId = { kHKHotKeyEventSignature, static_cast<UInt32>(uid) };
    if (noErr == _HKRegisterHotKey(keycode, mask, hotKeyId, &ref)) {
      if (HotKeyReferencesMap().empty())
        if (!_HKManagerInstallEventHandler()) {
          _HKUnregisterHotKey(ref);
          return NO;
        }
      
      HotKeyReferencesMap()[hotkey] = ref;
      HotKeyMap()[uid] = hotkey;
      return YES;
    }
  }
  return NO;
}

BOOL HKHotKeyUnregister(HKHotKey *hotkey) {
  if (!_HKHotKeyIsRegistred(hotkey))
    return NO;

  const auto &ref = HotKeyReferencesMap().find(hotkey);
  if (ref == HotKeyReferencesMap().end()) {
    NSCAssert(false, @"Unable to find Carbon HotKey Handler");
    return NO;
  }

  OSStatus err = _HKUnregisterHotKey(ref->second);
  if (noErr != err) {
    SPXLogError(@"error while unregistering hotkey %@ : %s", hotkey, _OSStatusToStr(err));
    return NO;
  }

  if (HKTraceHotKeyEvents)
    NSLog(@"Unregister HotKey: %@", hotkey);

  HotKeyReferencesMap().erase(ref);

  /* Remove from keys record */
  for (const auto& iter : HotKeyMap()) {
    if (iter.second == hotkey) {
      HotKeyMap().erase(iter.first);
      break;
    }
  }
  if (HotKeyReferencesMap().empty())
    _HKManagerUninstallEventHandler();
  return YES;
}

BOOL HKHotKeyUnregisterAll(void) {
  if (!HotKeyReferencesMap().empty()) {
    for (const auto& iter : HotKeyReferencesMap()) {
      _HKUnregisterHotKey(iter.second);
    }
    HotKeyReferencesMap().clear();
    HotKeyMap().clear();

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
    OSStatus err = _HKUnregisterHotKey(key);
    if (noErr != err)
      spx_log_warning("error while unregistering hot key: %d", err);
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
            long(GetEventKind(theEvent)),
            NSFileTypeForHFSTypeCode(hotKeyID.signature),
            long(hotKeyID.id));
    }
    const auto &entry = HotKeyMap().find(hotKeyID.id);
    if (entry != HotKeyMap().end()) {
      HKHotKey *hotKey = entry->second;
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
