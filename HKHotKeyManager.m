//
//  HotKeyManager.m
//  Short-Cut
//
//  Created by Fox on Sat Nov 29 2003.
//  Copyright (c) 2004 Shadow Lab. All rights reserved.
//

#import "HKKeyMap.h"

#import "HKHotKey.h"

#include <Carbon/Carbon.h>

#import "HKHotKeyManager.h"
#import "HKHotKeyRegister.h"

static const OSType kHKHotKeyEventSignature = 'HkTk';

static OSStatus HandleHotKeyEvent(EventHandlerCallRef nextHandler,EventRef theEvent,void *userData);

BOOL HKTraceHotKeyEvents = NO;

@interface HKHotKeyManager (Private)
- (void)_hotKeyReleased:(HKHotKey *)key;
- (void)_hotKeyPressed:(HKHotKey *)key;
- (OSStatus)handleCarbonEvent:(EventRef)theEvent;
@end

@implementation HKHotKeyManager

static EventHandlerUPP kHKHandlerUPP = NULL;
+ (void)initialize {
  if ([HKHotKeyManager class] == self) {
    kHKHandlerUPP = NewEventHandlerUPP(HandleHotKeyEvent);
  }
}

+ (HKHotKeyManager *)sharedManager {
  static id sharedManager = nil;
  @synchronized (self) {
    if (!sharedManager) {
      sharedManager = [[self alloc] init];
    }
  }
  return sharedManager;
}

- (id)init {
  if (self = [super init]) {
    EventHandlerRef ref;
    EventTypeSpec eventTypes[2];

    eventTypes[0].eventClass = kEventClassKeyboard;
    eventTypes[0].eventKind  = kEventHotKeyPressed;

    eventTypes[1].eventClass = kEventClassKeyboard;
    eventTypes[1].eventKind  = kEventHotKeyReleased;
    
    if (noErr != InstallApplicationEventHandler(kHKHandlerUPP, 2, eventTypes, self, &ref)) {
      [self release];
      self = nil;
    } else {
      hk_handler = ref;
      hk_keys = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
    }
  }
  return self;
}

- (void)dealloc {
  [self unregisterAll];
  if (hk_keys) NSFreeMapTable(hk_keys);
  if (hk_handler) RemoveEventHandler(hk_handler);
  [super dealloc];
}

- (BOOL)registerHotKey:(HKHotKey *)key {
  // Si la cle est valide est non enregistr�
  if ([key isValid] && !NSMapGet(hk_keys, key)) {
    UInt32 mask = [key modifier];
    UInt32 keycode = [key keycode];
    DLog(@"%@ Code: %i, mask: %x, character: %C", NSStringFromSelector(_cmd), keycode, mask, [key character]);
    EventHotKeyID hotKeyId = {kHKHotKeyEventSignature, (unsigned)key};
    EventHotKeyRef ref = HKRegisterHotKey(keycode, mask, hotKeyId);
    if (ref) {
      NSMapInsert(hk_keys, key, ref);
      return YES;
    }
  }
  return NO;
}

- (BOOL)unregisterHotKey:(HKHotKey *)key {
  if ([key isRegistred]) {
    EventHotKeyRef ref = NSMapGet(hk_keys, key);
    NSAssert(ref != nil, @"Unable to find Carbon HotKey Handler");
    
    BOOL result = (ref) ? HKUnregisterHotKey(ref) : NO;
    
    NSMapRemove(hk_keys, key);
    return result;
  }
  return NO;
}

- (void)unregisterAll {
  void *key = nil;
  EventHotKeyRef ref = NULL;
  
  NSMapEnumerator refs = NSEnumerateMapTable(hk_keys);
  while (NSNextMapEnumeratorPair(&refs, &key, (void **)&ref)) {
    if (ref)
      HKUnregisterHotKey(ref);
  }
  NSResetMapTable(hk_keys);
}

- (OSStatus)handleCarbonEvent:(EventRef)theEvent {
  OSStatus err;
  EventHotKeyID hotKeyID;
  HKHotKey* hotKey;
  
  NSAssert(GetEventClass(theEvent) == kEventClassKeyboard, @"Unknown event class");
  
  err = GetEventParameter(theEvent,
                          kEventParamDirectObject, 
                          typeEventHotKeyID,
                          nil,
                          sizeof(EventHotKeyID),
                          nil,
                          &hotKeyID );
  if(noErr == err) {
    NSAssert(hotKeyID.signature == kHKHotKeyEventSignature, @"Invalid hot key signature");
    NSAssert(hotKeyID.id != nil, @"Invalid hot key id");
    
    if (HKTraceHotKeyEvents) {
      NSLog(@"HKManagerEvent {class:%@ kind:%i signature:%@ id:%p }",
            NSFileTypeForHFSTypeCode(GetEventClass(theEvent)),
            GetEventKind(theEvent),
            NSFileTypeForHFSTypeCode(hotKeyID.signature),
            hotKeyID.id);
    }
    
    hotKey = (HKHotKey*)hotKeyID.id;
    
    switch(GetEventKind(theEvent)) {
      case kEventHotKeyPressed:
        [self _hotKeyPressed:hotKey];
        break;
      case kEventHotKeyReleased:
        [self _hotKeyReleased:hotKey];
        break;
      default:
        NSAssert(NO, @"Unknown event kind");
        break;
    }
  }
  return err;
}

- (void)_hotKeyPressed:(HKHotKey *)key {
  [key keyPressed];
}
- (void)_hotKeyReleased:(HKHotKey *)key {
  [key keyReleased];
}

#pragma mark Filter Support
static HKHotKeyFilter _filter;

+ (void)setShortcutFilter:(HKHotKeyFilter)filter {
  _filter = filter;
}

#pragma mark -
+ (BOOL)isValidHotKeyCode:(UInt32)code withModifier:(UInt32)modifier {
  BOOL isValid = YES;
  // Si un filtre est utilis�, on l'utilise.
  if (_filter != nil) {
    isValid = (*_filter)(code, modifier);
  }
  if (isValid) {
    // Si le filtre est OK, on demande au system ce qu'il en pense.
    EventHotKeyID hotKeyId = {'Test', 0};
    @synchronized (self) {
      EventHotKeyRef key = HKRegisterHotKey(code, modifier, hotKeyId);
      if (key) {
        // Si le syst�me est OK, la cl�e est valide
        HKUnregisterHotKey(key);
      }
      else {
        // Sinon elle est invalide.
        isValid = NO;
      }
    }
  }
  return isValid;
}

@end

#pragma mark -
#pragma mark Carbon Event Handler
OSStatus HandleHotKeyEvent(EventHandlerCallRef nextHandler,EventRef theEvent,void *userData) {
  return [(id)userData handleCarbonEvent:theEvent];
}
