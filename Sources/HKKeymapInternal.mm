/*
 *  HKKeymapInternal.c
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import "HKKeymapInternal.h"

#include <Carbon/Carbon.h>
#include <unordered_map>

#import "HKKeyMap.h"

#pragma mark Flat and deflate
/* Flat format:
-----------------------------------------------------------------
| dead state (14 bits) | modifiers (10 bits) | keycode (8 bits) |
-----------------------------------------------------------------
Note: keycode = 0xff => keycode is 0.
*/

HK_INLINE
uint32_t __HKUtilsFlatKey(HKKeycode code, HKModifier modifier, UInt32 dead) {
  spx_assert(code < 128, "invalid value");
  /* We change keycode 0 to 0xff, so the return value is never 0, as flat == 0 mean invalid */
  /* modifier: modifier use only 16 high bits and 0x3ff00 is 0x3ff << 8 */
  return ((code ? : 0xff) & 0xff) | ((modifier >> 8) & 0x3ff00) | (dead & 0x3fff) << 18;
}
HK_INLINE
uint32_t __HKUtilsFlatDead(uint32_t flat, UInt32 dead) {
  return (flat & 0x3ffff) | ((dead & 0x3fff) << 18);
}
HK_INLINE
void __HKUtilsDeflatKey(uint32_t flat, HKKeycode *code, HKModifier *modifier, uint16_t *dead) {
  if (code) {
    *code = flat & 0xff;
    if (*code == 0xff) *code = 0;
  }
  if (modifier) *modifier = (HKModifier)(flat & 0x3ff00) << 8;
  if (dead) *dead = (flat >> 18) & 0x3fff;
}


HK_INLINE
void __HKUtilsNormalizeEndOfLine(std::unordered_map<uint16_t, uint32_t> &map) {
  /* Patch to correctly handle new line */
  HKKeycode mack = 0; HKModifier macm = 0; uint16_t macd = 0;
  auto mac = map.find('\r');
  if (mac != map.end())
    __HKUtilsDeflatKey(mac->second, &mack, &macm, &macd);

  HKKeycode unixk = 0; HKModifier unixm = 0; uint16_t unixd = 0;
  auto unix = map.find('\n');
  if (unix != map.end())
    __HKUtilsDeflatKey(unix->second, &unixk, &unixm, &unixd);

  /* If 'mac return' use modifier or dead key and unix not */
  if ((mac == map.end() || macm || macd) && (unix != map.end() && !unixm && !unixd)) {
    map['\r'] = unix->second;
  } else if ((unix == map.end() || unixm || unixd) && (mac != map.end() && !macm && !macd)) {
    map['\n'] = mac->second;
  }
}

#pragma mark Modifiers
enum {
  kCommandKey = 1 << 0,
  kShiftKey = 1 << 1,
  kCapsKey = 1 << 2,
  kOptionKey = 1 << 3,
  kControlKey = 1 << 4,
  kRightShiftKey = 1 << 5,
  kRightOptionKey = 1 << 6,
  kRightControlKey = 1 << 7,
};

HK_INLINE
UInt32 __GetModifierCount(NSUInteger idx) {
  UInt32 count = 0;
  if (idx & kCommandKey) count++;
  if (idx & kShiftKey) count++;
  if (idx & kCapsKey) count++;
  if (idx & kOptionKey) count++;
  if (idx & kControlKey) count++;
  if (idx & kRightShiftKey) count++;
  if (idx & kRightOptionKey) count++;
  if (idx & kRightControlKey) count++;
  return count;
}

HK_INLINE
UInt32 __GetNativeModifierCount(HKModifier idx) {
  UInt32 count = 0;
  if (idx & kCGEventFlagMaskShift) count++;
  if (idx & kCGEventFlagMaskControl) count++;
  if (idx & kCGEventFlagMaskCommand) count++;
  if (idx & kCGEventFlagMaskAlternate) count++;
  if (idx & kCGEventFlagMaskAlphaShift) count++;
  return count;
}

static
void __HKUtilsConvertModifiers(uint32_t *mods, NSInteger count) {
  while (count-- > 0) {
    HKModifier modifier = 0;
    if (mods[count] & kCommandKey) modifier |= kCGEventFlagMaskCommand;
    if (mods[count] & kShiftKey) modifier |= kCGEventFlagMaskShift;
    if (mods[count] & kCapsKey) modifier |= kCGEventFlagMaskAlphaShift;
    if (mods[count] & kOptionKey) modifier |= kCGEventFlagMaskAlternate;
    if (mods[count] & kControlKey) modifier |= kCGEventFlagMaskControl;
    /* Should not append */
    if (mods[count] & kRightShiftKey) modifier |= kCGEventFlagMaskShift;
    if (mods[count] & kRightOptionKey) modifier |= kCGEventFlagMaskAlternate;
    if (mods[count] & kRightControlKey) modifier |= kCGEventFlagMaskControl;

    mods[count] = modifier;
  }
}

