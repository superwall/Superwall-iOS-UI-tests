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
  XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@""]; __weak typeof(self) weakSelf = self;

#define ASYNC_END \
  [self waitWithExpectation:expectation];

#define ASYNC_FULFILL \
  [expectation fulfill]; weakSelf;

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
  [self dismissViewControllersWithCompletion:^{
    ASYNC_FULFILL
  }];

  // Remove delegate observers
  [self.mockDelegate removeObservers];

  ASYNC_END
}

- (void)test0 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] identifyWithUserId:@"test0" options:nil completion:^(NSError * _Nullable completion) {

    [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];
    [[Superwall sharedInstance] trackWithEvent:@"present_data"];

    ASYNC_TEST_ASSERT(kPaywallPresentationDelay)
  }];

  ASYNC_END
}

- (void)test1 {
  ASYNC_BEGIN

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test1a" options:nil completion:^(NSError * _Nullable completion) {
    [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];

    // Set new identity.
    [[Superwall sharedInstance] identifyWithUserId:@"test1b" options:nil completion:^(NSError * _Nullable completion) {
      [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Kate" }];
      [[Superwall sharedInstance] trackWithEvent:@"present_data"];

      ASYNC_TEST_ASSERT(kPaywallPresentationDelay)
    }];
  }];

  ASYNC_END
}

#warning https://linear.app/superwall/issue/SW-1625/[bug]-reset-not-clearing-user-attributes-before-presenting-paywall
- (void)test2 {
  ASYNC_BEGIN

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test2" options:nil completion:^(NSError * _Nullable completion) {

    [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" } completion:^{

      // Reset the user identity
      [[Superwall sharedInstance] resetWithCompletion:^{
        [[Superwall sharedInstance] trackWithEvent:@"present_data"];

        ASYNC_TEST_ASSERT(kPaywallPresentationDelay)
      }];
    }];

  }];

  ASYNC_END
}

- (void)test3 {
  ASYNC_BEGIN

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test3" options:nil completion:^(NSError * _Nullable completion) {

    [[Superwall sharedInstance] setUserAttributesDictionary:@{ @"first_name" : @"Jack" }];

    // Reset the user identity twice
    [[Superwall sharedInstance] resetWithCompletion:^{

      [[Superwall sharedInstance] resetWithCompletion:^{

        [[Superwall sharedInstance] trackWithEvent:@"present_data"];

        ASYNC_TEST_ASSERT(kPaywallPresentationDelay)

      }];
    }];
  }];

  ASYNC_END
}

- (void)test4 {
  ASYNC_BEGIN

  [[Superwall sharedInstance] trackWithEvent:@"present_video"];

  [self sleepWithTimeInterval:4.0 completionHandler:^{
    [[Superwall sharedInstance] dismissWithCompletion:^{
      [self sleepWithTimeInterval:1.0 completionHandler:^{
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

- (void)test6 {
  ASYNC_BEGIN

  // Present the paywall.
  [[Superwall sharedInstance] trackWithEvent:@"present_products"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

- (void)test7 {
  ASYNC_BEGIN

  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7" options:nil completion:^(NSError * _Nullable error) {
    [[Superwall sharedInstance] setUserAttributesDictionary:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @14}];
    [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

    ASYNC_TEST_ASSERT(kPaywallPresentationDelay);
  }];

  ASYNC_END
}

- (void)test8 {
  ASYNC_BEGIN

  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7" options:nil completion:^(NSError * _Nullable error) {
    [[Superwall sharedInstance] setUserAttributesDictionary:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @12}];
    [[Superwall sharedInstance] trackWithEvent:@"present_and_rule_user"];

    ASYNC_TEST_ASSERT(kPaywallPresentationDelay);
  }];

  ASYNC_END
}

- (void)test9 {
  ASYNC_BEGIN

  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
  [[Superwall sharedInstance] trackWithEvent:@"present_always"];

  ASYNC_TEST_ASSERT(kPaywallPresentationDelay);

  ASYNC_END
}

@end
