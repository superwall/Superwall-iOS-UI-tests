//
//  Configuration_ObjC.m
//  UI Tests
//
//  Created by Bryan Dubno on 3/7/23.
//

#import <Foundation/Foundation.h>
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
  [[SWKStoreKitHelper shared] fetchCustomProductsWithCompletionHandler:^{
    completionHandler();
  }];
}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Dismiss any view controllers
  [self dismissViewControllersWithCompletionHandler:^{
    completionHandler();
  }];
}

@end
