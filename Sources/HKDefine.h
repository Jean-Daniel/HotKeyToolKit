/*
 *  HKDefine.h
 *  HotKeyToolKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2013 Jean-Daniel Dupas. All rights reserved.
 *
 *  File version: 100
 *  File Generated using “basegen --name=HotKeyToolKit --prefix=hk --objc --framework”.
 */

#if !defined(HK_DEFINE_H__)
#define HK_DEFINE_H__ 1

// MARK: Clang Macros
#ifndef __has_builtin
  #define __has_builtin(x) __has_builtin_ ## x
#endif

#ifndef __has_attribute
  #define __has_attribute(x) __has_attribute_ ## x
#endif

#ifndef __has_feature
  #define __has_feature(x) __has_feature_ ## x
#endif

#ifndef __has_extension
  #define __has_extension(x) __has_feature(x)
#endif

#ifndef __has_include
  #define __has_include(x) 0
#endif

#ifndef __has_include_next
  #define __has_include_next(x) 0
#endif

#ifndef __has_warning
  #define __has_warning(x) 0
#endif

// MARK: Visibility
#if defined(_WIN32)
  #define HK_HIDDEN

  #if defined(HK_STATIC_LIBRARY)
      #define HK_VISIBLE
  #else
    #if defined(HOTKEYTOOLKIT_DLL_EXPORT)
      #define HK_VISIBLE __declspec(dllexport)
    #else
      #define HK_VISIBLE __declspec(dllimport)
    #endif
  #endif
#endif

#if !defined(HK_VISIBLE)
  #define HK_VISIBLE __attribute__((__visibility__("default")))
#endif

#if !defined(HK_HIDDEN)
  #define HK_HIDDEN __attribute__((__visibility__("hidden")))
#endif

#if !defined(HK_EXTERN)
  #if defined(__cplusplus)
    #define HK_EXTERN extern "C"
  #else
    #define HK_EXTERN extern
  #endif
#endif

/* HK_EXPORT HK_PRIVATE should be used on
 extern variables and functions declarations */
#if !defined(HK_EXPORT)
  #define HK_EXPORT HK_EXTERN HK_VISIBLE
#endif

#if !defined(HK_PRIVATE)
  #define HK_PRIVATE HK_EXTERN HK_HIDDEN
#endif

// MARK: Inline
#if defined(__cplusplus) && !defined(__inline__)
  #define __inline__ inline
#endif

#if !defined(HK_INLINE)
  #if !defined(__NO_INLINE__)
    #if defined(_MSC_VER)
      #define HK_INLINE __forceinline static
    #else
      #define HK_INLINE __inline__ __attribute__((__always_inline__)) static
    #endif
  #else
    #define HK_INLINE __inline__ static
  #endif /* No inline */
#endif

// MARK: Attributes
#if !defined(HK_NORETURN)
  #if defined(_MSC_VER)
    #define HK_NORETURN __declspec(noreturn)
  #else
    #define HK_NORETURN __attribute__((__noreturn__))
  #endif
#endif

#if !defined(HK_DEPRECATED)
  #if defined(_MSC_VER)
    #define HK_DEPRECATED(msg) __declspec(deprecated(msg))
  #elif defined(__clang__)
    #define HK_DEPRECATED(msg) __attribute__((__deprecated__(msg)))
  #else
    #define HK_DEPRECATED(msg) __attribute__((__deprecated__))
  #endif
#endif

#if !defined(HK_UNUSED)
  #if defined(_MSC_VER)
    #define HK_UNUSED
  #else
    #define HK_UNUSED __attribute__((__unused__))
  #endif
#endif

#if !defined(HK_REQUIRES_NIL_TERMINATION)
  #if defined(_MSC_VER)
    #define HK_REQUIRES_NIL_TERMINATION
  #elif defined(__APPLE_CC__) && (__APPLE_CC__ >= 5549)
    #define HK_REQUIRES_NIL_TERMINATION __attribute__((__sentinel__(0,1)))
  #else
    #define HK_REQUIRES_NIL_TERMINATION __attribute__((__sentinel__))
  #endif
#endif

#if !defined(HK_REQUIRED_ARGS)
  #if defined(_MSC_VER)
    #define HK_REQUIRED_ARGS(idx, ...)
  #else
    #define HK_REQUIRED_ARGS(idx, ...) __attribute__((__nonnull__(idx, ##__VA_ARGS__)))
  #endif
#endif

