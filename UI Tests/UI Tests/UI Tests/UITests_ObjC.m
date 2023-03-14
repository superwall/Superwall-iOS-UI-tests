//
//  UITests-ObjC.m
//  UI Tests
//
//  Created by Bryan Dubno on 2/13/23.
//

#import "UI_Tests-Swift.h"

#import "UITests_ObjC.h"
#import "Configuration_ObjC.h"

@import SuperwallKit;

#define TEST_START \
TEST_START_NUM_ASSERTS(1);

#define TEST_START_NUM_ASSERTS(numAsserts) \
__weak typeof(self) weakSelf = self; dispatch_group_t group = dispatch_group_create(); for (NSInteger i = 0; i < numAsserts; i++){ dispatch_group_enter(group); } dispatch_group_notify(group, dispatch_get_main_queue(), ^{ completionHandler(nil); });

#define TEST_ASSERT(delay) \
[weakSelf assertAfter:delay testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] precision:SWKPrecisionValueDefault completionHandler:^{ dispatch_group_leave(group); }];

#define TEST_ASSERT_WITH_PRECISION(delay, precisionValue) \
[weakSelf assertAfter:delay testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] precision:precisionValue completionHandler:^{ dispatch_group_leave(group); }]

#define TEST_SKIP(message) \
[self skip:message]; return;

#define FATAL_ERROR(message) \
NSCAssert(false, message);

#pragma mark - SWKSuperwallDelegate

@interface SWKMockDelegate: NSObject <SWKSuperwallDelegate>
@property (nonatomic, strong) NSMutableArray <void (^)(SWKSuperwallEventInfo *info)> *observers;
- (void)addObserver:(void (^)(SWKSuperwallEventInfo *info))block;
- (void)removeObservers;
@end

#pragma mark - UITests_ObjC

// Constants
static NSTimeInterval kPaywallPresentationDelay;
static NSTimeInterval kPaywallPresentationFailureDelay;

@interface UITests_ObjC () <Testable>
@end

@implementation UITests_ObjC

static id<SWKTestConfiguration> kConfiguration;

- (id<SWKTestConfiguration>)configuration {
  if (!kConfiguration) {
    NSString *configurationType = SWKConstants.configurationType;
    if ([configurationType isEqualToString:@"automatic"]) {
      kConfiguration = [SWKConfigurationAutomatic new];
    } else {
      NSAssert(NO, @"Could not find ObjC test configuration type");
    }
  }

  return kConfiguration;
}

+ (void)initialize {
  kPaywallPresentationDelay = SWKConstants.paywallPresentationDelay;
  kPaywallPresentationFailureDelay = SWKConstants.paywallPresentationFailureDelay;
}

- (void)test0WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  TEST_ASSERT(kPaywallPresentationDelay)
}

- (void)test1WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test1a"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

  // Set new identity.
  [[Superwall sharedInstance] identifyWithUserId:@"test1b"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Kate" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  TEST_ASSERT(kPaywallPresentationDelay)
}

- (void)test2WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test2"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

  // Reset the user identity
  [[Superwall sharedInstance] reset];

  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  TEST_ASSERT(kPaywallPresentationDelay)
}

- (void)test3WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test3"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

  // Reset the user identity twice
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];

  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  TEST_ASSERT(kPaywallPresentationDelay)
}

#warning crop home indicator
- (void)test4WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] trackWithEvent:@"present_video"];

  [self sleepWithTimeInterval:4.0 completionHandler:^{
    [[Superwall sharedInstance] dismissWithCompletion:^{
      [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
        [[Superwall sharedInstance] trackWithEvent:@"present_video"];

        TEST_ASSERT_WITH_PRECISION(2.0, SWKPrecisionValueVideo);
      }];
    }];
  }];
}

#warning https://linear.app/superwall/issue/SW-1632/add-objc-initialiser-for-paywallproducts
- (void)test5WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  SKProduct *primary = SWKStoreKitHelper.shared.monthlyProduct;
  SKProduct *secondary = SWKStoreKitHelper.shared.annualProduct;

  if (!primary || !secondary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];

  SWKPaywallProducts *products = [[SWKPaywallProducts alloc] initWithPrimary:primaryProduct secondary:secondaryProduct tertiary:nil];
  ////  PaywallOverrides *paywallOverrides = [[PaywallOverrides alloc] initWithProducts:products];
  //
  [[Superwall sharedInstance] trackWithEvent:@"present_products" params:nil products:products ignoreSubscriptionStatus:NO presentationStyleOverride:SWKPaywallPresentationStyleNone onSkip:nil onPresent:nil onDismiss:nil];

  TEST_ASSERT(kPaywallPresentationDelay)
}

#warning https://linear.app/superwall/issue/SW-1633/check-paywall-overrides-work
- (void)test6WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Present the paywall.
  [[Superwall sharedInstance] trackWithEvent:@"present_products"];

  TEST_ASSERT(kPaywallPresentationDelay);
}

