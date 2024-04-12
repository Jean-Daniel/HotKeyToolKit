/*
 *  HKKeymapInternal.h
 *  HotKeyToolKit
 *
 *  Copyright © 2004 - 2024 Jean-Daniel Dupas. All rights reserved.
 */

#import <HotKeyToolKit/HKBase.h>

typedef struct __HKKeyMapContext HKKeyMapContext;

HK_PRIVATE
HKKeyMapContext *HKKeyMapContextCreateWithUchrData(CFDataRef uchr);

HK_PRIVATE
UniChar HKCharacterForKeyCodeFunction(HKKeyMapContext *ctxt, HKKeycode keycode, HKModifier modifier);

HK_PRIVATE
NSUInteger HKKeycodesForCharacterFunction(HKKeyMapContext *ctxt, UniChar character, HKKeycode *keys, HKModifier *modifiers, NSUInteger maxsize);

HK_PRIVATE
void HKKeyMapContextDealloc(HKKeyMapContext *ctxt);
