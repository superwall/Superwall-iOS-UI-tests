//
//  SnapshotTests-ObjC.m
//  Automated Snapshot Testing
//
//  Created by Bryan Dubno on 2/13/23.
//

#import <XCTest/XCTest.h>
#import "Automated_Snapshot_Testing-Swift.h"

@import SnapshotTesting;
@import SuperwallKit;

#define ASYNC_BEGIN \
ASYNC_BEGIN_WITH(1)

#define ASYNC_BEGIN_WITH(NUM_ASSERTS) \
XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@""]; __weak typeof(self) weakSelf = self; expectation.expectedFulfillmentCount = NUM_ASSERTS;

#define ASYNC_END \
[self waitWithExpectation:expectation];

#define ASYNC_FULFILL \
[expectation fulfill]; weakSelf;

// After a delay, the snapshot will be taken and the expectation will be fulfilled. Don't confused this await. You'll need to use `[self sleepWithTimeInterval:completionHandler:]` if you need to wait.
#define ASYNC_TEST_ASSERT(timeInterval) \
[weakSelf assertAfter:timeInterval fulfill:expectation testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] precision:YES];

#define ASYNC_TEST_ASSERT_WITHOUT_PRECISION(timeInterval) \
[weakSelf assertAfter:timeInterval fulfill:expectation testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] precision:NO];

#pragma mark - SWKSuperwallDelegate

@interface SWKMockDelegate: NSObject <SWKSuperwallDelegate>
@property (nonatomic, strong) NSMutableArray <void (^)(SWKSuperwallEventInfo *info)> *observers;
- (void)addObserver:(void (^)(SWKSuperwallEventInfo *info))block;
- (void)removeObservers;
@end

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

#pragma mark - SnapshotTests_ObjC

@interface SnapshotTests_ObjC : XCTestCase

@property (nonatomic, strong) SWKMockDelegate *mockDelegate;

@end

// Constants
static NSTimeInterval kPaywallPresentationDelay = 8.0;
static BOOL kHasConfigured = NO;

@implementation SnapshotTests_ObjC

- (void)setUp {
  // Make sure setup has not been called
  if (kHasConfigured) {
    return;
  }

  kHasConfigured = YES;

  ASYNC_BEGIN

  self.mockDelegate = [[SWKMockDelegate alloc] init];

  [Superwall configureWithApiKey:@"pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2"];
  Superwall.sharedInstance.delegate = self.mockDelegate;

  // Set status
  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

  // Begin fetching products for use in other test cases
  [[SWKStoreKitHelper shared] fetchCustomProductsWithCompletionHandler:^{
    ASYNC_FULFILL
  }];

  ASYNC_END
}

- (void)tearDown {
  ASYNC_BEGIN

  // Reset status
  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

  // Dismiss any view controllers
  [self dismissViewControllersWithCompletionHandler:^{
    ASYNC_FULFILL
  }];

  // Remove delegate observers
  [self.mockDelegate removeObservers];

  ASYNC_END
}

- (void)test0 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] identifyWithUserId:@"test0" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay)

  ASYNC_END
}

- (void)test1 {
  ASYNC_BEGIN

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test1a" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];

  // Set new identity.
  [[Superwall sharedInstance] identifyWithUserId:@"test1b" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Kate" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay)

  ASYNC_END
}

#warning https://linear.app/superwall/issue/SW-1625/[bug]-reset-not-clearing-user-attributes-before-presenting-paywall
- (void)test2 {
  ASYNC_BEGIN

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test2" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];

  // Reset the user identity
  [[Superwall sharedInstance] reset];

  [[Superwall sharedInstance] trackWithEvent:@"present_data"];
  ASYNC_TEST_ASSERT(kPaywallPresentationDelay)

  ASYNC_END
}

- (void)test3 {
  ASYNC_BEGIN

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test3" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];

  // Reset the user identity twice
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];

  [[Superwall sharedInstance] trackWithEvent:@"present_data"];
  ASYNC_TEST_ASSERT(kPaywallPresentationDelay)

  ASYNC_END
}

- (void)test4 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] trackWithEvent:@"present_video"];

  [self sleepWithTimeInterval:4.0 completionHandler:^{
    [[Superwall sharedInstance] dismissWithCompletion:^{
      [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
        [[Superwall sharedInstance] trackWithEvent:@"present_video"];

        ASYNC_TEST_ASSERT_WITHOUT_PRECISION(2.0);
      }];
    }];
  }];

  ASYNC_END
}

#warning https://linear.app/superwall/issue/SW-1632/add-objc-initialiser-for-paywallproducts
- (void)test5 {
  ASYNC_BEGIN

  SKProduct *primary = SWKStoreKitHelper.shared.monthlyProduct;
  SKProduct *secondary = SWKStoreKitHelper.shared.annualProduct;

  if (!primary || !secondary) {
    XCTAssert(false, @"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];

  SWKPaywallProducts *products = [[SWKPaywallProducts alloc] initWithPrimary:primaryProduct secondary:secondaryProduct tertiary:nil];
  ////  PaywallOverrides *paywallOverrides = [[PaywallOverrides alloc] initWithProducts:products];
  //
  [[Superwall sharedInstance] trackWithEvent:@"present_products" params:nil products:products ignoreSubscriptionStatus:NO presentationStyleOverride:SWKPaywallPresentationStyleNone onSkip:nil onPresent:nil onDismiss:nil];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay)

  ASYNC_END
}

#warning https://linear.app/superwall/issue/SW-1633/check-paywall-overrides-work
- (void)test6 {
  ASYNC_BEGIN

  // Present the paywall.
  [[Superwall sharedInstance] trackWithEvent:@"present_products"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

- (void)test7 {
  ASYNC_BEGIN_WITH(2)

  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @14}];
  [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

  // Assert after a delay
  [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    ASYNC_TEST_ASSERT(0);

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove those attributes.
      [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];
      [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

      ASYNC_TEST_ASSERT(kPaywallPresentationDelay);
    }];
  }];

  ASYNC_END
}