#pragma mark -
#pragma mark UCHR
typedef struct __HKKeyMapContext {
  CFDataRef uchr;
  UniChar map[128];
  std::unordered_map<uint16_t, uint32_t> chars;
  std::unordered_map<uint16_t, uint32_t> stats;
  const UCKeyboardLayout *layout;
} HKKeyMapContext;

static
UniChar UchrCharacterForKeyCodeAndKeyboard(const UCKeyboardLayout *layout, HKKeycode keycode, HKModifier modifiers) {
  UniChar string[3];
  SInt32 type = LMGetKbdType();
  UInt32 deadKeyState = 0;
  UniCharCount stringLength = 0;
  UInt32 ucModifiers = (UInt32)(HKModifierConvert(modifiers, kHKModifierFormatNative, kHKModifierFormatCarbon) >> 8) & 0xff;
  OSStatus err = UCKeyTranslate (layout,
                                 keycode, kUCKeyActionDown, ucModifiers,
                                 type, 0, &deadKeyState,
                                 3, &stringLength, string);
  if (noErr == err) {
    if (stringLength == 0 && deadKeyState != 0) {
      UCKeyTranslate (layout,
                      kHKVirtualSpaceKey , kUCKeyActionDown, 0, // => No Modifier
                      type, kUCKeyTranslateNoDeadKeysMask, &deadKeyState,
                      3, &stringLength, string);
    }
    if (stringLength > 0) {
      return string[0];
    }
  }
  return kHKNilUnichar;
}

UniChar HKCharacterForKeyCodeFunction(HKKeyMapContext *ctxt, HKKeycode keycode, HKModifier modifiers) {
  // fast path (does not works for dead key)
  if (!modifiers && keycode < 128 && ctxt->map[keycode] != kHKNilUnichar)
    return ctxt->map[keycode];
  return UchrCharacterForKeyCodeAndKeyboard(ctxt->layout, keycode, modifiers);
}

NSUInteger HKKeycodesForCharacterFunction(HKKeyMapContext *ctxt, UniChar character, HKKeycode *keys, HKModifier *modifiers, NSUInteger maxsize) {
  NSUInteger count = 0;
  NSUInteger limit = 10;
  HKKeycode ikeys[10];
  HKModifier imodifiers[10];

  uint16_t d = 0;
  HKKeycode k = 0;
  HKModifier m = 0;
  auto iter = ctxt->chars.find(character);
  if (iter == ctxt->chars.end())
    return 0;

  uint32_t flat = iter->second;
  while (flat && count < limit) {
    __HKUtilsDeflatKey(flat, &k, &m, &d);
    ikeys[count] = k;
    imodifiers[count] = m;
    count++;
    if (d) {
      auto siter = ctxt->stats.find(d);
      if (siter != ctxt->stats.end())
        flat = siter->second;
      else
        flat = 0;
    } else {
      flat = 0;
    }
  }
  NSUInteger idx = 0;
  while (idx < count && idx < maxsize) {
    keys[idx] = ikeys[count - idx - 1];
    modifiers[idx] = imodifiers[count - idx - 1];
    idx++;
  }
  return count;
}

void HKKeyMapContextDealloc(HKKeyMapContext *ctxt) {
  if (ctxt->uchr)
    CFRelease(ctxt->uchr);
  delete ctxt;
}

HK_INLINE
const UCKeyboardTypeHeader *__UCKeyboardHeaderForCurrentKeyboard(const UCKeyboardLayout* layout) {
  NSUInteger idx = 0;
  UInt8 kbType = LMGetKbdType();
  const UCKeyboardTypeHeader *head = layout->keyboardTypeList;
  while (idx < layout->keyboardTypeCount) {
    if (layout->keyboardTypeList[idx].keyboardTypeFirst <= kbType && layout->keyboardTypeList[idx].keyboardTypeLast >= kbType) {
      head = &layout->keyboardTypeList[idx];
      break;
    }
    idx++;
  }
  return head;
}

