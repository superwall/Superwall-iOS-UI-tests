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

- (void)setPaywallViewControllerDidFinish:(void (^)(SWKPaywallViewController *, SWKPaywallResult))block {
  _paywallViewControllerDidFinish = [block copy];
}

- (void)paywallViewController:(SWKPaywallViewController *)controller didFinishWith:(enum SWKPaywallResult)result {
  if (self.paywallViewControllerDidFinish) {
    self.paywallViewControllerDidFinish(controller, result);
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

  [Superwall configureWithApiKey:SWKConstants.apiKey];

  // Begin fetching products for use in other test cases
  [[SWKStoreKitHelper sharedInstance] fetchCustomProductsWithCompletionHandler:^{
    completionHandler();
  }];
}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Reset identity and user data
  [[Superwall sharedInstance] reset];

  completionHandler();
}

- (void)mockSubscribedUserWithProductIdentifier:(NSString * _Nonnull)productIdentifier  completionHandler:(void (^ _Nonnull)(void))completionHandler {
  [self activateSubscriberWithProductIdentifier:productIdentifier completionHandler:^{
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

  [Superwall configureWithApiKey:SWKConstants.apiKey purchaseController:self.purchaseController options:nil completion:NULL];

  // Set status
  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

  // Begin fetching products for use in other test cases
  [[SWKStoreKitHelper sharedInstance] fetchCustomProductsWithCompletionHandler:^{
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

  [[SWKStoreKitHelper sharedInstance] purchaseWithProduct:product completionHandler:^(SKPaymentTransactionState transactionState) {

    switch (transactionState) {
      case SKPaymentTransactionStatePurchased:
      case SKPaymentTransactionStateRestored:
        [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
        completion(SWKPurchaseResultPurchased, nil);
        break;
      case SKPaymentTransactionStateFailed:
        completion(SWKPurchaseResultFailed, [NSError new]);
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

