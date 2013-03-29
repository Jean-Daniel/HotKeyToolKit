/*
 *  HKTrapWindow.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2004 - 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

#import <HotKeyToolKit/HKBase.h>

// MARK: Constants Declaration
/*!
 @abstract   Notification send when a NSEvent is caught.
 @discussion Notification userInfo contains a NSDictionary with 3 keys:<br />
 - kHKEventKeyCodeKey: A NSNumber<br />
 - kHKEventModifierKey: A NSNumber<br />
 - kHKEventCharacterKey: A NSNumber<br />
 */
HK_EXPORT
NSString * const kHKTrapWindowDidCatchKeyNotification;

HK_EXPORT
NSString * const kHKEventKeyCodeKey;
HK_EXPORT
NSString * const kHKEventModifierKey;
HK_EXPORT
NSString * const kHKEventCharacterKey;

// MARK: -
/*!
 @abstract   This Window can be use to record a Hot Key Event.
 @discussion The Window catch all Events and when the
 NSTextField trapField is selected, it block KeyEvents and send a -setHotKey:mask: message
 to the delegate.
 To use it, create an NSWindow in Interface Builder. Change the window class to HKTrapWindow
 and link trapField to a NSTextField owned by this window. Each time the Window receive an event,
 it set the value of this textField to the shortCut String Description.
 */
@class HKHotKey;
@protocol HKTrapWindowDelegate;
HK_OBJC_EXPORT
@interface HKTrapWindow : NSWindow {
@private
  struct _hk_twFlags {
    unsigned int trap:1;
    unsigned int resend:1;
    unsigned int skipverify:1;
    unsigned int :29;
  } _twFlags;
}

@property(nonatomic) BOOL trapping;
@property(nonatomic) BOOL verifyHotKey;

/* simulate event (usefull when want to catch an already registred hotkey) */
- (void)handleHotKey:(HKHotKey *)aKey;

@property(nonatomic, assign) id<HKTrapWindowDelegate> delegate;

@end

// MARK: -
/*!
 @category	NSObject(TrapWindowDelegate)
 @abstract	Delegate Methods for HKTrapWindow
 */
@protocol HKTrapWindowDelegate <NSWindowDelegate>
@optional
/*!
 @abstract   Implements this method to filter which key equivalent should be handle by the windows or trapped.
 							This method is required if you don't want to catch shortcut like 'ESC'.
 @param      window The Trap Window.
 @result     Returns YES to catch the event and prevent it processing by the window.
 */
- (BOOL)trapWindow:(HKTrapWindow *)window shouldTrapKeyEquivalent:(NSEvent *)theEvent;

/*!
 @discussion Implements this method to filter which key events should be caught.
 							You can use this method to prevent catching of events like <code>return</code> or <code>escape</code>.
 @param      window The Trap Window.
 @param      theEvent The event to proceed.
 @result     Returns YES to catch the event and prevent it processing by the window.
 */
- (BOOL)trapWindow:(HKTrapWindow *)window shouldTrapKeyEvent:(NSEvent *)theEvent;

/* hotkey filter */
- (BOOL)trapWindow:(HKTrapWindow *)window isValidHotKey:(HKKeycode)keycode modifier:(HKModifier)modifier;

/*!
 @method     trapWindowDidCatchHotKey:
 @abstract   Notification sended when the trap catch an Event.
 @discussion userInfo contains a NSDictionary with 3 keys:<br />
 - kHKEventKeyCodeKey: A NSNumber<br />
 - kHKEventModifierKey: A NSNumber<br />
 - kHKEventCharacterKey: A NSNumber<br />
 @param      aNotification The Notification object is the window itself.
 */
- (void)trapWindowDidCatchHotKey:(NSNotification *)aNotification;

@end
