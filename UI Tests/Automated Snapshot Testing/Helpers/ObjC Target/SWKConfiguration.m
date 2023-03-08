//
//  SWKConfiguration.m
//  Automated Snapshot ObjC
//
//  Created by Bryan Dubno on 3/7/23.
//

#import <Foundation/Foundation.h>
#import "SWKConfiguration.h"

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

// MARK: - Configurations

@interface SWKConfigurationAutomatic : NSObject <SWKTestConfiguration>
@end

// MARK: -

@implementation SnapshotTests_ObjC (Additions)

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

@end

// MARK: - Automatic configuration

@implementation SWKConfigurationAutomatic

- (void)setupWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  // Make sure setup has not been called
  if (SWKConfigurationState.hasConfigured) { return; }
  SWKConfigurationState.hasConfigured = YES;

  ASYNC_BEGIN

  [Superwall configureWithApiKey:SWKConstants.apiKey];

  // Set status
//  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

  // Begin fetching products for use in other test cases
  [[SWKStoreKitHelper shared] fetchCustomProductsWithCompletionHandler:^{
    ASYNC_FULFILL
  }];

  ASYNC_END
  completionHandler();
}

- (void)tearDownWithCompletionHandler:(void (^ _Nonnull)(void))completionHandler {
  ASYNC_BEGIN

  // Reset status
//  [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;

  // Dismiss any view controllers
  [XCTestCase dismissViewControllersWithCompletionHandler:^{
    ASYNC_FULFILL
  }];

  ASYNC_END
  completionHandler();
}

@end