- (void)test7WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @14}];
  [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

  // Assert after a delay
  [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    TEST_ASSERT(0);

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove those attributes.
      [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];
      [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

      TEST_ASSERT(kPaywallPresentationDelay);
    }];
  }];
}

- (void)test8WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @12}];
  [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

  TEST_ASSERT(kPaywallPresentationDelay);
}

- (void)test9WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
//  [self canRunWithTest:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__]];
  TEST_SKIP(@"Rework test");

//  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
//  [[Superwall sharedInstance] trackWithEvent:@"present_always"];
//
//  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
- (void)test10WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Present the paywall.
  [[Superwall sharedInstance] trackWithEvent:@"present_products"];

  // Wait and assert.
  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // Assert original products.
    TEST_ASSERT(0);

    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{

      // Create override products
      SKProduct *monthlyProduct = SWKStoreKitHelper.shared.monthlyProduct;
      SKProduct *annualProduct = SWKStoreKitHelper.shared.annualProduct;

      SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:monthlyProduct];
      SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:annualProduct];

      SWKPaywallProducts *products = [[SWKPaywallProducts alloc] initWithPrimary:primaryProduct secondary:secondaryProduct tertiary:nil];

      // Override original products with new ones.
      [[Superwall sharedInstance] trackWithEvent:@"present_products" params:nil products:products ignoreSubscriptionStatus:NO presentationStyleOverride:SWKPaywallPresentationStyleNone onSkip:nil onPresent:nil onDismiss:nil];

      // Wait and assert.
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Assert override products.
        TEST_ASSERT(0);

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          // Present the paywall.
          [[Superwall sharedInstance] trackWithEvent:@"present_products"];

          // Assert original products.
          TEST_ASSERT(kPaywallPresentationDelay);

        }];
      }];
    }];
  }];
}

// Clear a specific user attribute.
- (void)test11WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3);

  // Add user attribute
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Claire" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // Assert that the first name is displayed
    TEST_ASSERT(0);

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove user attribute
      [[Superwall sharedInstance] removeUserAttributes:@[@"first_name"]];
      [[Superwall sharedInstance] trackWithEvent:@"present_data"];

      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Assert that the first name is NOT displayed
        TEST_ASSERT(0);

        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Add new user attribute
          [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Sawyer" }];
          [[Superwall sharedInstance] trackWithEvent:@"present_data"];

          TEST_ASSERT(kPaywallPresentationDelay)
        }];
      }];
    }];
  }];
}

// Test trigger: off
- (void)test12WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] trackWithEvent:@"keep_this_trigger_off"];
  TEST_ASSERT(kPaywallPresentationDelay);
}

// Test trigger: not in the dashboard
- (void)test13WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] trackWithEvent:@"i_just_made_this_up_and_it_dne"];
  TEST_ASSERT(kPaywallPresentationDelay);
}

// Test trigger: not-allowed standard event (paywall_close)
- (void)test14WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  [[Superwall sharedInstance] trackWithEvent:@"present_always"];

  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // After delay, assert that there was a presentation
    TEST_ASSERT(0);

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
      TEST_ASSERT(kPaywallPresentationDelay);
    }];
  }];
}

// Clusterfucks by Jake™
- (void)test15WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Present paywall
  [[Superwall sharedInstance] trackWithEvent:@"present_always"];
  [[Superwall sharedInstance] trackWithEvent:@"present_always" params:@{@"some_param_1": @"hello"}];
  [[Superwall sharedInstance] trackWithEvent:@"present_always"];

  // Wait and assert.
  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // After delay, assert that there was a presentation
    TEST_ASSERT(0);

    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{

      [[Superwall sharedInstance] trackWithEvent:@"present_always"];
      [[Superwall sharedInstance] identifyWithUserId:@"1111"];
      [[Superwall sharedInstance] trackWithEvent:@"present_always"];

      // Wait and assert.
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // After delay, assert that there was a presentation
        TEST_ASSERT(0);

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          // Present paywall
          [[Superwall sharedInstance] trackWithEvent:@"present_always" onSkip:nil onPresent:^(SWKPaywallInfo * _Nonnull info) {
            [[Superwall sharedInstance] trackWithEvent:@"present_always"];

            // Wait and assert.
            TEST_ASSERT(kPaywallPresentationDelay);

          } onDismiss:nil];
        }];
      }];
    }];
  }];
}

// Present an alert on Superwall.presentedViewController from the onPresent callback
- (void)test16WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] trackWithEvent:@"present_always" onSkip:nil onPresent:^(SWKPaywallInfo * _Nonnull info) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:@"This is an alert message" preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:okAction];

      UIViewController *presentingViewController = [Superwall sharedInstance].presentedViewController;
      [presentingViewController presentViewController:alertController animated:NO completion:nil];
    });
  } onDismiss:nil];

  TEST_ASSERT_WITH_PRECISION(kPaywallPresentationDelay, SWKPrecisionValueTransparency);
}

