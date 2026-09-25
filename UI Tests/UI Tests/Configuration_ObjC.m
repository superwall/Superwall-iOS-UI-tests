//
//  Configuration_ObjC.m
//  UI Tests
//
//  Created by Bryan Dubno on 3/7/23.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "UI_Tests-Swift.h"

#import "Configuration_ObjC.h"
#import "UITests_ObjC.h"

@import SuperwallKit;

@interface SWKConfigurationState: NSObject
@property (nonatomic, assign, class) BOOL hasConfigured;
@end

@implementation SWKConfigurationState

static BOOL kHasConfigured = NO;

+ (BOOL)hasConfigured {
  return kHasConfigured;
}

+ (void)setHasConfigured:(BOOL)hasConfigured {
  kHasConfigured = hasConfigured;
}

@end

// MARK: - SWKPaywallViewControllerDelegate

@implementation SWKMockPaywallViewControllerDelegate

- (void)setPaywallViewControllerDidFinish:(void (^)(SWKPaywallViewController *, SWKPaywallResult, BOOL))block {
  _paywallViewControllerDidFinish = [block copy];
}

- (void)paywall:(SWKPaywallViewController *)paywall didFinishWithResult:(enum SWKPaywallResult)result shouldDismiss:(BOOL)shouldDismiss {
  if (self.paywallViewControllerDidFinish) {
    self.paywallViewControllerDidFinish(paywall, result, shouldDismiss);
  }
}

- (void)paywall:(SWKPaywallViewController *)paywall loadingStateDidChange:(enum SWKPaywallLoadingState)loadingState {}

@end

// MARK: - SWKMockSuperwallDelegate

@interface SWKMockSuperwallDelegate ()
@property (nonatomic, copy) void (^handleSuperwallEvent)(SWKSuperwallEventInfo *);
@end

/// Events the SDK sent before a test installed its own handler, while only a
/// delegate from setup was listening. A Swift test's body runs straight after
/// setup, so its delegate is in place before the SDK tracks anything
/// (`appInstall`, `appLaunch`, ...). An Objective-C test starts a moment later
/// and would miss those; they're handed to the first handler it installs.
static NSMutableArray<SWKSuperwallEventInfo *> *SWKEventsBeforeTestHandler;

void SWKRecordEventBeforeTestHandler(SWKSuperwallEventInfo *eventInfo) {
  if (!SWKEventsBeforeTestHandler) {
    SWKEventsBeforeTestHandler = [NSMutableArray array];
  }
  [SWKEventsBeforeTestHandler addObject:eventInfo];
}

@implementation SWKMockSuperwallDelegate

- (void)handleSuperwallEvent:(void (^)(SWKSuperwallEventInfo *))handler {
  self.handleSuperwallEvent = handler;

  NSArray<SWKSuperwallEventInfo *> *earlierEvents = SWKEventsBeforeTestHandler;
  SWKEventsBeforeTestHandler = nil;
  for (SWKSuperwallEventInfo *eventInfo in earlierEvents) {
    handler(eventInfo);
  }
}

- (void)handleSuperwallEventWithInfo:(SWKSuperwallEventInfo *)eventInfo {
  [SWKPresentationObserver recordEventInfo:eventInfo];
  if (self.handleSuperwallEvent) {
    self.handleSuperwallEvent(eventInfo);
  } else {
    SWKRecordEventBeforeTestHandler(eventInfo);
  }
}

@end


// MARK: - Automatic configuration

@interface SWKConfigurationAutomatic()
@end

@implementation SWKConfigurationAutomatic

- (void)setupWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Make sure setup has not been called
  if (SWKConfigurationState.hasConfigured) { return; }
  SWKConfigurationState.hasConfigured = YES;

  // Begin fetching products for use in other test cases
  [[SWKStoreKitHelper sharedInstance] fetchCustomProductsWithCompletionHandler:^{
    [Superwall configureWithApiKey:SWKConstants.currentTestOptions.apiKey
      purchaseController: NULL
      options:SWKConstants.currentTestOptions.options
      completion: NULL
    ];
    // Observe presentation outcomes even in tests that don't set a delegate.
    // The SDK holds delegates weakly, hence the static.
    static SWKMockSuperwallDelegate *defaultDelegate;
    defaultDelegate = [SWKMockSuperwallDelegate new];
    [[Superwall sharedInstance] setDelegate:defaultDelegate];
    completionHandler();
  }];

}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Reset identity and user data
  [[Superwall sharedInstance] reset];

  completionHandler();
}

- (void)mockSubscribedUserWithProductIdentifier:(NSString * _Nonnull)productIdentifier  completionHandler:(void (^ _Nonnull)(void))completionHandler {
  [self activateSubscriptionWithProductIdentifier:productIdentifier completionHandler:^{
    NSSet *activeEntitlements = [NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]];
    [[Superwall sharedInstance] setActiveSubscriptionStatusWith:activeEntitlements];
    [SWKSubscriptionWaiter waitForSubscriptionWithProductIdentifier:productIdentifier completionHandler:^{
      completionHandler();
    }];
  }];
}

@end

// MARK: - Advanced configuration

