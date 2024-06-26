/*
 *  HKHotKey.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKHotKey.h"

#import "HKKeyMap.h"
#import "HKHotKeyManager.h"

#include <IOKit/hidsystem/IOHIDLib.h>
#include <IOKit/hidsystem/IOHIDParameter.h>

@interface HKHotKey ()
- (void)hk_invalidateTimer;
- (void)hk_invoke:(NSTimer *)timer;
@end

HK_INLINE
CFTimeInterval __HKEventTime(void) {
  return SPXHostTimeToTimeInterval(SPXHostTimeGetCurrent());
}

@implementation HKHotKey {
@private
  NSTimer *_repeatTimer;

  struct _hk_hkFlags {
    unsigned int down:1;
    unsigned int lock:1;
    unsigned int repeat:1;
    unsigned int invoked:1;
    unsigned int onrelease:1;
    unsigned int registred:1;
    unsigned int reserved:26;
  } _hkFlags;
}

- (id)copyWithZone:(NSZone *)zone {
  HKHotKey *copy = [[[self class] allocWithZone:zone] init];
  copy->_actionBlock = [_actionBlock copy];

  copy->_nativeModifier = _nativeModifier;
  copy->_keycode = _keycode;
  copy->_character = _character;

  copy->_repeatTimer = nil;
  copy->_repeatInterval = _repeatInterval;

  /* Key isn't registred */
  copy->_hkFlags.onrelease = _hkFlags.onrelease;
  return copy;
}

#pragma mark -
#pragma mark Convenient constructors.
+ (id)hotkey {
  return [[self alloc] init];
}
+ (id)hotkeyWithKeycode:(HKKeycode)code modifier:(NSUInteger)modifier {
  return [[self alloc] initWithKeycode:code modifier:modifier];
}
+ (id)hotkeyWithUnichar:(UniChar)character modifier:(NSUInteger)modifier {
  return [[self alloc] initWithUnichar:character modifier:modifier];
}

#pragma mark -
#pragma mark Initializers

- (id)init {
  if (self = [super init]) {
    _character = kHKNilUnichar;
    _keycode = kHKInvalidVirtualKeyCode;
  }
  return self;
}

- (id)initWithKeycode:(HKKeycode)code modifier:(NSUInteger)modifier {
  if (self = [self init]) {
    [self setKeycode:code];
    [self setModifier:modifier];
  }
  return self;
}

- (id)initWithUnichar:(UniChar)character modifier:(NSUInteger)modifier {
  if (self = [self init]) {
    [self setModifier:modifier];
    [self setCharacter:character];
  }
  return self;
}

- (void)dealloc {
  if ([self isRegistred]) {
    spx_log("Releasing a registred hotkey is not safe !");
    [self hk_invalidateTimer];
    [self setRegistred:NO];
  }
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p> {keycode:%#x character:%#x modifier:%#x repeat:%f isRegistred:%@ }",
          [self class], self,
          [self keycode], [self character], (unsigned int)[self modifier], [self repeatInterval],
          ([self isRegistred] ? @"YES" : @"NO")];
}

#pragma mark -
#pragma mark Misc Properties

- (BOOL)isValid {
  return (self.character != kHKNilUnichar) && (self.keycode != kHKInvalidVirtualKeyCode);
}

- (NSString*)shortcut {
  return [HKKeyMap stringRepresentationForCharacter:self.character modifiers:_nativeModifier];
}

#pragma mark -
#pragma mark iVar Accessors.
HK_INLINE
void _checkNotRegistred(HKHotKey *self) {
  if ([self isRegistred])
		SPXThrowException(NSInvalidArgumentException, @"Cannot change keystroke when the receiver is registred");
}

- (NSUInteger)modifier {
  return HKModifierConvert(_nativeModifier, kHKModifierFormatNative, kHKModifierFormatCocoa);
}
- (void)setModifier:(NSUInteger)modifier {
  _checkNotRegistred(self);
  _nativeModifier = (HKModifier)HKModifierConvert(modifier, kHKModifierFormatCocoa, kHKModifierFormatNative);
}

- (void)setNativeModifier:(HKModifier)modifier {
  _checkNotRegistred(self);
  _nativeModifier = modifier;
}

