/*
 *  HKHotKey.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import <HotKeyToolKit/HKBase.h>

/*!
@abstract	This class represent a Global Hot Key (Shortcut) that can be registred to execute an action when called.
@discussion	It uses an UniChar and a virtual keycode to store the shortcut so if the keyboard layout change, the shortcut change too.
*/
HK_OBJC_EXPORT
@interface HKHotKey : NSObject <NSCopying>

#pragma mark -
#pragma mark Convenient constructors.
/*!
  @method
 @abstract Creates and returns an new Hot Key.
 @result A new HotKey.
 */
+ (instancetype)hotkey;
/*!
  @method
 @abstract Creates and returns an new Hot Key with keycode set to <i>code</i> and modifier set to <i>modifier</i>.
 @param code A virtual keycode.
 @result Returns a new HotKey with keystrock set to <i>keycode</i> and <i>modifier</i>.
 */
+ (instancetype)hotkeyWithKeycode:(HKKeycode)code modifier:(NSUInteger)modifier;
/*!
  @method
 @abstract Creates and returns an new Hot Key with character set to <i>character</i> and modifier set to <i>modifier</i>.
 @param character An UniChar.
 @result Returns a new HotKey with keystrock set to <i>character</i> and <i>modifier</i>.
 */
+ (instancetype)hotkeyWithUnichar:(UniChar)character modifier:(NSUInteger)modifier;

#pragma mark -
#pragma mark Initializers
/*!
  @method
 @abstract   Designated Initializer
 @result     A new HotKey.
 */
- (instancetype)init;

/*!
  @method
 @abstract   Initializes a newly allocated hotkey.
 @param      code The virtual Keycode of the receiver.
 @param      modifier The modifier mask for the receiver.
 @result     Returns a HotKey with keystrock set to <i>keycode</i> and <i>modifier</i>.
 */
- (instancetype)initWithKeycode:(HKKeycode)code modifier:(NSUInteger)modifier;
/*!
  @method
 @abstract   Initializes a newly allocated hotkey.
 @param      character (description)
 @param      modifier (description)
 @result     Returns a HotKey with keystrock set to <i>character</i> and <i>modifier</i>.
 */
- (instancetype)initWithUnichar:(UniChar)character modifier:(NSUInteger)modifier;

#pragma mark -
#pragma mark Misc Properties
/*!
  @method
 @abstract   	Methode use to define if a key can be registred.
 @discussion 	A key is valid if charater is not nil.
 @result		Returns YES if it has a keycode and a character.
 */
- (BOOL)isValid;

/*!
 @property
 @abstract String representation of the shortcut using symbolic characters when possible.
 */
@property(nonatomic, readonly) NSString *shortcut;

#pragma mark -
#pragma mark iVar Accessors.
/*!
 @property
 @abstract   The modifier is an unsigned int as define in NSEvent.h
 @discussion This modifier is equivalent to KeyMask defined in NSEvent.h
 @result     Returns the modifier associated whit this Hot Key.
 */
@property(nonatomic) NSUInteger modifier;

@property(nonatomic) HKModifier nativeModifier;

/*!
 @property
 @abstract  The Virtual keycode assigned to this Hot Key for the current keyboard layout.
 */
@property(nonatomic) HKKeycode keycode;
/*!
 @property
 @abstract   Character is an UniChar that represent the character associated whit this HotKey
 @discussion Character is an Unichar, but is not always printable. Some keyboard keys haven't a glyph
 representation. To obtain a printable representation use HKModifierStringForMask() with a nil modifier.
 When setting this property, if the character could not be generatd by a single key event without modifier,
 this method will try to find first keycode used to output character, and replace character by a output of this keycode.
 */
@property(nonatomic) UniChar character;

/* Set both keycode and caracter. Does not perform any check */
- (void)setKeycode:(HKKeycode)keycode character:(UniChar)character;

@property(nonatomic, copy) void (^actionBlock)(void);

@property(nonatomic) BOOL invokeOnKeyUp;

/*!
  @method
 @abstract   Returns the status of the Hot Key.
 @result		Returns YES if the receiver is currently register as a System Hot Key and respond to System Hot Key Events.
 */
- (BOOL)isRegistred;
/*!
  @method
 @abstract   Sets the stats of the receiver. If flag is YES, the receiver try to register himself as a Global Hot Key.
 @discussion This method call <i>isValid</i> before trying to register and return NO if receiver isn't valid.
 @result		Returns YES if the stats is already flag or if it succesfully registers or unregisters.
 */
- (BOOL)setRegistred:(BOOL)flag;

/*!
 @property
 @abstract  Time interval between two autorepeat key down events.
 @discussion 0 means no autorepeat.
 */
@property(nonatomic) NSTimeInterval repeatInterval;

/*!
 @property
 @discussion 0 means system default. < 0 means receiver's 'repeat interval'.
 */
@property(nonatomic) NSTimeInterval initialRepeatInterval;

/*!
 @property
 @abstract   Packed representation of receiver's character, keycode and modifier.
 @discussion This method can be usefull to serialize an hotkey or to save a keystate with one call.
 */
@property(nonatomic) uint64_t rawkey;

/*!
 @method
 @abstract   Make target perform action.
 */
- (void)invoke:(BOOL)repeat;

#pragma mark Callback Methods
- (void)keyPressed:(NSTimeInterval)eventTime;
- (void)keyReleased:(NSTimeInterval)eventTime;

- (void)willInvoke;
- (void)didInvoke;

/* valid only during [target action:sender] call */
@property(nonatomic, readonly) BOOL isARepeat;
@property(nonatomic, readonly) NSTimeInterval eventTime;

@end

// MARK: Serialization Helpers
HK_EXPORT
uint64_t HKHotKeyPackKeystoke(HKKeycode keycode, HKModifier modifier, UniChar chr);

HK_EXPORT
void HKHotKeyUnpackKeystoke(uint64_t raw, HKKeycode *keycode, HKModifier *modifier, UniChar *chr);

// MARK: System Settings
/*!
 @function
 @abstract Returns the time interval between two repeat key down event.
 @result Returns the key repeat interval setted in "System Preferences" or -1 on error.
 */
HK_EXPORT
NSTimeInterval HKGetSystemKeyRepeatInterval(void);

/*!
 @function
 @abstract Returns the time interval between a key is pressed and system start to repeat key down event.
 @result Returns the initial key repeat interval setted in "System Preferences" or -1 on error.
 */
HK_EXPORT
NSTimeInterval HKGetSystemInitialKeyRepeatInterval(void);

// MARK: Registration Utilities
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

