/*
 *  HKFramework.m
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2013 Jean-Daniel Dupas. All rights reserved.
 */

#import <HotKeyToolKit/HKFramework.h>

@implementation HotKeyToolKitFramework

+ (NSBundle *)bundle {
  return [NSBundle bundleForClass:[HotKeyToolKitFramework class]];
}
+ (NSString *)bundleIdentifier {
  return [[self bundle] bundleIdentifier];
}

+ (NSURL *)URLForDirectory:(NSString *)aName {
  return [[[[self bundle] resourceURL] URLByDeletingLastPathComponent] URLByAppendingPathComponent:aName isDirectory:YES];
}

+ (NSURL *)URLForAuxiliaryExecutable:(NSString *)name {
  return [[self URLForDirectory:@"Support"] URLByAppendingPathComponent:name];
}

@end
