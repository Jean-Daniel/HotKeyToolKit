/*
 *  HKKeymapInternal.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import <HotKeyToolKit/HKBase.h>

typedef struct __HKKeyMapContext HKKeyMapContext;

typedef UniChar (*HKCharacterForKeyCodeFunction)(void *ctxt, HKKeycode keycode, HKModifier modifier);
typedef NSUInteger (*HKKeycodesForCharacterFunction)(void *ctxt, UniChar character, HKKeycode *keys, HKModifier *modifiers, NSUInteger maxsize);
typedef void (*HKContextDealloc)(HKKeyMapContext *ctxt);

struct __HKKeyMapContext {
  void *data;
  HKContextDealloc dealloc;
  HKCharacterForKeyCodeFunction map;
  HKKeycodesForCharacterFunction reverseMap;
};

HK_PRIVATE
OSStatus HKKeyMapContextWithUchrData(const UCKeyboardLayout *layout, bool reverse, HKKeyMapContext *ctxt);

#if !__LP64__
HK_PRIVATE
OSStatus HKKeyMapContextWithKCHRData(const void *layout, bool reverse, HKKeyMapContext *ctxt);
#endif /* __LP64__ */
