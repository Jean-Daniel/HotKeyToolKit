
#if !defined(HK_FRAMEWORK_H__)
#define HK_FRAMEWORK_H__ 1

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

#endif /* HK_FRAMEWORK_H__ */