- (void)test8 {
  ASYNC_BEGIN

  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7" error:nil];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @12}];
  [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

- (void)test9 {
  ASYNC_BEGIN

  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
  [[Superwall sharedInstance] trackWithEvent:@"present_always"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
#warning("https://linear.app/superwall/issue/SW-1633/check-paywall-overrides-work")
- (void)test10 {
  ASYNC_BEGIN_WITH(3)

  // Present the paywall.
  [[Superwall sharedInstance] trackWithEvent:@"present_products"];

  // Wait and assert.
  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // Assert original products.
    ASYNC_TEST_ASSERT(0);

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
        ASYNC_TEST_ASSERT(0);

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          // Present the paywall.
          [[Superwall sharedInstance] trackWithEvent:@"present_products"];

          // Assert original products.
          ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

        }];
      }];
    }];
  }];

  ASYNC_END
}

// Clear a specific user attribute.
- (void)test11 {
  ASYNC_BEGIN_WITH(3)

  // Add user attribute
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name": @"Claire" }];
  [[Superwall sharedInstance] trackWithEvent:@"present_data"];

  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // Assert that the first name is displayed
    ASYNC_TEST_ASSERT(0)

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove user attribute
      [[Superwall sharedInstance] removeUserAttributes:@[@"first_name"]];
      [[Superwall sharedInstance] trackWithEvent:@"present_data"];

      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Assert that the first name is NOT displayed
        ASYNC_TEST_ASSERT(0)

        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Add new user attribute
          [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name": @"Sawyer" }];
          [[Superwall sharedInstance] trackWithEvent:@"present_data"];

          ASYNC_TEST_ASSERT(kPaywallPresentationDelay)
        }];
      }];
    }];
  }];

  ASYNC_END
}

// Test trigger: off
- (void)test12 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] trackWithEvent:@"keep_this_trigger_off"];
  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

// Test trigger: not in the dashboard
- (void)test13 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] trackWithEvent:@"i_just_made_this_up_and_it_dne"];
  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

// Test trigger: not-allowed standard event (paywall_close)
- (void)test14 {
  ASYNC_BEGIN_WITH(2)

  [[Superwall sharedInstance] trackWithEvent:@"present_always"];

  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // After delay, assert that there was a presentation
    ASYNC_TEST_ASSERT(0);

    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
      ASYNC_TEST_ASSERT(kPaywallPresentationDelay);
    }];
  }];

  ASYNC_END
}

// Clusterfucks by Jake™
#warning Failing on assertion 2: https://linear.app/superwall/issue/SW-1659/[bug-minor]-uiwindow-appears-slightly-misplaced
- (void)test15 {
  ASYNC_BEGIN_WITH(3)

  // Present paywall
  [[Superwall sharedInstance] trackWithEvent:@"present_always"];
  [[Superwall sharedInstance] trackWithEvent:@"present_always" params:@{@"some_param_1": @"hello"}];
  [[Superwall sharedInstance] trackWithEvent:@"present_always"];

  // Wait and assert.
  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
    // After delay, assert that there was a presentation
    ASYNC_TEST_ASSERT(0);

    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{

      [[Superwall sharedInstance] trackWithEvent:@"present_always"];
      [[Superwall sharedInstance] identifyWithUserId:@"1111" error:nil];
      [[Superwall sharedInstance] trackWithEvent:@"present_always"];

      // Wait and assert.
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // After delay, assert that there was a presentation
        ASYNC_TEST_ASSERT(0);

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          // Present paywall
          [[Superwall sharedInstance] trackWithEvent:@"present_always" onSkip:nil onPresent:^(SWKPaywallInfo * _Nonnull info) {
            [[Superwall sharedInstance] trackWithEvent:@"present_always"];

            // Wait and assert.
            ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

          } onDismiss:nil];
        }];
      }];
    }];
  }];

  ASYNC_END
}

// Present an alert on Superwall.presentedViewController from the onPresent callback
- (void)test16 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] trackWithEvent:@"present_always" onSkip:nil onPresent:^(SWKPaywallInfo * _Nonnull info) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:@"This is an alert message" preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:okAction];

      UIViewController *presentingViewController = [Superwall sharedInstance].presentedViewController;
      [presentingViewController presentViewController:alertController animated:NO completion:nil];
    });
  } onDismiss:nil];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

// Make sure exit / refresh shows up if paywall.js isn’t installed on page
#warning("does this still work? what's the correct time interval. Bug filed: https://linear.app/superwall/issue/SW-1657/[bug]-exit-refresh-not-appearing")
- (void)test17 {
  ASYNC_BEGIN

  // Send event
  [[Superwall sharedInstance] trackWithEvent:@"no_paywalljs"];

  // Wait and assert.
  ASYNC_TEST_ASSERT(30.0);

  ASYNC_END
}

@end