#pragma mark -
HK_INLINE
bool __HKUCHROutputIsStateRecord(UCKeyOutput output) {
  return (output & (1 << 14)) == (1 << 14);
}
HK_INLINE
bool __HKUCHROutputIsSequence(UCKeyOutput output) {
  return (output & (1 << 15)) == (1 << 15);
}
HK_INLINE
bool __HKUCHROutputIsInvalid(UCKeyOutput output) {
  return output >= 0xfffe;
}
HK_INLINE
bool __HKUCHRKeyCharIsSequence(UCKeyCharSeq output) {
  return (output & (1 << 15)) == (1 << 15);
}

HK_INLINE
bool __HKMapInsertIfBetter(std::unordered_map<uint16_t, uint32_t> &table, uint16_t key, HKKeycode code, HKModifier modifier, UInt32 dead) {
  auto res = table.try_emplace(key, __HKUtilsFlatKey(code, modifier, dead));
  if (res.second) // if this was a new entry -> we are done
    return true;

  /* retreive previous modifier */
  HKModifier m = 0;
  __HKUtilsDeflatKey(res.first->second, NULL, &m, NULL);
  /* if new modifier uses less key than the previous one */
  if (__GetNativeModifierCount(modifier) < __GetNativeModifierCount(m)) {
    /* replace previous record */
    res.first->second = __HKUtilsFlatKey(code, modifier, dead);
    return true;
  }

  return false;
}

