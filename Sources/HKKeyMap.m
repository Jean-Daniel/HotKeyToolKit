/*
 *  HKKeyMap.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import <HotKeyToolKit/HKKeyMap.h>

#import "HKFramework.h"
#import "HKKeymapInternal.h"

#import <Carbon/Carbon.h>

#pragma mark Statics Functions Declaration
HK_INLINE
NSString *SpecialChar(UniChar ch) {
  return [NSString stringWithCharacters:&ch length:1];
}

static
HKKeycode HKMapGetSpecialKeyCodeForCharacter(UniChar charCode);
static
UniChar HKMapGetSpecialCharacterForKeycode(HKKeycode keycode);

static
NSString *HKMapGetModifierString(HKModifier mask);
static
NSString *HKMapGetSpeakableModifierString(HKModifier mask);
static
NSString *HKMapGetStringForUnichar(UniChar unicode);

// MARK: -
// MARK: HKKeyMap implementation

const UniChar kHKNilUnichar = 0xffff;

@interface HKKeyMap ()
- (void)hk_update;
- (void)hk_loadLayout;
@end

@implementation HKKeyMap {
@private
  bool _autoupdate;
  HKKeyMapContextRef _ctxt;
  TISInputSourceRef _layout;
}

HK_INLINE
void _HKKeyMapUpdate(HKKeyMap *self, bool load) {
  if (self->_autoupdate)
    [self hk_update];
  if (!self->_ctxt && load)
    [self hk_loadLayout];
}

+ (HKKeyMap *)currentKeyMap {
  static HKKeyMap *currentKeyMap = nil;
  if (!currentKeyMap) {
    currentKeyMap = [[HKKeyMap alloc] init];
    if (!currentKeyMap) {
      SPXDebug(@"Error while initializing Keyboard Map");
    } else {
      SPXDebug(@"Keyboard Map initialized");
    }
  }
  return currentKeyMap;
}

static
void _ShowTISPalette(CFStringRef name, NSString *identifier) {
  NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:
                              SPXCFToNSString(name), kTISPropertyInputSourceType,
                              kTISCategoryPaletteInputSource, kTISPropertyInputSourceCategory,
                              identifier, kTISPropertyInputSourceID, nil]; //identifier may be nil
  TISInputSourceRef src = NULL;
  // See TISCreateInputSourceList for explanation about the double call pattern.
  CFArrayRef list = TISCreateInputSourceList(SPXNSToCFDictionary(properties), false);
  if (list) {
    if (CFArrayGetCount(list) > 0)
      src = (TISInputSourceRef)CFRetain(CFArrayGetValueAtIndex(list, 0));
    CFRelease(list);
  }
  if (!src) {
    list = TISCreateInputSourceList(SPXNSToCFDictionary(properties), true);
    if (list) {
      if (CFArrayGetCount(list) > 0)
        src = (TISInputSourceRef)CFRetain(CFArrayGetValueAtIndex(list, 0));
      CFRelease(list);
    }
  }
  if (src) {
    TISSelectInputSource(src);
    CFRelease(src);
  }
}

+ (void)showKeyboardViewer {
  _ShowTISPalette(kTISTypeKeyboardViewer, nil);
}

+ (void)showCharacterPalette {
  // Passing only kTISTypeCharacterPalette returns a list with 2 input source, so we have
  // to be more specific.
  _ShowTISPalette(kTISTypeCharacterPalette, @"com.apple.CharacterPaletteIM");
}

+ (BOOL)isFunctionKey:(HKKeycode)keycode {
  UniChar chr = HKMapGetSpecialCharacterForKeycode(keycode);
  if (kHKNilUnichar != chr)
    return [self isFunctionKeyCharacter:chr];
  return NO;
}

+ (BOOL)isFunctionKeyCharacter:(UniChar)character {
  return 0xF700 <= character && character <= 0xF8FF;
}

+ (NSString *)stringRepresentationForCharacter:(UniChar)character modifiers:(HKModifier)modifiers {
  if (character && character != kHKNilUnichar) {
    NSString *str = nil;
    NSString *mod = HKMapGetModifierString(modifiers);
    if (modifiers & kCGEventFlagMaskNumericPad) {
      if (character >= '0' && character <= '9') {
        UniChar chrs[2] = { character, '*' };
        str = [NSString stringWithCharacters:chrs length:2];
      }
    }
    if ([mod length] > 0) {
      return [mod stringByAppendingString:str ? : HKMapGetStringForUnichar(character)];
    } else {
      return str ? : HKMapGetStringForUnichar(character);
    }
  }
  return nil;
}

+ (NSString *)speakableStringRepresentationForCharacter:(UniChar)character modifiers:(HKModifier)modifiers {
  if (character && character != kHKNilUnichar) {
    NSString *mod = HKMapGetSpeakableModifierString(modifiers);
    if ([mod length] > 0) {
      return [NSString stringWithFormat:@"%@ + %@", mod, HKMapGetStringForUnichar(character)];
    } else {
      return HKMapGetStringForUnichar(character);
    }
  }
  return nil;
}

- (instancetype)init {
  if (self = [super init]) {
    _autoupdate = true;
  }
  return self;
}

HK_INLINE
void _HKKeyMapResetContext(HKKeyMap *self) {
  if (self->_ctxt) {
    if (self->_ctxt->dealloc)
      self->_ctxt->dealloc(self->_ctxt);
    free(self->_ctxt);
    self->_ctxt = NULL;
  }
}

- (void)dealloc {
  _HKKeyMapResetContext(self);
  if (_layout)
    CFRelease(_layout);
}

- (NSString *)identifier {
  _HKKeyMapUpdate(self, false);
  return SPXCFToNSString(TISGetInputSourceProperty(_layout, kTISPropertyInputSourceID));
}

- (NSString *)localizedName {
  _HKKeyMapUpdate(self, false);
  return SPXCFToNSString(TISGetInputSourceProperty(_layout, kTISPropertyInputSourceLanguages));
}

- (HKKeycode)keycodeForCharacter:(UniChar)character modifiers:(HKModifier *)modifiers {
  if (kHKNilUnichar == character)
    return kHKInvalidVirtualKeyCode;
  HKKeycode key[4];
  HKModifier mod[4];
  NSUInteger cnt = 0;
  _HKKeyMapUpdate(self, true);
  if (_ctxt && _ctxt->reverseMap)
    cnt = _ctxt->reverseMap(_ctxt->data, character, key, mod, 4);
  /* if not found, or need more than 2 keystroke */
  if (!cnt || cnt > 2 || kHKInvalidVirtualKeyCode == key[0])
    return kHKInvalidVirtualKeyCode;

  /* dead key: the second keycode is space key */
  if (cnt == 2 && key[1] != kHKVirtualSpaceKey)
    return kHKInvalidVirtualKeyCode;

  if (modifiers) *modifiers = mod[0];

  return key[0];
}