- (void)setKeycode:(HKKeycode)keycode {
  _checkNotRegistred(self);
  _keycode = keycode;
  [self willChangeValueForKey:SPXProperty(character)];
  if (_keycode != kHKInvalidVirtualKeyCode)
    _character = [[HKKeyMap currentKeyMap] characterForKeycode:_keycode];
  else
    _character = kHKNilUnichar;
  [self didChangeValueForKey:SPXProperty(character)];
}

- (void)setCharacter:(UniChar)character {
  _checkNotRegistred(self);
  [self setKeycode:[[HKKeyMap currentKeyMap] keycodeForCharacter:character modifiers:NULL]];
}

- (void)setKeycode:(HKKeycode)keycode character:(UniChar)character {
  _checkNotRegistred(self);
  [self willChangeValueForKey:SPXProperty(keycode)];
  _keycode = keycode;
  [self didChangeValueForKey:SPXProperty(keycode)];
  [self willChangeValueForKey:SPXProperty(character)];
  _character = character;
  [self didChangeValueForKey:SPXProperty(character)];
}

- (BOOL)isRegistred { return _hkFlags.registred; }

- (BOOL)setRegistred:(BOOL)flag {
  if (![self isValid])
    return NO; // invalid hotkey

  flag = flag ? 1 : 0;
  if (flag == _hkFlags.registred)
    return YES; // hotkey already registred

  BOOL result = YES;
  if (flag) { // if register
    if (HKHotKeyRegister(self))
      _hkFlags.registred = 1; // Set registred flag
    else
      result = NO;
  } else { // If unregister
    [self hk_invalidateTimer];
    _hkFlags.registred = 0;
    result = HKHotKeyUnregister(self);
  }
  return result;
}

- (BOOL)invokeOnKeyUp { return _hkFlags.onrelease; }
- (void)setInvokeOnKeyUp:(BOOL)flag { SPXFlagSet(_hkFlags.onrelease, flag); }

- (NSTimeInterval)initialRepeatInterval {
  if (fiszero(_initialRepeatInterval)) {
    return HKGetSystemInitialKeyRepeatInterval();
  } else if (_initialRepeatInterval < 0) {
    return self.repeatInterval;
  }
  return _initialRepeatInterval;
}

#pragma mark Key Serialization
- (uint64_t)rawkey {
  return HKHotKeyPackKeystoke([self keycode], [self nativeModifier], [self character]);
}

- (void)setRawkey:(uint64_t)rawkey {
  HKKeycode keycode;
  UniChar character;
  HKModifier modifier;
  HKHotKeyUnpackKeystoke(rawkey, &keycode, &modifier, &character);
  [self setKeycode:keycode character:character];
  [self setNativeModifier:modifier];
}

#pragma mark -
#pragma mark Invoke
- (void)keyPressed:(NSTimeInterval)eventTime {
  _hkFlags.down = 1;
  _eventTime = eventTime;
  [self hk_invalidateTimer];
  if (_hkFlags.onrelease) {
    _hkFlags.invoked = 0;
  } else if (!_hkFlags.onrelease) {
    /* Flags used to avoid double invocation if 'on release' change during invoke */
    _hkFlags.invoked = 1;
    [self invoke:NO];
    //  may no longer be down (if release key event append during invoke)
    if (_hkFlags.down && [self repeatInterval] > 0) {
      NSTimeInterval value = [self initialRepeatInterval];
      if (value > 0) {
        value -= (__HKEventTime() - _eventTime); // time elapsed in invoke
        _repeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:value]
                                                interval:[self repeatInterval]
                                                  target:self
                                                selector:@selector(hk_invoke:)
                                                userInfo:nil
                                                 repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_repeatTimer forMode:NSRunLoopCommonModes];
      }
    }
  }
}

- (void)keyReleased:(NSTimeInterval)eventTime {
  _hkFlags.down = 0;
  _eventTime = eventTime;
  [self hk_invalidateTimer];
  if (_hkFlags.onrelease && !_hkFlags.invoked) {
    [self invoke:NO];
  }
}

- (void)invoke:(BOOL)repeat {
  if (!_hkFlags.lock) {
    SPXFlagSet(_hkFlags.repeat, repeat);
    [self willInvoke];
    _hkFlags.lock = 1;
    @try {
      if (_actionBlock)
        _actionBlock();
    } @catch (id exception) {
      spx_log_exception(exception);
    }
    _hkFlags.lock = 0;
    [self didInvoke];
    SPXFlagSet(_hkFlags.repeat, NO);
  } else {
    spx_log("Recursive call in %@", self);
    // Should we resend event ?
  }
}