HKKeyMapContext *HKKeyMapContextCreateWithUchrData(CFDataRef uchr) {
  HKKeyMapContext *ctxt = new HKKeyMapContext();
  ctxt->uchr = uchr;
  CFRetain(uchr);

  ctxt->layout = reinterpret_cast<const UCKeyboardLayout *>(CFDataGetBytePtr(uchr));
  /* set nil unichar in all blocks */
  memset(ctxt->map, 0xff, sizeof(ctxt->map));

  // Load table and reverse table
  const uint8_t *data = reinterpret_cast<const uint8_t *>(ctxt->layout);
  const UCKeyboardTypeHeader *header = __UCKeyboardHeaderForCurrentKeyboard(ctxt->layout);
  const UCKeyToCharTableIndex *tables = reinterpret_cast<const UCKeyToCharTableIndex *>(data + header->keyToCharTableIndexOffset);
  const UCKeyModifiersToTableNum *modifiers = reinterpret_cast<const UCKeyModifiersToTableNum *>(data + header->keyModifiersToTableNumOffset);
  /* optionals */
  const UCKeyStateRecordsIndex *records = reinterpret_cast<const UCKeyStateRecordsIndex *>(header->keyStateRecordsIndexOffset ? data + header->keyStateRecordsIndexOffset : NULL);
  // TODO: improve sequence support
  // const UCKeySequenceDataIndex *sequences = header->keySequenceDataIndexOffset ? data + header->keySequenceDataIndexOffset : NULL;
  // const UCKeyStateTerminators * terminators = reinterpret_cast<const UCKeyStateTerminators *>(header->keyStateTerminatorsOffset ? data + header->keyStateTerminatorsOffset : NULL);

  /* Computer Table to modifiers map */
  uint32_t tmod[tables->keyToCharTableCount];
  memset(tmod, 0xff, tables->keyToCharTableCount * sizeof(*tmod));

  /* idx is a modifier combination */
  for (uint8_t idx = 0; idx < 255; idx++) { // 255 modifiers combinations.
    /* chars table that corresponds to the 'idx' modifier combination */
    uint16_t table = idx < modifiers->modifiersCount ? modifiers->tableNum[idx] : modifiers->defaultTableNum;
    /* check table overflow */
    if (table < tables->keyToCharTableCount) {
      /* If the modifier 'idx' use less keys than the one already set to access 'table', we choose it. */
      if (__GetModifierCount(tmod[table]) > __GetModifierCount(idx))
          tmod[table] = idx;
    } else {
      /* Table overflow, should not append but does it on french keymap (and already did it in KCHR)  */
      spx_log("Invalid Keyboard layout, table %u does not exists for modifier: %0x", table, idx);
    }
  }
  __HKUtilsConvertModifiers(tmod, tables->keyToCharTableCount);

  /* Deadr is a temporary map that map deadkey record index to keycode */
  std::unordered_map<uint16_t, uint32_t> deadr = std::unordered_map<uint16_t, uint32_t>();

  /* Foreach key in each table */
  for (NSUInteger idx = 0; idx < tables->keyToCharTableCount; idx++) {
    CGKeyCode key = 0;
    const UCKeyOutput *output = reinterpret_cast<const UCKeyOutput *>(data + tables->keyToCharTableOffsets[idx]);
    while (key < tables->keyToCharTableSize) {
      if (__HKUCHROutputIsInvalid(output[key])) {
        // Illegal character => no output, skip it
      } else if (__HKUCHROutputIsSequence(output[key])) {
        // Sequence record. Useless for reverse mapping, so ignore it
//        NSUInteger seq = output[key] & 0x3fff;
//        if (sequences && seq < sequences->charSequenceCount) {
//          // Maybe check if sequence contains only one char.
//
//        }
      } else if (__HKUCHROutputIsStateRecord(output[key])) { // if "State Record", save it into deadr table
        uint16_t keyState = output[key] & 0x3fff;
        // deadr contains as key the state record, and as value, the keystroke we have to use to "produce" this state.
        __HKMapInsertIfBetter(deadr, keyState, (HKKeycode)key, (HKModifier)tmod[idx], 0);

        /* for table without modifiers only, save the record into the fast map */
        // FIXME: broken: should set it to first key of the sequence, not on terminator key
#if 0
        if (tmod[idx] == 0 && key < 128) {
          /* check if there is a terminator for this key */
          if (keyState >= 0 && terminators && keyState < terminators->keyStateTerminatorCount) {
            UCKeyCharSeq unicode = terminators->keyStateTerminators[keyState];
            if (__HKUCHRKeyCharIsSequence(unicode)) {
              // Sequence
              unicode = kHKNilUnichar;
            }
            ctxt->map[key] = unicode;
          } else {
            // no terminator, set it to nil as we will check the dead state records later
            ctxt->map[key] = kHKNilUnichar;
          }
        }
#endif
      } else {
        __HKMapInsertIfBetter(ctxt->chars, output[key], (HKKeycode)key, (HKModifier)tmod[idx], 0);
        // Save it into simple mapping table
        if (tmod[idx] == 0 && key < 128)
          ctxt->map[key] = output[key];
      }
      key++;
    }
  }

  /* handle deadstate record */
  if (records) {
    for (uint16_t idx = 0; idx < records->keyStateRecordCount; idx++) {
      const auto iter = deadr.find(idx);
      if (iter == deadr.end()) {
        spx_log("Unreachable block: %u", idx);
      } else {
        uint32_t code = iter->second;
        const UCKeyStateRecord *record = reinterpret_cast<const UCKeyStateRecord *>(data + records->keyStateRecordOffsets[idx]);
        if (record->stateZeroCharData != 0 && record->stateZeroNextState == 0) {
          UCKeyCharSeq unicode = record->stateZeroCharData;
          if (__HKUCHRKeyCharIsSequence(unicode)) {
            // Warning: sequence
          } else {
            /* Get keycode to access record idx */
            ctxt->chars.try_emplace(unicode, code);

            /* Update fast table map */
            uint16_t d;
            HKKeycode k = 0;
            HKModifier m = 0;
            __HKUtilsDeflatKey(code, &k, &m, &d);
            if (0 == m && kHKNilUnichar == ctxt->map[k]) {
              ctxt->map[k] = unicode;
            }
          }
        } else if ((record->stateZeroCharData == 0 || record->stateZeroCharData >= 0xFFFE) && record->stateZeroNextState != 0) {
          // No output and next state not null
          // Map dead state to keycode
          ctxt->stats.try_emplace(record->stateZeroNextState, code);
        }
        // Browse all record output
        if (record->stateEntryCount) {
          NSUInteger entry = 0;
          if (kUCKeyStateEntryTerminalFormat == record->stateEntryFormat) {
            const UCKeyStateEntryTerminal *term = reinterpret_cast<const UCKeyStateEntryTerminal *>(record->stateEntryData);
            while (entry < record->stateEntryCount) {
              UCKeyCharSeq unicode = term->charData;
              // Should resolve sequence
              if (__HKUCHRKeyCharIsSequence(unicode)) {
                //spx_debug("WARNING: Sequence: %u", unicode & 0x3fff);
              } else {
                // Get previous keycode and append dead key state
                code = __HKUtilsFlatDead(code, term->curState);
                ctxt->chars.try_emplace(unicode, code);
              }
              term++;
              entry++;
            }
          } else if (kUCKeyStateEntryRangeFormat == record->stateEntryFormat) {
            spx_log("Range entry not implemented");
          }
        } // reverse
      }
    }
  }

  __HKUtilsNormalizeEndOfLine(ctxt->chars);

  return ctxt;
}
