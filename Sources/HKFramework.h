
#if !defined(__HK_FRAMEWORK_H)
#define __HK_FRAMEWORK_H 1

#import <Foundation/Foundation.h>

#import <HotKeyToolKit/HKDefine.h>

// MARK: Framework Description
HK_OBJC_EXPORT
@interface HotKeyToolKitFramework : NSObject {}

+ (NSBundle *)bundle;
+ (NSString *)bundleIdentifier;

+ (NSURL *)URLForDirectory:(NSString *)aName;
+ (NSURL *)URLForAuxiliaryExecutable:(NSString *)name;

@end

#endif /* __HK_FRAMEWORK_H */
