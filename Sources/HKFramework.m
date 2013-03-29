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
  NSString *path = [[[[self bundle] resourcePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:aName];
  return path ? [NSURL fileURLWithPath:path isDirectory:YES] : nil;
}

+ (NSURL *)URLForAuxiliaryExecutable:(NSString *)name {
  NSString *path = [[[[self bundle] resourcePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Support"];
  return path ? [NSURL fileURLWithPath:[path stringByAppendingPathComponent:name]] : nil;
}

@end