- (NSUInteger)getKeycodes:(HKKeycode *)keys modifiers:(HKModifier *)modifiers
                maxLength:(NSUInteger)maxcount forCharacter:(UniChar)character {
  NSUInteger count = 0;
  if (character != kHKNilUnichar) {
    HKKeycode keycode = HKMapGetSpecialKeyCodeForCharacter(character);
    if (keycode == kHKInvalidVirtualKeyCode) {
      _HKKeyMapUpdate(self, true);
      if (_ctxt && _ctxt->reverseMap)
        count = _ctxt->reverseMap(_ctxt->data, character, keys, modifiers, maxcount);
    } else {
      count = 1;
      if (maxcount > 0) {
        if (keys) keys[0] = keycode & 0xffff;
        if (modifiers) modifiers[0] = 0;
      }
    }
  }
  return count;
}

- (UniChar)characterForKeycode:(HKKeycode)keycode {
  return [self characterForKeycode:keycode modifiers:0];
}

- (UniChar)characterForKeycode:(HKKeycode)keycode modifiers:(HKModifier)modifiers {
  UniChar unicode = !modifiers ? HKMapGetSpecialCharacterForKeycode(keycode) : kHKNilUnichar;
  if (kHKNilUnichar == unicode) {
    _HKKeyMapUpdate(self, true);
    if (_ctxt && _ctxt->map)
      unicode = _ctxt->map(_ctxt->data, keycode, modifiers);
  }
  return unicode;
}

