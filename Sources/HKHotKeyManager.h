/*
 *  HKHotKeyManager.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2012 Shadow Lab. All rights reserved.
 */

#import <HotKeyToolKit/HKBase.h>

@class HKHotKey;

HK_PRIVATE
BOOL HKHotKeyRegister(HKHotKey *hotkey);

HK_PRIVATE
BOOL HKHotKeyUnregister(HKHotKey *hotkey);

HK_PRIVATE
BOOL HKHotKeyUnregisterAll(void);

