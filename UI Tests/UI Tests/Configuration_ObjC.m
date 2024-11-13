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

@end

// MARK: - SWKMockSuperwallDelegate

@interface SWKMockSuperwallDelegate ()
@property (nonatomic, copy) void (^handleSuperwallEvent)(SWKSuperwallEventInfo *);
@end

@implementation SWKMockSuperwallDelegate

- (void)handleSuperwallEvent:(void (^)(SWKSuperwallEventInfo *))handler {
  self.handleSuperwallEvent = handler;
}

- (void)handleSuperwallEventWithInfo:(SWKSuperwallEventInfo *)eventInfo {
  if (self.handleSuperwallEvent) {
    self.handleSuperwallEvent(eventInfo);
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
    completionHandler();
  }];
}

@end

// MARK: - Advanced configuration

@interface SWKAdvancedPurchaseController: NSObject <SWKPurchaseController>
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

    // Set status
    [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

    completionHandler();
  }];
}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Reset status
  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

  // Reset identity and user data
  [[Superwall sharedInstance] reset];

  completionHandler();
}

- (void)mockSubscribedUserWithProductIdentifier:(NSString * _Nonnull)productIdentifier completionHandler:(void (^ _Nonnull)(void))completionHandler {
  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
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

- (void)purchaseWithProduct:(SKProduct *)product completion:(void (^)(enum SWKPurchaseResult, NSError * _Nullable))completion {
  [[SWKStoreKitHelper sharedInstance] purchaseWithProduct:product completionHandler:^(SWKPurchaseResult purchaseResult, NSError *error) {
    switch (purchaseResult) {
      case SWKPurchaseResultPurchased:
        [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
        completion(SWKPurchaseResultPurchased, nil);
        break;
      case SWKPurchaseResultPending:
        completion(SWKPurchaseResultPending, nil);
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

@end