- (void)hk_update {
  CFBooleanRef selected = TISGetInputSourceProperty(_layout, kTISPropertyInputSourceIsSelected);
  if (!selected || !CFBooleanGetValue(selected)) {
    // FIXME: we should probably use ASCII capable input source or override input source.
    TISInputSourceRef current = TISCopyCurrentKeyboardLayoutInputSource();
    if (current != _layout) { // FIXME: compare _identifier instead
      _HKKeyMapResetContext(self);
      if (_layout)
        CFRelease(_layout);
      _layout = current;
    }
  }
}

- (void)hk_loadLayout {
  OSStatus err = noErr;
  _ctxt = calloc(1, sizeof(*_ctxt));
  CFDataRef uchr = TISGetInputSourceProperty(_layout, kTISPropertyUnicodeKeyLayoutData);
  if (uchr) {
    err = HKKeyMapContextWithUchrData((const UCKeyboardLayout *)CFDataGetBytePtr(uchr), true, _ctxt);
  } else {
#if !__LP64__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    /* maybe this is kchr data only ... */
    KeyboardLayoutRef ref;
    // FIXME: should find a better way to get matching KCHR.
    err = KLGetCurrentKeyboardLayout(&ref);
    // err = KLGetKeyboardLayoutWithName(???, &ref);
    if (noErr == err) {
      const void *data = NULL;
      err = KLGetKeyboardLayoutProperty(ref, kKLKCHRData, (void *)&data);
      if (noErr == err)
        err = HKKeyMapContextWithKCHRData(data, true, _ctxt);
    }
    if (noErr != err) {
      spx_log_error("Error while trying to get layout data: %s", GetMacOSStatusErrorString(err));
    }
#pragma clang diagnostic pop
#else
    spx_log_warning("No UCHR data found and 64 bits does not support KCHR.");
    err = paramErr;
#endif
  }
  if (noErr != err)
    memset(_ctxt, 0, sizeof(*_ctxt));
}

@end