@interface SWKAdvancedPurchaseController: NSObject <SWKPurchaseController, SWKSuperwallDelegate>
/// Entitlements set by `mockSubscribedUser`. The SDK can notice the purchase a
/// test makes after the mock has set the status, and syncing would then
/// overwrite it; syncing keeps these instead.
@property (nonatomic, strong, nullable) NSSet<SWKEntitlement *> *mockedEntitlements;
- (void)syncSubscriptionStatus;
@end

@interface SWKConfigurationAdvanced()
@property (nonatomic, strong) SWKAdvancedPurchaseController *purchaseController;
@end

@implementation SWKConfigurationAdvanced

- (void)setupWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Make sure setup has not been called
  if (SWKConfigurationState.hasConfigured) { return; }
  SWKConfigurationState.hasConfigured = YES;

  // Begin fetching products for use in other test cases
  [[SWKStoreKitHelper sharedInstance] fetchCustomProductsWithCompletionHandler:^{
    [Superwall configureWithApiKey:SWKConstants.currentTestOptions.apiKey
      purchaseController:self.purchaseController
      options:SWKConstants.currentTestOptions.options
      completion:NULL
    ];

    // Set delegate to listen for customer info changes
    [[Superwall sharedInstance] setDelegate:self.purchaseController];

    // Initialize subscription status
    [self.purchaseController syncSubscriptionStatus];

    completionHandler();
  }];
}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Reset status
  [[Superwall sharedInstance] setInactiveSubscriptionStatus];

  // Reset identity and user data
  [[Superwall sharedInstance] reset];

  completionHandler();
}

- (void)mockSubscribedUserWithProductIdentifier:(NSString * _Nonnull)productIdentifier completionHandler:(void (^ _Nonnull)(void))completionHandler {
  NSSet *activeEntitlements = [NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]];
  self.purchaseController.mockedEntitlements = activeEntitlements;
  [[Superwall sharedInstance] setActiveSubscriptionStatusWith:activeEntitlements];
  completionHandler();
}

- (SWKAdvancedPurchaseController *)purchaseController {
  if (!_purchaseController) {
    _purchaseController = [SWKAdvancedPurchaseController new];
  }

  return _purchaseController;
}

@end

// MARK: - SWKPurchaseController

@implementation SWKAdvancedPurchaseController

- (void)purchaseWithProduct:(SWKStoreProduct *)product completion:(void (^)(enum SWKPurchaseResult, NSError * _Nullable))completion {
  [[SWKStoreKitHelper sharedInstance] purchaseWithProduct:product.sk1Product completionHandler:^(SWKPurchaseResult purchaseResult, NSError *error) {
    switch (purchaseResult) {
      case SWKPurchaseResultPurchased:
        [[Superwall sharedInstance] setActiveSubscriptionStatusWith:[NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]]];
        completion(SWKPurchaseResultPurchased, nil);
        break;
      case SWKPurchaseResultPending:
        completion(SWKPurchaseResultPending, nil);
        break;
      case SWKPurchaseResultFailed:
        completion(SWKPurchaseResultFailed, error);
        break;
      default:
        completion(SWKPurchaseResultCancelled, nil);
        break;
    }
  }];
}

- (void)restorePurchasesWithCompletion:(void (^)(enum SWKRestorationResult, NSError * _Nullable))completion {
  completion(SWKRestorationResultRestored, nil);
}

- (void)syncSubscriptionStatus {
  /// Sync subscription status based on current transactions and web entitlements.
  if (@available(iOS 15.0, *)) {
    NSMutableSet<NSString *> *productIds = [NSMutableSet set];

    // Collect product IDs from active transactions
    [SKPaymentQueue.defaultQueue.transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull transaction, NSUInteger idx, BOOL * _Nonnull stop) {
      if (transaction.transactionState == SKPaymentTransactionStatePurchased ||
          transaction.transactionState == SKPaymentTransactionStateRestored) {
        [productIds addObject:transaction.payment.productIdentifier];
      }
    }];

    // Get device entitlements from product IDs
    NSSet<SWKEntitlement *> *activeDeviceEntitlements = [[Superwall sharedInstance].entitlements byProductIds:productIds];

    // Get web entitlements
    NSSet<SWKEntitlement *> *activeWebEntitlements = [Superwall sharedInstance].entitlements.web;

    // Combine both sets
    NSMutableSet<SWKEntitlement *> *allActiveEntitlements = [activeDeviceEntitlements mutableCopy];
    [allActiveEntitlements unionSet:activeWebEntitlements];

    // Update subscription status, keeping one mocked by the test
    [[Superwall sharedInstance] setActiveSubscriptionStatusWith:self.mockedEntitlements ?: allActiveEntitlements];
  }
}

// MARK: - SWKSuperwallDelegate

- (void)handleSuperwallEventWithInfo:(SWKSuperwallEventInfo *)eventInfo {
  [SWKPresentationObserver recordEventInfo:eventInfo];
  SWKRecordEventBeforeTestHandler(eventInfo);
}

- (void)customerInfoDidChangeFrom:(SWKCustomerInfo *)oldValue to:(SWKCustomerInfo *)newValue {
  /// Every time the customer info changes, sync the subscription status.
  [self syncSubscriptionStatus];
}

@end