#if !defined(HK_FORMAT)
  #if defined(_MSC_VER)
    #define HK_FORMAT(fmtarg, firstvararg)
  #else
    #define HK_FORMAT(fmtarg, firstvararg) __attribute__((__format__ (__printf__, fmtarg, firstvararg)))
  #endif
#endif

#if !defined(HK_CF_FORMAT)
  #if defined(__clang__)
    #define HK_CF_FORMAT(i, j) __attribute__((__format__(__CFString__, i, j)))
  #else
    #define HK_CF_FORMAT(i, j)
  #endif
#endif

#if !defined(HK_NS_FORMAT)
  #if defined(__clang__)
    #define HK_NS_FORMAT(i, j) __attribute__((__format__(__NSString__, i, j)))
  #else
    #define HK_NS_FORMAT(i, j)
  #endif
#endif

// MARK: -
// MARK: Static Analyzer
#ifndef CF_CONSUMED
  #if __has_attribute(cf_consumed)
    #define CF_CONSUMED __attribute__((__cf_consumed__))
  #else
    #define CF_CONSUMED
  #endif
#endif

#ifndef CF_RETURNS_RETAINED
  #if __has_attribute(cf_returns_retained)
    #define CF_RETURNS_RETAINED __attribute__((__cf_returns_retained__))
  #else
    #define CF_RETURNS_RETAINED
  #endif
#endif

#ifndef CF_RETURNS_NOT_RETAINED
	#if __has_attribute(cf_returns_not_retained)
		#define CF_RETURNS_NOT_RETAINED __attribute__((__cf_returns_not_retained__))
	#else
		#define CF_RETURNS_NOT_RETAINED
	#endif
#endif


#if defined(__OBJC__)

/* HK_OBJC_EXPORT and HK_OBJC_PRIVATE can be used
 to define ObjC classes visibility. */
#if !defined(HK_OBJC_PRIVATE)
  #if __LP64__
    #define HK_OBJC_PRIVATE HK_HIDDEN
  #else
    #define HK_OBJC_PRIVATE
  #endif /* 64 bits runtime */
#endif

#if !defined(HK_OBJC_EXPORT)
  #if __LP64__
    #define HK_OBJC_EXPORT HK_VISIBLE
  #else
    #define HK_OBJC_EXPORT
  #endif /* 64 bits runtime */
#endif

// MARK: Static Analyzer
#ifndef HK_UNUSED_IVAR
  #if __has_extension(attribute_objc_ivar_unused)
    #define HK_UNUSED_IVAR __attribute__((__unused__))
  #else
    #define HK_UNUSED_IVAR
  #endif
#endif

#ifndef NS_CONSUMED
  #if __has_attribute(ns_consumed)
    #define NS_CONSUMED __attribute__((__ns_consumed__))
  #else
    #define NS_CONSUMED
  #endif
#endif

#ifndef NS_CONSUMES_SELF
  #if __has_attribute(ns_consumes_self)
    #define NS_CONSUMES_SELF __attribute__((__ns_consumes_self__))
  #else
    #define NS_CONSUMES_SELF
  #endif
#endif

#ifndef NS_RETURNS_RETAINED
  #if __has_attribute(ns_returns_retained)
    #define NS_RETURNS_RETAINED __attribute__((__ns_returns_retained__))
  #else
    #define NS_RETURNS_RETAINED
  #endif
#endif

#ifndef NS_RETURNS_NOT_RETAINED
  #if __has_attribute(ns_returns_not_retained)
    #define NS_RETURNS_NOT_RETAINED __attribute__((__ns_returns_not_retained__))
  #else
    #define NS_RETURNS_NOT_RETAINED
  #endif
#endif

#ifndef NS_RETURNS_AUTORELEASED
  #if __has_attribute(ns_returns_autoreleased)
    #define NS_RETURNS_AUTORELEASED __attribute__((__ns_returns_autoreleased__))
  #else
    #define NS_RETURNS_AUTORELEASED
  #endif
#endif

/* Method Family */
#ifndef NS_METHOD_FAMILY
  /* supported families are: none, alloc, copy, init, mutableCopy, and new. */
  #if __has_attribute(ns_returns_autoreleased)
    #define NS_METHOD_FAMILY(family) __attribute__((objc_method_family(family)))
  #else
    #define NS_METHOD_FAMILY(arg)
  #endif
#endif

// gracefully degrade
#if !__has_feature(objc_instancetype)
  #define instancetype id
#endif

#endif /* ObjC */


#endif /* HK_DEFINE_H__ */