#pragma mark -
#pragma mark Statics Functions Definition
HKKeycode HKMapGetSpecialKeyCodeForCharacter(UniChar character) {
  switch (character) {
      /* functions keys */
    case kHKF1Unicode:
      return kHKVirtualF1Key;
    case kHKF2Unicode:
      return kHKVirtualF2Key;
    case kHKF3Unicode:
      return kHKVirtualF3Key;
    case kHKF4Unicode:
      return kHKVirtualF4Key;
      /* functions keys */
    case kHKF5Unicode:
      return kHKVirtualF5Key;
    case kHKF6Unicode:
      return kHKVirtualF6Key;
    case kHKF7Unicode:
      return kHKVirtualF7Key;
    case kHKF8Unicode:
      return kHKVirtualF8Key;
      /* functions keys */
    case kHKF9Unicode:
      return kHKVirtualF9Key;
    case kHKF10Unicode:
      return kHKVirtualF10Key;
    case kHKF11Unicode:
      return kHKVirtualF11Key;
    case kHKF12Unicode:
      return kHKVirtualF12Key;
      /* functions keys */
    case kHKF13Unicode:
      return kHKVirtualF13Key;
    case kHKF14Unicode:
      return kHKVirtualF14Key;
    case kHKF15Unicode:
      return kHKVirtualF15Key;
    case kHKF16Unicode:
      return kHKVirtualF16Key;
      /* aluminium keyboard */
    case kHKF17Unicode:
      return kHKVirtualF17Key;
    case kHKF18Unicode:
      return kHKVirtualF18Key;
    case kHKF19Unicode:
      return kHKVirtualF19Key;
//    case kHKF20Unicode: return ;
//    case kHKF21Unicode: return ;
//    case kHKF22Unicode: return ;
//    case kHKF23Unicode: return ;
//    case kHKF24Unicode: return ;
//    case kHKF25Unicode: return ;
//    case kHKF26Unicode: return ;
//    case kHKF27Unicode: return ;
//    case kHKF28Unicode: return ;
//    case kHKF29Unicode: return ;
//    case kHKF30Unicode: return ;
//    case kHKF31Unicode: return ;
//    case kHKF32Unicode: return ;
//    case kHKF33Unicode: return ;
//    case kHKF34Unicode: return ;
//    case kHKF35Unicode: return ;
      /* editing utility keys */
    case kHKHelpUnicode:
      return kHKVirtualHelpKey;
//    case kHKInsertUnicode:
//      return ;
    case kHKDeleteUnicode:
      return kHKVirtualDeleteKey;
    case kHKTabUnicode:
      return kHKVirtualTabKey;
    case kHKEnterUnicode:
      return kHKVirtualEnterKey;
    case kHKReturnUnicode:
      return kHKVirtualReturnKey;
    case kHKEscapeUnicode:
      return kHKVirtualEscapeKey;
    case kHKForwardDeleteUnicode:
      return kHKVirtualForwardDeleteKey;
      /* navigation keys */
    case kHKHomeUnicode:
      return kHKVirtualHomeKey;
//    case kHKBeginUnicode:
//      return ;
    case kHKEndUnicode:
      return kHKVirtualEndKey;
    case kHKPageUpUnicode:
      return kHKVirtualPageUpKey;
    case kHKPageDownUnicode:
      return kHKVirtualPageDownKey;
    case kHKLeftArrowUnicode:
      return kHKVirtualLeftArrowKey;
    case kHKRightArrowUnicode:
      return kHKVirtualRightArrowKey;
    case kHKUpArrowUnicode:
      return kHKVirtualUpArrowKey;
    case kHKDownArrowUnicode:
      return kHKVirtualDownArrowKey;
    case kHKClearLineUnicode:
      return kHKVirtualClearLineKey;
    case kHKNoBreakSpaceUnicode:
      return kHKVirtualSpaceKey;
  }
  return kHKInvalidVirtualKeyCode;
}

UniChar HKMapGetSpecialCharacterForKeycode(HKKeycode keycode) {
  switch (keycode) {
    case kHKInvalidVirtualKeyCode: return kHKNilUnichar;
      /* functions keys */
    case kHKVirtualF1Key: return kHKF1Unicode;
    case kHKVirtualF2Key: return kHKF2Unicode;
    case kHKVirtualF3Key: return kHKF3Unicode;
    case kHKVirtualF4Key: return kHKF4Unicode;
      /* functions keys */
    case kHKVirtualF5Key: return kHKF5Unicode;
    case kHKVirtualF6Key: return kHKF6Unicode;
    case kHKVirtualF7Key: return kHKF7Unicode;
    case kHKVirtualF8Key: return kHKF8Unicode;
      /* functions keys */
    case kHKVirtualF9Key:  return kHKF9Unicode;
    case kHKVirtualF10Key: return kHKF10Unicode;
    case kHKVirtualF11Key: return kHKF11Unicode;
    case kHKVirtualF12Key: return kHKF12Unicode;
      /* functions keys */
    case kHKVirtualF13Key: return kHKF13Unicode;
    case kHKVirtualF14Key: return kHKF14Unicode;
    case kHKVirtualF15Key: return kHKF15Unicode;
    case kHKVirtualF16Key: return kHKF16Unicode;
      /* aluminium keyboard */
    case kHKVirtualF17Key: return kHKF17Unicode;
    case kHKVirtualF18Key: return kHKF18Unicode;
    case kHKVirtualF19Key: return kHKF19Unicode;
      /* editing utility keys */
    case kHKVirtualHomeKey:          return kHKHomeUnicode;
    case kHKVirtualEndKey:           return kHKEndUnicode;
    case kHKVirtualPageUpKey:        return kHKPageUpUnicode;
    case kHKVirtualPageDownKey:      return kHKPageDownUnicode;
    case kHKVirtualHelpKey:          return kHKHelpUnicode;
    case kHKVirtualForwardDeleteKey: return kHKForwardDeleteUnicode;
      /* navigation keys */
    case kHKVirtualLeftArrowKey:  return kHKLeftArrowUnicode;
    case kHKVirtualRightArrowKey: return kHKRightArrowUnicode;
    case kHKVirtualUpArrowKey:    return kHKUpArrowUnicode;
    case kHKVirtualDownArrowKey:  return kHKDownArrowUnicode;
      /* special num-pad key */
    case kHKVirtualClearLineKey:  return kHKClearLineUnicode;
      /* key with special representation */
    case kHKVirtualEnterKey:  return kHKEnterUnicode;
    case kHKVirtualTabKey:    return kHKTabUnicode;
    case kHKVirtualReturnKey: return kHKReturnUnicode;
    case kHKVirtualDeleteKey: return kHKDeleteUnicode;
    case kHKVirtualEscapeKey: return kHKEscapeUnicode;
  }
  return kHKNilUnichar;
}

