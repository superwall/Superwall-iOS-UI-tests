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
@property (nonatomic, copy) void (^handleSuperwallPlacement)(SWKSuperwallPlacementInfo *);
@end

@implementation SWKMockSuperwallDelegate

- (void)handleSuperwallPlacement:(void (^)(SWKSuperwallPlacementInfo *))handler {
  self.handleSuperwallPlacement = handler;
}

- (void)handleSuperwallPlacementWithInfo:(SWKSuperwallPlacementInfo *)placementInfo {
  if (self.handleSuperwallPlacement) {
    self.handleSuperwallPlacement(placementInfo);
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
    NSSet *activeEntitlements = [NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]];
    [[Superwall sharedInstance].entitlements setActiveStatusWith:activeEntitlements];
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
    [[Superwall sharedInstance].entitlements setInactiveStatus];

    completionHandler();
  }];
}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Reset status
  [[Superwall sharedInstance].entitlements setInactiveStatus];

  // Reset identity and user data
  [[Superwall sharedInstance] reset];

  completionHandler();
}

- (void)mockSubscribedUserWithProductIdentifier:(NSString * _Nonnull)productIdentifier completionHandler:(void (^ _Nonnull)(void))completionHandler {
  NSSet *activeEntitlements = [NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]];
  [[Superwall sharedInstance].entitlements setActiveStatusWith:activeEntitlements];
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
        [[Superwall sharedInstance].entitlements setActiveStatusWith:[NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]]];
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

@end