// Clusterfucks by Jake™
- (void)test17WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    TEST_ASSERT(0)

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Set identity
      [[Superwall sharedInstance] identifyWithUserId:@"test2"];
      [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

      // Reset the user identity
      [[Superwall sharedInstance] reset];

      [[Superwall sharedInstance] trackWithEvent:@"present_data"];

      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        TEST_ASSERT(0)

        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Present paywall
          [[Superwall sharedInstance] trackWithEvent:@"present_always"];
          [[Superwall sharedInstance] trackWithEvent:@"present_always" params:@{@"some_param_1": @"hello"}];
          [[Superwall sharedInstance] trackWithEvent:@"present_always"];

          TEST_ASSERT(kPaywallPresentationDelay);
        }];
      }];
    }];
  }];
}

- (void)test18WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping for now")
}

// Clusterfucks by Jake™
- (void)test19WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test19a"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Jack"}];

  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    TEST_ASSERT(0)

    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{

      [[Superwall sharedInstance] getTrackResultForEvent:@"present_and_rule_user" completionHandler:^(SWKTrackResult * _Nonnull result) {

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          // Show a paywall
          [[Superwall sharedInstance] trackWithEvent:@"present_always"];

          // Assert that paywall was displayed
          [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
            TEST_ASSERT(0)

            // Dismiss any view controllers
            [weakSelf dismissViewControllersWithCompletionHandler:^{
              // Assert that no paywall is displayed as a result of the Superwall-owned paywall_close standard event.
              TEST_ASSERT(0)

              // Dismiss any view controllers
              [weakSelf dismissViewControllersWithCompletionHandler:^{

                // Set identity
                [[Superwall sharedInstance] identifyWithUserId:@"test19b"];
                [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Jack"}];

                // Set new identity
                [[Superwall sharedInstance] identifyWithUserId:@"test19c"];
                [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Kate"}];
                [[Superwall sharedInstance] trackWithEvent:@"present_data"];

                TEST_ASSERT(kPaywallPresentationDelay)
              }];
            }];
          }];
        }];
      }];
    }];
  }];
}

- (void)test20WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Write from Swift version")
}

//- (void)test_getTrackResult_paywall {
//  [[Superwall sharedInstance] getTrackResultForEvent:@"present_data" completionHandler:^(SWKTrackResult * _Nonnull result) {
//    switch (result.value) {
//      case SWKTrackValuePaywall:
//        break;
//      default:
//        XCTFail();
//    }
//  }];
//}
//
//- (void)test_getTrackResult_eventNotFound {
//  [[Superwall sharedInstance] getTrackResultForEvent:@"a_random_madeup_event" completionHandler:^(SWKTrackResult * _Nonnull result) {
//    XCTAssertEqual(result.value, SWKTrackValueEventNotFound);
//  }];
//}
//
//- (void)test_getTrackResult_noRuleMatch {
//  [[Superwall sharedInstance] getTrackResultForEvent:@"present_and_rule_user" completionHandler:^(SWKTrackResult * _Nonnull result) {
//    XCTAssertEqual(result.value, SWKTrackValueNoRuleMatch);
//  }];
//}
//
//- (void)test_getTrackResult_paywallNotAvailable {
//  [[Superwall sharedInstance] getTrackResultForEvent:@"incorrect_product_identifier" completionHandler:^(SWKTrackResult * _Nonnull result) {
//    XCTAssertEqual(result.value, SWKTrackValuePaywallNotAvailable);
//  }];
//}
//
//- (void)test_getTrackResult_holdout {
//  [[Superwall sharedInstance] getTrackResultForEvent:@"holdout" completionHandler:^(SWKTrackResult * _Nonnull result) {
//    switch (result.value) {
//      case SWKTrackValueHoldout:
//        break;
//      default:
//        XCTFail();
//    }
//  }];
//}

// Missing the final case `userIsSubscribed`. This can be done when we are able to manually
// set the subscription status using the purchaseController.


// Make sure exit / refresh shows up if paywall.js isn’t installed on page
//- (void)test17 {
////
//  // Send event
//  [[Superwall sharedInstance] trackWithEvent:@"no_paywalljs"];
//
//  // Wait and assert.
//  ASYNC_TEST_ASSERT(kPaywallPresentationFailureDelay);
//
//}

@end

// MARK: - SWKMockDelegate

@implementation SWKMockDelegate

- (instancetype)init {
  self = [super init];
  if (self) {
    self.observers = [[NSMutableArray alloc] init];
  }

  return self;
}

- (void)addObserver:(void (^)(SWKSuperwallEventInfo *info))block {
  [self.observers addObject:block];
}

- (void)removeObservers {
  [self.observers removeAllObjects];
}

- (void)didTrackSuperwallEventInfo:(SWKSuperwallEventInfo *)info {
  [self.observers enumerateObjectsUsingBlock:^(void (^ _Nonnull observer)(SWKSuperwallEventInfo *), NSUInteger idx, BOOL * _Nonnull stop) {
    observer(info);
  }];
}

@end
