#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "OnboardingDuplicate" asset catalog image resource.
static NSString * const ACImageNameOnboardingDuplicate AC_SWIFT_PRIVATE = @"OnboardingDuplicate";

/// The "OnboardingSafe" asset catalog image resource.
static NSString * const ACImageNameOnboardingSafe AC_SWIFT_PRIVATE = @"OnboardingSafe";

/// The "OnboardingStorage" asset catalog image resource.
static NSString * const ACImageNameOnboardingStorage AC_SWIFT_PRIVATE = @"OnboardingStorage";

/// The "swipe_promo_image" asset catalog image resource.
static NSString * const ACImageNameSwipePromoImage AC_SWIFT_PRIVATE = @"swipe_promo_image";

#undef AC_SWIFT_PRIVATE