#pragma mark String representation
NSString* HKMapGetModifierString(HKModifier mask) {
  UniChar modifier[5];
  UniChar *symbol = modifier;
  if (kCGEventFlagMaskAlphaShift & mask) {
    *(symbol++) = 0x21ea; // Caps lock
  }
  if (kCGEventFlagMaskControl & mask) {
    *(symbol++) = 0x2303; // kControlUnicode;
  }
  if (kCGEventFlagMaskAlternate & mask) {
    *(symbol++) = 0x2325; // kOptionUnicode
  }
  if (kCGEventFlagMaskShift & mask) {
    *(symbol++) = 0x21E7; // kShiftUnicode
  }
  if (kCGEventFlagMaskCommand & mask) {
    *(symbol++) = 0x2318; // kCommandUnicode
  }
  NSString *result = symbol - modifier > 0 ? [NSString stringWithCharacters:modifier length:symbol - modifier] : nil;
  return result;
}

NSString* HKMapGetSpeakableModifierString(HKModifier mask) {
  NSMutableString *str = mask ? [[NSMutableString alloc] init] : nil;
  NSBundle *bundle = [HotKeyToolKitFramework bundle];
  if (kCGEventFlagMaskAlphaShift & mask) {
    [str appendString:NSLocalizedStringFromTableInBundle(@"Caps Lock", @"Keyboard", bundle, @"Speakable Caps Lock Modifier")];
  }
  if (kCGEventFlagMaskControl & mask) {
    if ([str length])
      [str appendString:@" + "];
    [str appendString:NSLocalizedStringFromTableInBundle(@"Control", @"Keyboard", bundle, @"Speakable Control Modifier")];
  }
  if (kCGEventFlagMaskAlternate & mask) {
    if ([str length])
      [str appendString:@" + "];
    [str appendString:NSLocalizedStringFromTableInBundle(@"Option", @"Keyboard", bundle, @"Speakable Option Modifier")];
  }
  if (kCGEventFlagMaskShift & mask) {
    if ([str length])
      [str appendString:@" + "];
    [str appendString:NSLocalizedStringFromTableInBundle(@"Shift", @"Keyboard", bundle, @"Speakable Shift Modifier")];
  }
  if (kCGEventFlagMaskCommand & mask) {
    if ([str length])
      [str appendString:@" + "];
    [str appendString:NSLocalizedStringFromTableInBundle(@"Command", @"Keyboard", bundle, @"Speakable Command Modifier")];
  }
  return str;
}

