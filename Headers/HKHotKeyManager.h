//
//  HotKeyManager.h
//
//  Created by Fox on Sat Nov 29 2003.
//  Copyright (c) 2004 Shadow Lab. All rights reserved.
//
/*!
    @header HKHotKeyManager
*/

/*!
    @typedef 	HKHotKeyFilter CallBack.
    @abstract   A function of the form BOOL isAValidKeyStrock(UInt16 keycode, UInt32 modifier);<br />
 				<i>keycode</i> is a Virtual Keycode.
 				<i>modifier</i> is a Cocoa Modifier constant combination.
*/

typedef BOOL (*HKHotKeyFilter)(UInt32 keycode, UInt32 modifier);

@class HKHotKey;

/*!
    @class 		HKHotKeyManager
    @abstract   HotKeyManager is used to register and unregister HKHotKey. It dispatch Global HotKey event.
*/
@interface HKHotKeyManager : NSObject {
  @private
  void* hk_handler; /* EventHandlerRef handlerRef */
  NSMapTable *hk_keys;
}

/*!
    @method     isValidHotKeyCode:withModifier:
    @abstract   Use to define if a Shortcut is valid (not already used,�)
    @discussion You can customize this function result by providing a HKHotKeyFilter to the Manager (see setShortcutFilter).
 	@param		code a Virtual Keycode.
 	@param		modifier the modifier keys.
 	@result		Returns YES if the keystrock is valid.
*/
+ (BOOL)isValidHotKeyCode:(UInt32)code withModifier:(UInt32)modifier;


/*!
    @method     setShortcutFilter:
    @abstract   Add a filter function. This Function is used to define if a HotKey is valid or not.
 				Allow framework user to defined some shortcut as invalid.
    @param      filter A function like: BOOL isAValidShortCut(UInt16 keycode, UInt32 modifierMask);
*/
+ (void)setShortcutFilter:(HKHotKeyFilter)filter;

/*!
    @method     sharedManager
    @abstract   Returns the shared HKHotKeyManager instance. 
*/
+ (HKHotKeyManager *)sharedManager;

/*!
    @method     registerHotKey:
    @abstract   Try to register an HKHotKey as Gloab System HotKey.
 	@param		key The HKHotKey you want to register
 	@result		YES if the key is succesfully registred.
*/
- (BOOL)registerHotKey:(HKHotKey *)key;
/*!
    @method     unregisterHotKey:
    @abstract   Try to unregister an HKHotKey as System HotKey.
  	@param		key The HKHotKey you want to unregister
 	@result		Returns YES if the key is succesfully unregistred.
*/
- (BOOL)unregisterHotKey:(HKHotKey *)key;

/*!
    @method     unregisterAll
    @abstract   Unregister all registred keys.
*/
- (void)unregisterAll;

@end

extern BOOL HKTraceHotKeyEvents;