- (BOOL)isARepeat { return _hkFlags.repeat; }

- (void)willInvoke {}
- (void)didInvoke {}

#pragma mark -
#pragma mark Private
- (void)hk_invalidateTimer {
  if (_repeatTimer) {
    [_repeatTimer invalidate];
    _repeatTimer = nil;
  }
}

- (void)hk_invoke:(NSTimer *)timer {
  /* get uptime in seconds (this is what carbon and cocoa event use as timestamp) */
  _eventTime = __HKEventTime();
  if (HKTraceHotKeyEvents) {
    NSLog(@"Repeat event: %@", self);
  }
  if (!_hkFlags.onrelease)
    [self invoke:YES];
}

@end

uint64_t HKHotKeyPackKeystoke(HKKeycode keycode, HKModifier modifier, UniChar chr) {
  uint64_t packed = chr;
  packed |= modifier & 0x00ff0000;
  packed |= (keycode << 24) & 0xff000000;
  return packed;
}

void HKHotKeyUnpackKeystoke(uint64_t rawkey, HKKeycode *outKeycode, HKModifier *outModifier, UniChar *outChr) {
  UniChar character = rawkey & 0x0000ffff;
  HKModifier modifier = (HKModifier)(rawkey & 0x00ff0000);
  HKKeycode keycode = (rawkey & 0xff000000) >> 24;
  if (keycode == 0xff) keycode = kHKInvalidVirtualKeyCode;
  BOOL isSpecialKey = (modifier & (kCGEventFlagMaskNumericPad | kCGEventFlagMaskSecondaryFn)) != 0;
  if (!isSpecialKey) {
    /* If key is a number (not in numpad) we use keycode, because american keyboard use number */
    if (character >= '0' && character <= '9')
      isSpecialKey = YES;
  }

  /* we should use keycode if this is a special keycode (fonction, numpad, ...).
   else we try to resolve keycode using modifier
   if conversion fail, we use keycode, and we update character */
  HKKeyMap *keymap = [HKKeyMap currentKeyMap];
  if (!isSpecialKey || (kHKInvalidVirtualKeyCode == keycode)) {
    /* update keycode to reflect character */
    HKKeycode newCode = [keymap keycodeForCharacter:character modifiers:NULL];
    if (kHKInvalidVirtualKeyCode != newCode)
      keycode = newCode;
    else
      character = [keymap characterForKeycode:keycode];
  } else {
    character = [keymap characterForKeycode:keycode];
  }
  if (outChr) *outChr = character;
  if (outKeycode) *outKeycode = keycode;
  if (outModifier) *outModifier = modifier;
}

#pragma mark -
static
io_connect_t _HKHIDGetSystemService(void) {
  static mach_port_t sSystemService = 0;
  
  if (!sSystemService) {
    mach_port_t iter;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass), &iter);
    if (KERN_SUCCESS == kr) {
      mach_port_t service = IOIteratorNext(iter);
      if (service) {
        kr = IOServiceOpen(service, mach_task_self(), kIOHIDParamConnectType, &sSystemService);
        spx_assert(KERN_SUCCESS == kr, "System service unavailable");
        IOObjectRelease(service);
      }
      IOObjectRelease(iter);
    }
  }

  return sSystemService;
}

static
NSTimeInterval _HKGetSystemKeyProperty(CFStringRef property) {
  NSTimeInterval interval = -1;
  io_connect_t service = _HKHIDGetSystemService();
  if (service) {
    CFTypeRef value = NULL;
    kern_return_t kr = IOHIDCopyCFTypeParameter(service, property, &value);
    /* convert nano into seconds */
    if (KERN_SUCCESS == kr && value != NULL) {
      double intervalNs = 0;
      if (CFNumberGetValue(value, kCFNumberDoubleType, &intervalNs))
        interval = (double)intervalNs / 1e9;
      CFRelease(value);
    }
  }
  return interval;
}

NSTimeInterval HKGetSystemKeyRepeatInterval(void) {
  return _HKGetSystemKeyProperty(CFSTR(kIOHIDKeyRepeatKey));
}

NSTimeInterval HKGetSystemInitialKeyRepeatInterval(void) {
  return _HKGetSystemKeyProperty(CFSTR(kIOHIDInitialKeyRepeatKey));
}
