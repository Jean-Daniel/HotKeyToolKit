/*
 *  HKHotKeyManager.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2012 Shadow Lab. All rights reserved.
 */
/*!
 @header HKHotKeyManager
 */
#import <Foundation/Foundation.h>
#import <HotKeyToolKit/HKBase.h>

@class HKHotKey;

/*!
 @class 		HKHotKeyManager
 @abstract   HotKeyManager is used to register and unregister HKHotKey. It dispatches Global HotKey event.
 */
HK_OBJC_EXPORT
@interface HKHotKeyManager : NSObject {
@private
  void *_handler; /* EventHandlerRef */
  NSMapTable *_refs;
  NSMapTable *_keys;
}

/*!
 @abstract   Returns the shared HKHotKeyManager instance.
 */
+ (HKHotKeyManager *)sharedManager;

/*!
 @abstract   Try to register an HKHotKey as Gloab System HotKey.
 @param		key The HKHotKey you want to register
 @result		YES if the key is succesfully registred.
 */
- (BOOL)registerHotKey:(HKHotKey *)key;
/*!
 @abstract   Try to unregister an HKHotKey as System HotKey.
 @param		key The HKHotKey you want to unregister
 @result		Returns YES if the key is succesfully unregistred.
 */
- (BOOL)unregisterHotKey:(HKHotKey *)key;

/*!
 @abstract   Unregister all registred keys.
 */
- (void)unregisterAll;

/* Protected */
- (void)hotKeyPressed:(HKHotKey *)key at:(NSTimeInterval)aTime;
- (void)hotKeyReleased:(HKHotKey *)key at:(NSTimeInterval)aTime;

@end

/*!
 @function
 @abstract   Use to define if a Shortcut is valid (not already used,…)
 @discussion You can customize this function result by providing a HKHotKeyFilter to the Manager (see setShortcutFilter).
 @param      code a Virtual Keycode.
 @param      modifier the modifier keys.
 @result     Returns YES if the keystrock is valid.
 */
HK_EXPORT
BOOL HKHotKeyCheckKeyCodeAndModifier(HKKeycode code, HKModifier modifier);

/* Debugging purpose */
HK_EXPORT BOOL HKTraceHotKeyEvents;