NSString *HKMapGetStringForUnichar(UniChar character) {
  NSString *str = nil;
  if (kHKNilUnichar == character)
    return str;
  NSBundle *bundle = [HotKeyToolKitFramework bundle];
  switch (character) {
    case kHKF1Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F1", @"Keyboard", bundle, @"F1 Key display String");
      break;
    case kHKF2Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F2", @"Keyboard", bundle, @"F2 Key display String");
      break;
    case kHKF3Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F3", @"Keyboard", bundle, @"F3 Key display String");
      break;
    case kHKF4Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F4", @"Keyboard", bundle, @"F4 Key display String");
      break;
      /* functions Unicodes */
    case kHKF5Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F5", @"Keyboard", bundle, @"F5 Key display String");
      break;
    case kHKF6Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F6", @"Keyboard", bundle, @"F6 Key display String");
      break;
    case kHKF7Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F7", @"Keyboard", bundle, @"F7 Key display String");
      break;
    case kHKF8Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F8", @"Keyboard", bundle, @"F8 Key display String");
      break;
      /* functions Unicodes */
    case kHKF9Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F9", @"Keyboard", bundle, @"F9 Key display String");
      break;
    case kHKF10Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F10", @"Keyboard", bundle, @"F10 Key display String");
      break;
    case kHKF11Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F11", @"Keyboard", bundle, @"F11 Key display String");
      break;
    case kHKF12Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F12", @"Keyboard", bundle, @"F12 Key display String");
      break;
      /* functions Unicodes */
    case kHKF13Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F13", @"Keyboard", bundle, @"F13 Key display String");
      break;
    case kHKF14Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F14", @"Keyboard", bundle, @"F14 Key display String");
      break;
    case kHKF15Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F15", @"Keyboard", bundle, @"F15 Key display String");
      break;
    case kHKF16Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F16", @"Keyboard", bundle, @"F16 Key display String");
      break;
      /* aluminium keyboard */
    case kHKF17Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F17", @"Keyboard", bundle, @"F17 Key display String");
      break;
    case kHKF18Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F18", @"Keyboard", bundle, @"F18 Key display String");
      break;
    case kHKF19Unicode:
      str = NSLocalizedStringFromTableInBundle(@"F19", @"Keyboard", bundle, @"F19 Key display String");
      break;
      /* editing utility Unicodes */
    case kHKHelpUnicode:
      str = NSLocalizedStringFromTableInBundle(@"help", @"Keyboard", bundle, @"Help Key display String");
      break;
    case ' ':
      str = NSLocalizedStringFromTableInBundle(@"spc", @"Keyboard", bundle, @"Space Key display String");
      break;
      /* Special Chars */
    case kHKDeleteUnicode:
      character = 0x232b;
      break;
    case kHKTabUnicode:
      character = 0x21e5;
      break;
    case kHKEnterUnicode:
      character = 0x2305;
      break;
    case kHKReturnUnicode:
      character = 0x21a9;
      break;
    case kHKEscapeUnicode:
      character = 0x238b;
      break;
    case kHKForwardDeleteUnicode:
      character = 0x2326;
      break;
      /* navigation keys */
    case kHKHomeUnicode:
      character = 0x2196;
      break;
    case kHKEndUnicode:
      character = 0x2198;
      break;
    case kHKPageUpUnicode:
      character = 0x21de;
      break;
    case kHKPageDownUnicode:
      character = 0x21df;
      break;
    case kHKLeftArrowUnicode:
      character = 0x21e0;
      break;
    case kHKUpArrowUnicode:
      character = 0x21e1;
      break;
    case kHKRightArrowUnicode:
      character = 0x21e2;
      break;
    case kHKDownArrowUnicode:
      character = 0x21e3;
      break;
      /* others Unicodes */
    case kHKClearLineUnicode:
      character = 0x2327;
      break;
  }
  if (!str)
    // Choose uppercase variant for ASCII chars (that's how they are shown on the keyboard).
    str = (character <= 127) ? [SpecialChar(character) uppercaseString] : SpecialChar(character);
  return str;
}
