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
__weak typeof(self) weakSelf = self; dispatch_group_t group = dispatch_group_create(); for (NSInteger i = 0; i < numAsserts; i++){ dispatch_group_enter(group); } dispatch_group_notify(group, dispatch_get_main_queue(), ^{ completionHandler(nil); }); NSString *testName = [NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__];

#define TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(delay, captureAreaValue, completionHandlerValue) \
[weakSelf assertAfter:delay testName:testName precision:SWKPrecisionValueDefault captureArea:captureAreaValue completionHandler:^{ dispatch_group_leave(group); if(completionHandlerValue != nil) { completionHandlerValue(); }}];

#define TEST_ASSERT_DELAY_COMPLETION(delay, completionHandlerValue) \
TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(delay, [SWKCaptureArea safeAreaNoHomeIndicator], completionHandlerValue)

#define TEST_ASSERT_COMPLETION(completionHandlerValue) \
TEST_ASSERT_DELAY_COMPLETION(0, ^{})

#define TEST_ASSERT_VALUE_COMPLETION(value, completionHandlerValue) \
[weakSelf assertWithValue:value testName:testName completionHandler:^{ dispatch_group_leave(group); if(completionHandlerValue != nil) { completionHandlerValue(); }}];

#define TEST_ASSERT_DELAY_VALUE_COMPLETION(delay, value, completionHandlerValue) \
[weakSelf sleepWithTimeInterval:delay completionHandler:^{ TEST_ASSERT_VALUE_COMPLETION(value, completionHandlerValue) }];

#define TEST_SKIP(message) \
[self skip:message]; completionHandler(nil); return;

#define FATAL_ERROR(message) \
NSCAssert(false, message);

#pragma mark - UITests_ObjC

// Constants
static NSTimeInterval kPaywallPresentationDelay;
static NSTimeInterval kImplicitPaywallPresentationDelay;
static NSTimeInterval kPaywallPresentationFailureDelay;
static NSTimeInterval kPaywallDelegateResponseDelay;

@interface UITests_ObjC () <Testable>
@end

@interface UITests_ObjC (Logging)
- (void)print:(NSString *)format, ...;
@end

@implementation UITests_ObjC (Logging)
- (void)print:(NSString *)format, ... {
  va_list args;
  va_start(args, format);
  NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  [self log:formattedString];
}
@end

@implementation UITests_ObjC

static id<SWKTestConfiguration> kConfiguration;

- (id<SWKTestConfiguration>)configuration {
  if (!kConfiguration) {
    NSString *configurationType = SWKConstants.configurationType;
    if ([configurationType isEqualToString:@"automatic"]) {
      kConfiguration = [SWKConfigurationAutomatic new];
    }
    else if ([configurationType isEqualToString:@"advanced"]) {
      kConfiguration = [SWKConfigurationAdvanced new];
    }
    else {
      NSAssert(NO, @"Could not find ObjC test configuration type");
    }
  }
  
  return kConfiguration;
}

+ (void)initialize {
  kPaywallPresentationDelay = SWKConstants.paywallPresentationDelay;
  kImplicitPaywallPresentationDelay = SWKConstants.implicitPaywallPresentationDelay;
  kPaywallPresentationFailureDelay = SWKConstants.paywallPresentationFailureDelay;
  kPaywallDelegateResponseDelay = SWKConstants.paywallDelegateResponseDelay;
}

// Uses the identify function. Should see the name 'Jack' in the paywall.
- (void)test0WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Uses the identify function. Should see the name 'Kate' in the paywall.
- (void)test1WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test1a"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  
  // Set new identity.
  [[Superwall sharedInstance] identifyWithUserId:@"test1b"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Kate" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Calls `reset()`. No first name should be displayed.
- (void)test2WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test2"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  
  // Reset the user identity
  [[Superwall sharedInstance] reset];
  
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Calls `reset()` multiple times. No first name should be displayed.
- (void)test3WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test3"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  
  // Reset the user identity twice
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];
  
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning with a 0 on the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and we want to capture the video as quickly as possible.
- (void)test4WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] registerWithPlacement:@"present_video"];
  
  // Wait 4 seconds before dismissing the video
  [self sleepWithTimeInterval:4.0 completionHandler:^{
    [[Superwall sharedInstance] dismissWithCompletion:^{
      // Once the video has been dismissed, wait 1 second before dismissing again
      [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
        [[Superwall sharedInstance] registerWithPlacement:@"present_video"];
        
        // Assert that the video has started from the 0 sec mark (video simply counts from 0sec to 2sec and only displays those 2 values)
        TEST_ASSERT_DELAY_COMPLETION(2.0, ^{})
      }];
    }];
  }];
}

- (SWKTestOptions *)testOptions5 {
  return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier];
}
- (void)test5WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;
  SKProduct *secondary = [SWKStoreKitHelper sharedInstance].sk1AnnualProduct;
  
  if (!primary || !secondary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }
  
  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];

  // Create PaywallOverrides
  SWKPaywallOverrides *paywallOverrides = [[SWKPaywallOverrides alloc] initWithProductsByName:@{
    @"primary": primaryProduct,
    @"secondary": secondaryProduct
  }];
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:delegate];
  
  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_products" params:nil paywallOverrides:paywallOverrides delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
      
      // Assert after a delay
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    } else {
      // Handle error
      completionHandler(result.error);
    }
  }];
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
- (void)test6WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Present the paywall.
  [[Superwall sharedInstance] registerWithPlacement:@"present_products"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
- (void)test7WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @14}];
  [[Superwall sharedInstance] registerWithPlacement:@"present_and_rule_user"];
  
  // Assert after a delay
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove those attributes.
      [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];
      [[Superwall sharedInstance] registerWithPlacement:@"present_and_rule_user"];

      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    }];
  }));
}

// Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
- (void)test8WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @12}];
  [[Superwall sharedInstance] registerWithPlacement:@"present_and_rule_user"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Present regardless of status
- (SWKTestOptions *)testOptions9 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test9WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
    [[Superwall sharedInstance] registerWithPlacement:@"present_always"];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products. After dismiss, paywall should be presented one last time with no override products.
- (void)test10WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Paywall Overrides don't work with register")
  //
  //  TEST_START_NUM_ASSERTS(3)
  //
  //  // Present the paywall.
  //  [[Superwall sharedInstance] registerWithPlacement:@"present_products"];
  //
  //  // Wait and assert.
  //  [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
  //    // Assert original products.
  //    TEST_ASSERT(0);
  //
  //    // Dismiss any view controllers
  //    [weakSelf dismissViewControllersWithCompletionHandler:^{
  //
  //      // Create override products
  //      SKProduct *monthlyProduct = SWKStoreKitHelper.shared.monthlyProduct;
  //      SKProduct *annualProduct = SWKStoreKitHelper.shared.annualProduct;
  //
  //      SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:monthlyProduct];
  //      SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:annualProduct];
  //
  //      SWKPaywallProducts *products = [[SWKPaywallProducts alloc] initWithPrimary:primaryProduct secondary:secondaryProduct tertiary:nil];
  //
  //      // Override original products with new ones.
  //      [[Superwall sharedInstance] trackWithEvent:@"present_products" params:nil products:products ignoreSubscriptionStatus:NO presentationStyleOverride:SWKPaywallPresentationStyleNone onSkip:nil onPresent:nil onDismiss:nil];
  //
  //      // Wait and assert.
  //      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
  //        // Assert override products.
  //        TEST_ASSERT(0);
  //
  //        // Dismiss any view controllers
  //        [weakSelf dismissViewControllersWithCompletionHandler:^{
  //
  //          // Present the paywall.
  //          [[Superwall sharedInstance] trackWithEvent:@"present_products"];
  //
  //          // Assert original products.
  //          TEST_ASSERT(kPaywallPresentationDelay);
  //
  //        }];
  //      }];
  //    }];
  //  }];
}

// Clear a specific user attribute.
- (void)test11WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3);
  
  // Add user attribute
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Claire" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
  
  // Assert that the first name is displayed
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove user attribute
      [[Superwall sharedInstance] removeUserAttributes:@[@"first_name"]];
      [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
      
      // Assert that the first name is NOT displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Add new user attribute
          [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Sawyer" }];
          [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }));
    }];
  }));
}

// Test trigger: off
- (void)test12WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] registerWithPlacement:@"keep_this_trigger_off"];
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Test trigger: not in the dashboard
- (void)test13WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] registerWithPlacement:@"i_just_made_this_up_and_it_dne"];
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Test trigger: not-allowed standard event (paywall_close)
- (void)test14WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
  
  // After delay, assert that there was a presentation
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    }];
  }));
}

// Clusterfucks by Jake™
- (void)test15WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Present paywall
  [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
  [[Superwall sharedInstance] registerWithPlacement:@"present_always" params:@{@"some_param_1": @"hello"}];
  [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
  
  // After delay, assert that there was a presentation
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      
      [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
      [[Superwall sharedInstance] identifyWithUserId:@"1111"];
      [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
      
      // After delay, assert that there was a presentation
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          
          SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];
          __block NSString *experimentId;
          
          [handler onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
            [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
            experimentId = paywallInfo.experiment.id;
            // Wait and assert.
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
              TEST_ASSERT_VALUE_COMPLETION(experimentId, ^{});
            });
          }];
          
          // Present paywall
          [[Superwall sharedInstance] registerWithPlacement:@"present_always" params:nil handler:handler];
        }];
      }));
    }];
  }));
}

// Present an alert on Superwall.presentedViewController from the onPresent callback
- (void)test16WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];
  [handler onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:@"This is an alert message" preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:okAction];
      
      UIViewController *presentingViewController = [Superwall sharedInstance].presentedViewController;
      [presentingViewController presentViewController:alertController animated:NO completion:nil];
    });
  }];
  
  [[Superwall sharedInstance] registerWithPlacement:@"present_always" params:nil handler:handler];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Clusterfucks by Jake™
- (void)test17WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
  
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Set identity
      [[Superwall sharedInstance] identifyWithUserId:@"test2"];
      [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
      
      // Reset the user identity
      [[Superwall sharedInstance] reset];
      
      [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
      
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Present paywall
          [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
          [[Superwall sharedInstance] registerWithPlacement:@"present_always" params:@{@"some_param_1": @"hello"}];
          [[Superwall sharedInstance] registerWithPlacement:@"present_always"];

          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }));
    }];
  }));
}

- (void)test18WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:delegate];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_urls" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }
    
    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Position of the perform button to open a URL in Safari
      CGPoint point = CGPointMake(330, 212);
      [weakSelf touch:point];
      
      // Verify that In-App Safari has opened
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Press the done button to go back
        CGPoint donePoint = CGPointMake(30, 70);
        [weakSelf touch:donePoint];
        
        // Verify that the paywall appears
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
      }));
    }));
  }];
}

// Clusterfucks by Jake™
- (void)test19WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)
  
  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test19a"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Jack"}];
  
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
  
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      
      [[Superwall sharedInstance] getPresentationResultForPlacement:@"present_and_rule_user" completionHandler:^(SWKPresentationResult * _Nonnull result) {

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          
          // Show a paywall
          [[Superwall sharedInstance] registerWithPlacement:@"present_always"];
          
          // Assert that paywall was displayed
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
            // Dismiss any view controllers
            [weakSelf dismissViewControllersWithCompletionHandler:^{
              // Assert that no paywall is displayed as a result of the Superwall-owned paywall_close standard event.
              TEST_ASSERT_DELAY_COMPLETION(0, (^{
                // Dismiss any view controllers
                [weakSelf dismissViewControllersWithCompletionHandler:^{
                  
                  // Set identity
                  [[Superwall sharedInstance] identifyWithUserId:@"test19b"];
                  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Jack"}];
                  
                  // Set new identity
                  [[Superwall sharedInstance] identifyWithUserId:@"test19c"];
                  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Kate"}];
                  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

                  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
                }];
              }));
            }];
          }));
        }];
      }];
    }];
  }));
}

/// Verify that external URLs can be opened in native Safari from paywall
- (void)test20WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Present paywall with URLs
  [[Superwall sharedInstance] registerWithPlacement:@"present_urls"];
  
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Position of the perform button to open a URL in Safari
    CGPoint point = CGPointMake(330, 136);
    [weakSelf touch:point];
    
    // Verify that Safari has opened.
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea safari], ^{
      // Relaunch the parent app.
      [weakSelf relaunchWithCompletionHandler:^{
        // Ensure nothing has changed.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
      }];
    });
  }));
}

/// Present the paywall and purchase; then make sure the paywall doesn't get presented again after the purchase
- (void)test21WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Register event to present the paywall
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
  
  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 750);
    [weakSelf touch:purchaseButton];
    
    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];
      
      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];
        
        // Try to present paywall again
        [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
        
        // Ensure the paywall doesn't present.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
      }];
    }));
  }));
}

/// Track an event shortly after another one is beginning to present. The session should not be cancelled out.
- (void)test22WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Write from Swift version")
}

/// Case: Unsubscribed user, register event without a gating handler
/// Result: paywall should display
- (void)test23WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Register event
  [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall"];
  
  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

/// Case: Subscribed user, register event without a gating handler
/// Result: paywall should NOT display
- (SWKTestOptions *)testOptions24 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test24WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Mock user as subscribed
  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{

    // Register event
    [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall"];

    // Assert that paywall DOES not appear
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

/// Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
/// Result: paywall should display, after user subscribes, don't show another paywall
- (void)test25WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Register event
  [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall"];
  
  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 748);
    [weakSelf touch:purchaseButton];
    
    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];
      
      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];

        [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
          // Try to present paywall again
          [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall"];

          // Ensure the paywall doesn't present.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }];
    }));
  }));
}

/// Case: Unsubscribed user, register event with a gating handler
/// Result: paywall should display, code in gating closure should not execute
- (void)test26WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"register_gated_paywall" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];
  
  // Assert that alert appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint purchaseButton = CGPointMake(352, 65);
    [weakSelf touch:purchaseButton];
    
    // Assert that nothing else appears
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }));
}

/// Case: Subscribed user, register event with a gating handler
/// Result: paywall should NOT display, code in gating closure should execute
- (SWKTestOptions *)testOptions27 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test27WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Mock user as subscribed
  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{

    // Register event and present an alert controller
    [[Superwall sharedInstance] registerWithPlacement:@"register_gated_paywall" params:nil handler:nil feature:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                                 message:@"This is an alert message"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:action];
        [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
      });
    }];

    // Assert that alert controller appears
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

// Presentation result: `paywall`
- (void)test28WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForPlacement:@"present_data" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

// Presentation result: `noRuleMatch`
- (void)test29WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Remove user attributes
  [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];
  
  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForPlacement:@"present_and_rule_user" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

// Presentation result: `eventNotFound`
- (void)test30WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForPlacement:@"some_random_not_found_event" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

// Presentation result: `holdOut`
- (void)test31WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForPlacement:@"holdout" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

// Presentation result: `userIsSubscribed`
- (SWKTestOptions *)testOptions32 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test32WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Mock user as subscribed
  [self handleSubscriptionMockingWithSubscribed:YES completionHandler:^{
    // Get the presentation result for the specified event
    [[Superwall sharedInstance] getPresentationResultForPlacement:@"present_data" completionHandler:^(SWKPresentationResult * _Nonnull result) {
      // Assert the value of the result's description
      NSString *value = [SWKPresentationValueObjcHelper description:result.value];
      TEST_ASSERT_VALUE_COMPLETION(value, ^{})
    }];
  }];
}

/// Call identify twice with the same ID before presenting a paywall
- (void)test33WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test33"];
  [[Superwall sharedInstance] identifyWithUserId:@"test33"];
  
  // Register event
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
  
  // Assert after a delay
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

/// Call reset while a paywall is displayed should not cause a crash
- (void)test34WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Register event
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];
  
  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Call reset while it is still on screen
    [[Superwall sharedInstance] reset];
    
    // Assert after a delay
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }));
}

// Finished purchase with a result type of `purchased`
- (void)test35WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];

  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }
    
    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Purchase on the paywall
      CGPoint purchaseButton = CGPointMake(196, 750);
      [weakSelf touch:purchaseButton];
      
      // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
      CGRect customFrame = CGRectMake(0, 488, 393, 300);
      TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
        // Tap the Subscribe button
        CGPoint subscribeButton = CGPointMake(196, 766);
        [weakSelf touch:subscribeButton];
        
        // Wait for subscribe to occur
        [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
          // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
          CGPoint okButton = CGPointMake(196, 495);
          [weakSelf touch:okButton];
          
          // Wait for the delegate function to be called
          [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
            // Assert didFinish paywall result value
            NSString *value = paywallDidFinishResultValueHolder.stringValue;
            TEST_ASSERT_VALUE_COMPLETION(value, ^{});
          }];
        }];
      }));
    }));
  }];
}

// Finished purchase with a result type of `declined`
- (void)test36WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];
  
  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }
    
    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Close the paywall
      CGPoint closeButton = CGPointMake(346, 54);
      [weakSelf touch:closeButton];
      
      // Wait for the delegate function to be called
      [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
        // Assert didFinish paywall result value
        NSString *value = paywallDidFinishResultValueHolder.stringValue;
        TEST_ASSERT_VALUE_COMPLETION(value, ^{});
      }];
    }));
  }];
}

// Finished purchase with a result type of `restored`
- (void)test37WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];
  
  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"restore" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }
    
    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Mock user as subscribed
      [weakSelf.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
        // Press restore
        CGPoint restoreButton = CGPointMake(200, 232);
        [weakSelf touch:restoreButton];
        
        // Wait for the delegate function to be called
        [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
          // Assert didFinish paywall result value
          NSString *value = paywallDidFinishResultValueHolder.stringValue;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }];
      }];
    }));
  }];
}

// Finished purchase with a result type of `purchased` and then swiping the paywall view controller away
- (void)test38WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(5)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];
  
  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }
    
    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Purchase on the paywall
      CGPoint purchaseButton = CGPointMake(196, 750);
      [weakSelf touch:purchaseButton];
      
      // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
      CGRect customFrame = CGRectMake(0, 488, 393, 300);
      TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
        // Tap the Subscribe button
        CGPoint subscribeButton = CGPointMake(196, 766);
        [weakSelf touch:subscribeButton];
        
        // Wait for subscribe to occur
        [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
          // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
          CGPoint okButton = CGPointMake(196, 495);
          [weakSelf touch:okButton];
          
          // Wait for the delegate function to be called
          [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
            // Assert paywall did finish result value
            NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
            TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, (^{
              // Modify the didFinish paywall did finish result value
              paywallDidFinishResultValueHolder.stringValue = @"empty value";

              // Swipe the paywall down to dismiss
              [weakSelf swipeDown];

              // Assert the paywall was dismissed
              TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
                // Assert paywall did finish result value
                NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
                TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, ^{});
              }));
            }));
          }];
        }];
      }));
    }));
  }];
}

// Finished restore with a result type of `restored` and then swiping the paywall view controller away (does it get called twice?)
- (void)test39WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [weakSelf holdStrongly:delegate];
  
  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"restore" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }
    
    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Mock user as subscribed
      [weakSelf.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
        // Press restore
        CGPoint restoreButton = CGPointMake(214, 292);
        [weakSelf touch:restoreButton];
        
        // Wait for the delegate function to be called
        [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
          // Assert paywall did finish result value ("restored")
          NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
          TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, (^{
            // Modify the paywall didFinish result value
            paywallDidFinishResultValueHolder.stringValue = @"empty value";

            // Swipe the paywall down to dismiss
            [weakSelf swipeDown];

            // Assert the paywall was dismissed
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
              // Assert paywall did finish result value ("empty value")
              NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
              TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, ^{});
            }));
          }));
        }];
      }];
    }));
  }];
}

// Paywall disappeared with a result type of `declined` by swiping the paywall view controller away
- (void)test40WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];
  
  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];
  
  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];
  
  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Swipe the paywall down to dismiss
      [weakSelf swipeDown];
      
      // Assert the paywall was dismissed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Wait for the delegate function to be called
        [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
          // Assert paywall did finish result value ("declined")
          NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
          TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, ^{});
        }];
      }));
    }));
  }];
}

- (void)handleSubscriptionMockingWithSubscribed:(BOOL)subscribed completionHandler:(void (^ _Nonnull)(void))completionHandler {
  if (!subscribed) {
    completionHandler();
    return;
  }

  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:completionHandler];
}

- (void)executeRegisterFeatureClosureTestWithSubscribed:(BOOL)subscribed gated:(BOOL)gated testName:(NSString * _Nonnull)testNameOverride completionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  testName = testNameOverride;

  // Perform subscribe again in case of advanced setup which can't be configured before SDK configuration.
  [self handleSubscriptionMockingWithSubscribed:subscribed completionHandler:^{
    NSString *event = gated ? @"register_gated_paywall" : @"register_nongated_paywall";

    SWKValueDescriptionHolder *errorHandlerHolder = [SWKValueDescriptionHolder new];
    errorHandlerHolder.stringValue = @"No";

    SWKPaywallPresentationHandler *paywallPresentationHandler = [[SWKPaywallPresentationHandler alloc] init];
    [paywallPresentationHandler onError:^(NSError * _Nonnull error) {
      errorHandlerHolder.intValue += 1;
      errorHandlerHolder.stringValue = @"Yes";
    }];

    SWKValueDescriptionHolder *featureClosureHolder = [SWKValueDescriptionHolder new];
    featureClosureHolder.stringValue = @"No";

    [[Superwall sharedInstance] registerWithPlacement:event params:nil handler:paywallPresentationHandler feature:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        featureClosureHolder.intValue += 1;
        featureClosureHolder.stringValue = @"Yes";
      });
    }];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      TEST_ASSERT_VALUE_COMPLETION(errorHandlerHolder.description, (^{
        TEST_ASSERT_VALUE_COMPLETION(featureClosureHolder.description, ^{});
      }));
    }));
  }];
}

- (void)executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:(BOOL)subscribed gated:(BOOL)gated testName:(NSString * _Nonnull)testNameOverride completionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  testName = testNameOverride;

  // Perform subscribe again in case of advanced setup which can't be configured before SDK configuration.
  [self handleSubscriptionMockingWithSubscribed:subscribed completionHandler:^{
    NSString *event = gated ? @"register_gated_paywall_v4" : @"register_nongated_paywall_v4";

    SWKValueDescriptionHolder *errorHandlerHolder = [SWKValueDescriptionHolder new];
    errorHandlerHolder.stringValue = @"No";

    SWKPaywallPresentationHandler *paywallPresentationHandler = [[SWKPaywallPresentationHandler alloc] init];
    [paywallPresentationHandler onError:^(NSError * _Nonnull error) {
      errorHandlerHolder.intValue += 1;
      errorHandlerHolder.stringValue = @"Yes";
    }];

    SWKValueDescriptionHolder *featureClosureHolder = [SWKValueDescriptionHolder new];
    featureClosureHolder.stringValue = @"No";

    [[Superwall sharedInstance] registerWithPlacement:event params:nil handler:paywallPresentationHandler feature:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        featureClosureHolder.intValue += 1;
        featureClosureHolder.stringValue = @"Yes";
      });
    }];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      TEST_ASSERT_VALUE_COMPLETION(errorHandlerHolder.description, (^{
        TEST_ASSERT_VALUE_COMPLETION(featureClosureHolder.description, ^{});
      }));
    }));
  }];
}

// Unable to fetch config, not subscribed, and not gated.
- (SWKTestOptions *)testOptions41 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO]; }
- (void)test41WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:NO gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Unable to fetch config, not subscribed, and gated.
- (SWKTestOptions *)testOptions42 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO]; }
- (void)test42WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:NO gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Unable to fetch config, subscribed, and not gated.
- (SWKTestOptions *)testOptions43 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO purchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test43WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:YES gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Unable to fetch config, subscribed, and gated.
- (SWKTestOptions *)testOptions44 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO purchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test44WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:YES gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, not subscribed, and not gated.
- (void)test45WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:NO gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, not subscribed, and gated.
- (void)test46WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:NO gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, subscribed, and not gated.
- (SWKTestOptions *)testOptions47 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test47WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:YES gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, subscribed, and gated.
- (SWKTestOptions *)testOptions48 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test48WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribed:YES gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

/// Present paywall from implicit trigger: `app_launch`.
- (SWKTestOptions *)testOptions49 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.appLaunchAPIKey]; }
- (void)test49WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Ensure nothing has changed.
  TEST_ASSERT_DELAY_COMPLETION(kImplicitPaywallPresentationDelay, ^{})
}

/// Present paywall from implicit trigger: `session_start`.
- (SWKTestOptions *)testOptions50 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.sessionStartAPIKey]; }
- (void)test50WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Ensure nothing has changed.
  TEST_ASSERT_DELAY_COMPLETION(kImplicitPaywallPresentationDelay, ^{})
}

/// Present paywall from implicit trigger: `app_install`.
- (SWKTestOptions *)testOptions51 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.appInstallAPIKey]; }
- (void)test51WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Ensure nothing has changed.
  TEST_ASSERT_DELAY_COMPLETION(kImplicitPaywallPresentationDelay, ^{})
}

- (void)test52WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *appInstallEventHolder = [SWKValueDescriptionHolder new];
  appInstallEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementAppInstall:
        appInstallEventHolder.intValue += 1;
        appInstallEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Close and reopen app
  [weakSelf springboardWithCompletionHandler:^{
    [weakSelf sleepWithTimeInterval:3.0 completionHandler:^{
      [weakSelf relaunchWithCompletionHandler:^{
        // Assert that `.appInstall` was called once
        TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, appInstallEventHolder.description, ^{});
      }];
    }];
  }];
}

- (void)test53WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *appLaunchEventHolder = [SWKValueDescriptionHolder new];
  appLaunchEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementAppLaunch:
        appLaunchEventHolder.intValue += 1;
        appLaunchEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Close and reopen app
  [weakSelf springboardWithCompletionHandler:^{
    [weakSelf relaunchWithCompletionHandler:^{
      // Assert that `.appLaunch` was called once
      TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, appLaunchEventHolder.description, ^{});
    }];
  }];
}

- (void)test54WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *sessionStartEventHolder = [SWKValueDescriptionHolder new];
  sessionStartEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSessionStart:
        sessionStartEventHolder.intValue += 1;
        sessionStartEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Assert that `.sessionStart` was called once
  TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, sessionStartEventHolder.description, ^{});
}

- (void)test55WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *appOpenEventHolder = [SWKValueDescriptionHolder new];
  appOpenEventHolder.stringValue = @"No";

  // Create value handler
  SWKValueDescriptionHolder *appCloseEventHolder = [SWKValueDescriptionHolder new];
  appCloseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementAppClose:
        appCloseEventHolder.intValue += 1;
        appCloseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementAppOpen:
        appOpenEventHolder.intValue += 1;
        appOpenEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Close app
  [weakSelf springboardWithCompletionHandler:^{

    // Assert that `.appClose` was called once
    TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, appCloseEventHolder.description, ^{

      // Re-open app
      [weakSelf relaunchWithCompletionHandler:^{

        // Assert that `.appOpen` was called once
        TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, appOpenEventHolder.description, ^{});
      }];
    });
  }];
}

- (void)test56WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  NSString *urlString = @"exampleapp://?superwall_debug=true&paywall_id=7872&token=sat_eyJhbGciOiJIUzI1NiJ9.eyJzY29wZXMiOlt7InNjb3BlIjoicGF5d2FsbF9wcmV2aWV3IiwiYXBwbGljYXRpb25JZCI6MTI3MH1dLCJpYXQiOjE2ODg2MjgxNTIsImV4cCI6NTA2NTI4Nzg3MiwiYXVkIjoicHduIiwiaXNzIjoicHduIiwic3ViIjoiNzAifQ.J0QNaycFlGY8ZQGBUwrySxkX43iPH2iV646EvJ5TvCg";
  NSURL *url = [[NSURL alloc] initWithString:urlString];
  BOOL handled = [[Superwall sharedInstance] handleDeepLink:url];

  // Create value handler
  SWKValueDescriptionHolder *deepLinkEventHolder = [SWKValueDescriptionHolder new];
  deepLinkEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementDeepLink:
        deepLinkEventHolder.intValue += 1;
        deepLinkEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  NSString *handledString = handled ? @"true" : @"false";

  // Assert that deep link was handled
  TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, handledString, (^{

    // Assert that `.deepLink` was called once
    TEST_ASSERT_VALUE_COMPLETION(deepLinkEventHolder.description, (^{
      // Tap the Preview button
      CGPoint previewButton = CGPointMake(196, 775);
      [weakSelf touch:previewButton];

      [weakSelf sleepWithTimeInterval:2.0 completionHandler:^{
        // Tap the Free Trial button
        CGPoint freeTrialButton = CGPointMake(196, 665);
        [weakSelf touch:freeTrialButton];

        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          // Tap the close button
          CGPoint closeButton = CGPointMake(196, 91);
          [weakSelf touch:closeButton];

          [weakSelf sleepWithTimeInterval:2.0 completionHandler:^{
            // Tap the preview button
            [weakSelf touch:previewButton];

            [weakSelf sleepWithTimeInterval:2.0 completionHandler:^{
              // Tap the default view
              CGPoint defaultButton = CGPointMake(196, 725);
              [weakSelf touch:defaultButton];

              TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{});
            }];
          }];
        }));
      }];
    }));
  }));
}

- (SWKTestOptions *)testOptions57 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.deepLinkOpenAPIKey]; }
- (void)test57WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  NSURL *url = [[NSURL alloc] initWithString:@"exampleapp://mydeepLink?isDeepLink=true"];
  BOOL handled = [[Superwall sharedInstance] handleDeepLink:url];

  // Create value handler
  SWKValueDescriptionHolder *deepLinkEventHolder = [SWKValueDescriptionHolder new];
  deepLinkEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementDeepLink:
        deepLinkEventHolder.intValue += 1;
        deepLinkEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  NSString *handledString = handled ? @"true" : @"false";

  // Assert that deep link was handled
  TEST_ASSERT_DELAY_VALUE_COMPLETION(kImplicitPaywallPresentationDelay, handledString, (^{

    // Assert that `.deepLink` was called once
    TEST_ASSERT_VALUE_COMPLETION(deepLinkEventHolder.description, (^{
      // Assert paywall presented.
      TEST_ASSERT_COMPLETION(^{})
    }))
  }));
}

- (SWKTestOptions *)testOptions58 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.transactionAbandonAPIKey]; }
- (void)test58WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionAbandonEventHolder = [SWKValueDescriptionHolder new];
  transactionAbandonEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTransactionAbandon:
        transactionAbandonEventHolder.intValue += 1;
        transactionAbandonEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger"];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 750);
    [weakSelf touch:purchaseButton];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint abandonTransactionButton = CGPointMake(359, 515);
      [weakSelf touch:abandonTransactionButton];

      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
        // Assert that `.transactionAbandon` was called once
        TEST_ASSERT_VALUE_COMPLETION(transactionAbandonEventHolder.description, ^{});
      });
    }));
  }));
}

- (SWKTestOptions *)testOptions59 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.paywallDeclineAPIKey]; }
- (void)test59WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(5)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create paywall decline value handler
  SWKValueDescriptionHolder *paywallDeclineEventHolder = [SWKValueDescriptionHolder new];
  paywallDeclineEventHolder.stringValue = @"No";

  // Create survey response value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementPaywallDecline:
        paywallDeclineEventHolder.intValue += 1;
        paywallDeclineEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger"];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Decline the paywall
    CGPoint declineButton = CGPointMake(358, 59);
    [weakSelf touch:declineButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
      // Tap the first option
      CGPoint firstOption = CGPointMake(196, 733);
      [weakSelf touch:firstOption];

      // Assert the next paywall is displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
        // Assert that `.paywallDecline` was called once
        TEST_ASSERT_VALUE_COMPLETION(paywallDeclineEventHolder.description, ^{});

        // Assert that `.surveyResponse` was called once
        TEST_ASSERT_VALUE_COMPLETION(surveyResponseEventHolder.description, ^{});
      });
    });
  }));
}

- (SWKTestOptions *)testOptions60 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.transactionFailAPIKey]; }
- (void)test60WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionFailEventHolder = [SWKValueDescriptionHolder new];
  transactionFailEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTransactionFail:
        transactionFailEventHolder.intValue += 1;
        transactionFailEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Fail all transactions
  [self failTransactionsWithCompletionHandler:^{
    [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger"];

    // Assert that paywall was presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
      // Purchase on the paywall
      CGPoint purchaseButton = CGPointMake(196, 750);
      [weakSelf touch:purchaseButton];

      // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
      CGRect customFrame = CGRectMake(0, 488, 393, 300);
      TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
        // Tap subscribe button.
        CGPoint subscribeButton = CGPointMake(196, 766);
        [weakSelf touch:subscribeButton];

        // Assert that paywall was presented
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
          // Assert that `.transactionFail` was called
          TEST_ASSERT_VALUE_COMPLETION(transactionFailEventHolder.description, ^{});
        });
      }));
    });
  }];
}

- (void)test61WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Need to add mechanism for restart")
}

/// Verify that an invalid URL like `#` doesn't crash the app
- (void)test62WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Present paywall with URLs
  [[Superwall sharedInstance] registerWithPlacement:@"present_urls"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Tap the open # URL button
    CGPoint point = CGPointMake(330, 360);
    [weakSelf touch:point];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }));
}

// Finished purchase with a result type of `restored`
- (void)test63WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];

  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"restore" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{

      // Press restore
      CGPoint restoreButton = CGPointMake(200, 232);
      [weakSelf touch:restoreButton];

      TEST_ASSERT_DELAY_COMPLETION(kPaywallDelegateResponseDelay, (^{
        NSString *value = paywallDidFinishResultValueHolder.stringValue;
        TEST_ASSERT_VALUE_COMPLETION(value, ^{});
      }));
    }));
  }];
}

/// Choose non-other option from a paywall exit survey that shows 100% of the time.
- (void)test64WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(6)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"show_survey_with_other" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Tap the first option
      CGPoint firstOption = CGPointMake(196, 733);
      [weakSelf touch:firstOption];

      // Assert that paywall has disappeared and the feature block called.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Open the paywall again
        [[Superwall sharedInstance] registerWithPlacement:@"show_survey_with_other" params:nil handler:nil];

        // Assert that paywall has disappeared and the feature block called.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          [weakSelf touch:closeButton];

          // Assert paywall closed without showing survey.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
            // Assert that `.surveyResponse` and `.paywallClose` was called
            NSString *value = surveyResponseEventHolder.description;
            TEST_ASSERT_VALUE_COMPLETION(value, ^{});
          }));
        }));
      }));
    }));
  }));
}

/// Choose other option from a paywall exit survey that shows 100% of the time.
- (void)test65WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(5)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"show_survey_with_other" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Tap the other option
      CGPoint otherOption = CGPointMake(196, 790);
      [weakSelf touch:otherOption];

      // Assert that alert controller with textfield has disappeared and the feature block called.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf typeText:@"Test" completionHandler:^{
          // Tap the other option
          CGPoint submitButton = CGPointMake(196, 350);
          [weakSelf touch:submitButton];

          // Assert that paywall has disappeared and the feature block called.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
            NSString *value = surveyResponseEventHolder.description;
            TEST_ASSERT_VALUE_COMPLETION(value, ^{});
          }));
        }];
      }));
    }));
  }));
}

/// Choose other option from a paywall exit survey that shows 100% of the time.
- (void)test66WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"zero_percent_survey" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Assert that paywall has disappeared, no survey, and the feature block called.
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      NSString *value = surveyResponseEventHolder.description;
      TEST_ASSERT_VALUE_COMPLETION(value, ^{});
    }));
  }));
}

/// Assert survey is displayed after swiping down to dismiss a paywall.
- (void)test67WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"modal_paywall_with_survey" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf swipeDown];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}));
  }));
}

/// Assert survey is displayed after swiping down to dismiss a paywall.
- (SWKTestOptions *)testOptions68 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.surveyResponseAPIKey]; }
- (void)test68WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(5)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      CGPoint firstOption = CGPointMake(196, 733);
      [weakSelf
       touch:firstOption];

      // Assert that new paywall has appeared.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          // Close the paywall
          CGPoint newCloseButton = CGPointMake(34, 66);
          [weakSelf touch:newCloseButton];

        // Assert paywall closed and feature block called.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{

          // Assert that `.surveyResponse` and `.paywallClose` was called
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }));
      }));
    }));
  }));
}

/// Assert survey is displayed after swiping down to dismiss a paywall presented by `getPaywall`.
- (void)test69WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *paywallDelegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:paywallDelegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [paywallDelegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Create Superwall delegate
  SWKMockSuperwallDelegate *superwallDelegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:superwallDelegate];

  // Set delegate
  [Superwall sharedInstance].delegate = superwallDelegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [superwallDelegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"modal_paywall_with_survey" params:nil paywallOverrides:nil delegate:paywallDelegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      [weakSelf swipeDown];

      // Assert the survey is displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{

        // Tap the first option
        CGPoint point = CGPointMake(196, 733);
        [weakSelf touch:point];

        // Assert the survey is displayed
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          // Assert that `.surveyResponse` and `.paywallClose` was called
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }));
      }));
    }));
  }];
}

/// Assert survey is displayed after tapping exit button to dismiss a paywall presented by `getPaywall`.
- (void)test70WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *superwallDelegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:superwallDelegate];

  // Set delegate
  [Superwall sharedInstance].delegate = superwallDelegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [superwallDelegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *paywallDelegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:paywallDelegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [paywallDelegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"show_survey_with_other" params:nil paywallOverrides:nil delegate:paywallDelegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert the paywall has displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Close the paywall
      CGPoint point = CGPointMake(356, 86);
      [weakSelf touch:point];

      // Assert the survey is displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Tap the first option
        CGPoint point = CGPointMake(196, 733);
        [weakSelf touch:point];

        // Assert the survey is displayed
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          // Assert that `.surveyResponse` and `.paywallClose` was called
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }));
      }));
    }));
  }];
}

/// Purchase from paywall that has a survey attached and make sure survey doesn't show.
- (void)test71WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"survey_with_purchase_button" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 750);
    [weakSelf touch:purchaseButton];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];

      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];

        // Assert the paywall has disappeared and no survey displayed.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
          // Assert that `.surveyResponse` not called.
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        })
      }];
    }));
  }));
}

/// Check that calling identify restores the seed value. This is async and dependent on config so needs to sleep after calling identify.
- (void)test72WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create value handler
  SWKValueDescriptionHolder *seedHolder = [SWKValueDescriptionHolder new];

  [[Superwall sharedInstance] identifyWithUserId:@"abc"];

  [weakSelf sleepWithTimeInterval:7.0 completionHandler:^{
    NSDictionary *userAttributes = [[Superwall sharedInstance] userAttributes];
    NSString *seedValueString = userAttributes[@"seed"];
    int seedValueInt = [seedValueString intValue];
    seedHolder.intValue = seedValueInt;

    NSString *value = seedHolder.description;
    TEST_ASSERT_VALUE_COMPLETION(value, ^{
      [[Superwall sharedInstance] reset];

      [[Superwall sharedInstance] identifyWithUserId:@"abc"];

      [weakSelf sleepWithTimeInterval:7.0 completionHandler:^{
        NSDictionary *userAttributes = [[Superwall sharedInstance] userAttributes];
        NSString *seedValueString = userAttributes[@"seed"];
        int seedValueInt = [seedValueString intValue];
        seedHolder.intValue = seedValueInt;

        NSString *value = seedHolder.description;
        TEST_ASSERT_VALUE_COMPLETION(value, ^{});
      }];
    });
  }];
}

- (SWKTestOptions *)testOptions73 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.touchesBeganAPIKey]; }
- (void)test73WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *touchesBeganEventHolder = [SWKValueDescriptionHolder new];
  touchesBeganEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTouchesBegan:
        touchesBeganEventHolder.intValue += 1;
        touchesBeganEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Wait until config has been retrieved
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Touch the paywall
    CGPoint centreOfScreen = CGPointMake(197, 426);
    [weakSelf touch:centreOfScreen];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      [weakSelf touch:centreOfScreen];

      NSString *value = touchesBeganEventHolder.description;
      TEST_ASSERT_VALUE_COMPLETION(value, ^{});
    }));
  }));
}

- (void)test74WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create survey response value handler
  SWKValueDescriptionHolder *surveyCloseEventHolder = [SWKValueDescriptionHolder new];
  surveyCloseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyClose:
        surveyCloseEventHolder.intValue += 1;
        surveyCloseEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithPlacement:@"survey_with_close_option"];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 154);
    [weakSelf touch:closeButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
      // Tap the close option
      CGPoint closeOption = CGPointMake(196, 792);
      [weakSelf touch:closeOption];

      // Assert the paywall has disappeared
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
        // Assert that `.surveyClose` was called once
        TEST_ASSERT_VALUE_COMPLETION(surveyCloseEventHolder.description, ^{});
      })
    });
  }));
}

/// Present the paywall and purchase. Make sure the transaction, product, and paywallInfo data is passed back to delegate.
- (void)test75WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionCompleteEventHolder = [SWKValueDescriptionHolder new];
  transactionCompleteEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTransactionComplete: {
        transactionCompleteEventHolder.intValue += 1;
        NSString *transactionId = placementInfo.params[@"store_transaction_id"];
        bool isNil = transactionId == nil;
        NSString *productId = placementInfo.params[@"product_id"];
        NSString *paywallId = placementInfo.params[@"paywall_identifier"];

        transactionCompleteEventHolder.stringValue = [NSString stringWithFormat:@"%s,%@,%@", isNil ? "true" : "false", productId, paywallId];
        break;
      }
      default:
        break;
    }
  }];

  // Register event to present the paywall
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 750);
    [weakSelf touch:purchaseButton];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];

      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];

        // Try to present paywall again
        [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

        // Ensure the paywall doesn't present.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
          TEST_ASSERT_VALUE_COMPLETION(transactionCompleteEventHolder.description, ^{});
        });
      }];
    }));
  }));
}

/// Register event and land in holdout. Register again and present paywall.
- (void)test76WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  [[Superwall sharedInstance] registerWithPlacement:@"holdout_one_time_occurrence"];

  // Assert that no paywall appears (holdout)
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [[Superwall sharedInstance] registerWithPlacement:@"holdout_one_time_occurrence"];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}));
  }));
}

- (void)test77WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;
  SKProduct *secondary = [SWKStoreKitHelper sharedInstance].sk1AnnualProduct;

  if (!primary || !secondary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];

  SWKPaywallOverrides *paywallOverrides = [[SWKPaywallOverrides alloc] initWithProductsByName:@{@"primary": primaryProduct, @"secondary": secondaryProduct}];

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:delegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_products" params:nil paywallOverrides:paywallOverrides delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });

      // Assert after a delay
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    } else {
      // Handle error
      completionHandler(result.error);
    }
  }];
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products. After dismiss, paywall should be presented one last time with no override products.
- (void)test78WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Paywall Overrides don't work with register")
}

/// Present non-gated `paywall_decline` paywall from gated paywall and make sure the feature block isn't called.
- (SWKTestOptions *)testOptions79 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.gatedAPIKey]; }
- (void)test79WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that alert appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Wait for non-gated paywall to show
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
      // Close the paywall
      [weakSelf touch:closeButton];

      // Assert the feature block wasn't called.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}))
    })
  }));
}

/// Present non-gated `transaction_abandon` paywall from gated paywall and make sure the feature block isn't called.
- (SWKTestOptions *)testOptions80 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.gatedAPIKey]; }
- (void)test80WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Wait for gated paywall to show
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Continue on the paywall
    CGPoint button = CGPointMake(196, 786);
    [weakSelf touch:button];

    [weakSelf sleepWithTimeInterval:2.0 completionHandler:^{
      // Purchase on the paywall
      [weakSelf touch:button];

      // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
      CGRect customFrame = CGRectMake(0, 488, 393, 300);
      TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
        CGPoint abandonTransactionButton = CGPointMake(359, 515);
        [weakSelf touch:abandonTransactionButton];

        // Wait for non-gated paywall to show
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
          // Close the paywall
          CGPoint closeButton = CGPointMake(356, 86);
          [weakSelf touch:closeButton];

          // Assert the feature block wasn't called.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}))
        })
      }));
    }];
  }));
}

/// Present non-gated `transaction_fail` paywall from gated paywall and make sure the feature block isn't called.
- (SWKTestOptions *)testOptions81 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.gatedAPIKey]; }
- (void)test81WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Fail all transactions
  [self failTransactionsWithCompletionHandler:^{
    // Register event and present an alert controller
    [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger" params:nil handler:nil feature:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                                 message:@"This is an alert message"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:action];
        [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
      });
    }];

    // Wait for gated paywall to show
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Continue on the paywall
      CGPoint button = CGPointMake(196, 786);
      [weakSelf touch:button];

      [weakSelf sleepWithTimeInterval:2.0 completionHandler:^{
        // Purchase on the paywall
        [weakSelf touch:button];

        // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
        CGRect customFrame = CGRectMake(0, 488, 393, 300);
        TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
          // Tap the Subscribe button
          CGPoint subscribeButton = CGPointMake(196, 766);
          [weakSelf touch:subscribeButton];

          // Wait for non-gated paywall to show
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
            // Close the paywall
            CGPoint closeButton = CGPointMake(356, 86);
            [weakSelf touch:closeButton];

            // Assert the feature block wasn't called.
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}))
          })
        }));
      }];
    }));
  }];
}

/// Make sure feature block of gated paywall isn't called when `paywall_decline` returns a `noRuleMatch`
- (SWKTestOptions *)testOptions82 { return [SWKTestOptions testOptionsWithApiKey:SWKConstants.noRuleMatchGatedAPIKey]; }
- (void)test82WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Wait for gated paywall to show
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(56, 86);
    [weakSelf touch:closeButton];

    // Assert the feature block wasn't called.
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}))
  }));
}

// Finished purchase with a result type of `restored`
// Same as test37 but with v4 paywall
- (void)test83WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];

  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"restore_v4" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Mock user as subscribed
      [weakSelf.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
        // Press restore
        CGPoint restoreButton = CGPointMake(196, 136);
        [weakSelf touch:restoreButton];

        // Wait for the delegate function to be called
        [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
          // Assert didFinish paywall result value
          NSString *value = paywallDidFinishResultValueHolder.stringValue;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }];
      }];
    }));
  }];
}

// Finished restore with a result type of `restored` and then swiping the paywall view controller away (does it get called twice?)
// Same as test39 but with v4 paywall
- (void)test84WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [weakSelf holdStrongly:delegate];

  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"restore_v4" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Mock user as subscribed
      [weakSelf.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
        // Press restore
        CGPoint restoreButton = CGPointMake(196, 196);
        [weakSelf touch:restoreButton];

        // Wait for the delegate function to be called
        [weakSelf sleepWithTimeInterval:kPaywallDelegateResponseDelay completionHandler:^{
          // Assert paywall did finish result value ("restored")
          NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
          TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, (^{
            // Modify the paywall didFinish result value
            paywallDidFinishResultValueHolder.stringValue = @"empty value";

            // Swipe the paywall down to dismiss
            [weakSelf swipeDown];

            // Assert the paywall was dismissed
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
              // Assert paywall did finish result value ("empty value")
              NSString *paywallDidFinishValue = paywallDidFinishResultValueHolder.stringValue;
              TEST_ASSERT_VALUE_COMPLETION(paywallDidFinishValue, ^{});
            }));
          }));
        }];
      }];
    }));
  }];
}

// Finished purchase with a result type of `restored`
// Same as test63 but with v4 paywall
- (void)test85WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [[SWKMockPaywallViewControllerDelegate alloc] init];
  [self holdStrongly:delegate];

  // Create a ValueDescriptionHolder to store the paywall did finish result value
  SWKValueDescriptionHolder *paywallDidFinishResultValueHolder = [SWKValueDescriptionHolder new];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    paywallDidFinishResultValueHolder.stringValue = [SWKPaywallResultValueObjcHelper description:result];
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"restore_v4" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{

      // Press restore
      CGPoint restoreButton = CGPointMake(196, 135);
      [weakSelf touch:restoreButton];

      TEST_ASSERT_DELAY_COMPLETION(kPaywallDelegateResponseDelay, (^{
        NSString *value = paywallDidFinishResultValueHolder.stringValue;
        TEST_ASSERT_VALUE_COMPLETION(value, ^{});
      }));
    }));
  }];
}

/// Case: Unsubscribed user, register event with a gating handler
/// Result: paywall should display, code in gating closure should not execute
/// Same as test26 but with v4 paywall
- (void)test86WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"register_gated_paywall_v4" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that alert appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint purchaseButton = CGPointMake(352, 65);
    [weakSelf touch:purchaseButton];

    // Assert that nothing else appears
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }));
}

/// Case: Subscribed user, register event with a gating handler
/// Result: paywall should NOT display, code in gating closure should execute
/// Same as test27 but with v4 paywall
- (SWKTestOptions *)testOptions87 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test87WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Mock user as subscribed
  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{

    // Register event and present an alert controller
    [[Superwall sharedInstance] registerWithPlacement:@"register_gated_paywall_v4" params:nil handler:nil feature:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                                 message:@"This is an alert message"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:action];
        [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
      });
    }];

    // Assert that alert controller appears
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

/// Case: Unsubscribed user, register event without a gating handler
/// Result: paywall should display
/// Same as test23 but with v4 paywall
- (void)test88WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Register event
  [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall_v4"];

  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

/// Case: Subscribed user, register event without a gating handler
/// Result: paywall should NOT display
/// Same as test24 but with v4 paywall
- (SWKTestOptions *)testOptions89 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test89WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Mock user as subscribed
  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{

    // Register event
    [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall_v4"];

    // Assert that paywall DOES not appear
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

/// Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
/// Result: paywall should display, after user subscribes, don't show another paywall
/// Same as test25 but with v4 paywall
- (void)test90WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Register event
  [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall_v4"];

  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 748);
    [weakSelf touch:purchaseButton];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];

      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];

        [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
          // Try to present paywall again
          [[Superwall sharedInstance] registerWithPlacement:@"register_nongated_paywall_v4"];

          // Ensure the paywall doesn't present.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }];
    }));
  }));
}

// Unable to fetch config, not subscribed, and not gated.
/// Same as test41 but with v4 paywall
- (SWKTestOptions *)testOptions91 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO]; }
- (void)test91WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:NO gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Unable to fetch config, not subscribed, and gated.
/// Same as test42 but with v4 paywall
- (SWKTestOptions *)testOptions92 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO]; }
- (void)test92WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:NO gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Unable to fetch config, subscribed, and not gated.
/// Same as test43 but with v4 paywall
- (SWKTestOptions *)testOptions93 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO purchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test93WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:YES gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Unable to fetch config, subscribed, and gated.
/// Same as test44 but with v4 paywall
- (SWKTestOptions *)testOptions94 { return [SWKTestOptions testOptionsWithAllowNetworkRequests:NO purchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test94WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:YES gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, not subscribed, and not gated.
/// Same as test45 but with v4 paywall
- (void)test95WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:NO gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, not subscribed, and gated.
/// Same as test46 but with v4 paywall
- (void)test96WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:NO gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, subscribed, and not gated.
/// Same as test47 but with v4 paywall
- (SWKTestOptions *)testOptions97 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test97WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:YES gated:NO testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Fetched config, subscribed, and gated.
/// Same as test48 but with v4 paywall
- (SWKTestOptions *)testOptions98 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test98WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  [self executeRegisterFeatureClosureTestWithSubscribedWithV4Paywall:YES gated:YES testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] completionHandler:completionHandler];
}

// Present regardless of status
/// Same as test9 but with v4 paywall
- (SWKTestOptions *)testOptions99 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test99WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
    [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

// Test trigger: not-allowed standard event (paywall_close)
/// Same as test14 but with v4 paywall
- (void)test100WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];

  // After delay, assert that there was a presentation
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    }];
  }));
}

// Clusterfucks by Jake™
/// Same as test15 but with v4 paywall
- (void)test101WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Present paywall
  [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];
  [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4" params:@{@"some_param_1": @"hello"}];
  [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];

  // After delay, assert that there was a presentation
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{

      [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];
      [[Superwall sharedInstance] identifyWithUserId:@"1111"];
      [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];

      // After delay, assert that there was a presentation
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];
          __block NSString *experimentId;

          [handler onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
            [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];
            experimentId = paywallInfo.experiment.id;
            // Wait and assert.
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
              TEST_ASSERT_VALUE_COMPLETION(experimentId, ^{});
            });
          }];

          // Present paywall
          [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4" params:nil handler:handler];
        }];
      }));
    }];
  }));
}

// Present an alert on Superwall.presentedViewController from the onPresent callback
/// Same as test16 but with v4 paywall
- (void)test102WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];
  [handler onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:@"This is an alert message" preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:okAction];

      UIViewController *presentingViewController = [Superwall sharedInstance].presentedViewController;
      [presentingViewController presentViewController:alertController animated:NO completion:nil];
    });
  }];

  [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4" params:nil handler:handler];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Uses the identify function. Should see the name 'Jack' in the paywall.
/// Same as test0 but with v4 paywall
- (void)test103WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Uses the identify function. Should see the name 'Kate' in the paywall.
/// Same as test1 but with v4 paywall
- (void)test104WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test1a"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

  // Set new identity.
  [[Superwall sharedInstance] identifyWithUserId:@"test1b"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Kate" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Calls `reset()`. No first name should be displayed.
/// Same as test2 but with v4 paywall
- (void)test105WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test2"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

  // Reset the user identity
  [[Superwall sharedInstance] reset];

  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Calls `reset()` multiple times. No first name should be displayed.
/// Same as test3 but with v4 paywall
- (void)test106WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test3"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

  // Reset the user identity twice
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];

  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Clear a specific user attribute.
/// Same as test11 but with v4 paywall
- (void)test107WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3);

  // Add user attribute
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Claire" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  // Assert that the first name is displayed
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove user attribute
      [[Superwall sharedInstance] removeUserAttributes:@[@"first_name"]];
      [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

      // Assert that the first name is NOT displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Add new user attribute
          [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Sawyer" }];
          [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }));
    }];
  }));
}

// Clusterfucks by Jake™
- (void)test108WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Set identity
      [[Superwall sharedInstance] identifyWithUserId:@"test2"];
      [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];

      // Reset the user identity
      [[Superwall sharedInstance] reset];

      [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Present paywall
          [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];
          [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4" params:@{@"some_param_1": @"hello"}];
          [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];

          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }));
    }];
  }));
}
/// Assert a `survey_close` event when closing a survey that has a close button.
/// Same as test74 but with v4 paywall
- (void)test109WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)
  // TODO: THIS IS FAILINIG FOR SOME REASON

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create survey response value handler
  SWKValueDescriptionHolder *surveyCloseEventHolder = [SWKValueDescriptionHolder new];
  surveyCloseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyClose:
        surveyCloseEventHolder.intValue += 1;
        surveyCloseEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithPlacement:@"survey_with_close_option_v4"];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(196, 820);
    [weakSelf touch:closeButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
      // Tap the close option
      CGPoint closeOption = CGPointMake(196, 792);
      [weakSelf touch:closeOption];

      // Assert the paywall has disappeared
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
        // Assert that `.surveyClose` was called once
        TEST_ASSERT_VALUE_COMPLETION(surveyCloseEventHolder.description, ^{});
      })
    });
  }));
}

/// Purchase from paywall that has a survey attached and make sure survey doesn't show.
/// Same as test71 but with v4 paywall
- (void)test110WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"survey_with_purchase_button_v4" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 750);
    [weakSelf touch:purchaseButton];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];

      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];

        // Assert the paywall has disappeared and no survey displayed.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
          // Assert that `.surveyResponse` not called.
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        })
      }];
    }));
  }));
}

/// Assert survey is displayed after swiping down to dismiss a paywall.
- (void)test111WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"modal_paywall_with_survey_v4" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf swipeDown];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}));
  }));
}

/// Assert survey is displayed after swiping down to dismiss a paywall presented by `getPaywall`.
/// Same as test69 but with v4 paywall
- (void)test112WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *paywallDelegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:paywallDelegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [paywallDelegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Create Superwall delegate
  SWKMockSuperwallDelegate *superwallDelegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:superwallDelegate];

  // Set delegate
  [Superwall sharedInstance].delegate = superwallDelegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [superwallDelegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"modal_paywall_with_survey_v4" params:nil paywallOverrides:nil delegate:paywallDelegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      [weakSelf swipeDown];

      // Assert the survey is displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{

        // Tap the first option
        CGPoint point = CGPointMake(196, 733);
        [weakSelf touch:point];

        // Assert the survey is displayed
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          // Assert that `.surveyResponse` and `.paywallClose` was called
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }));
      }));
    }));
  }];
}

/// Choose other option from a paywall exit survey that shows 100% of the time.
/// Same as test66 but with v4 paywall
- (void)test113WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"zero_percent_survey_v4" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Assert that paywall has disappeared, no survey, and the feature block called.
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      NSString *value = surveyResponseEventHolder.description;
      TEST_ASSERT_VALUE_COMPLETION(value, ^{});
    }));
  }));
}

/// Choose non-other option from a paywall exit survey that shows 100% of the time.
- (void)test114WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(6)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"show_survey_with_other_v4" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Tap the first option
      CGPoint firstOption = CGPointMake(196, 733);
      [weakSelf touch:firstOption];

      // Assert that paywall has disappeared and the feature block called.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Open the paywall again
        [[Superwall sharedInstance] registerWithPlacement:@"show_survey_with_other_v4" params:nil handler:nil];

        // Assert that paywall has disappeared and the feature block called.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          [weakSelf touch:closeButton];

          // Assert paywall closed without showing survey.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
            // Assert that `.surveyResponse` and `.paywallClose` was called
            NSString *value = surveyResponseEventHolder.description;
            TEST_ASSERT_VALUE_COMPLETION(value, ^{});
          }));
        }));
      }));
    }));
  }));
}

/// Choose other option from a paywall exit survey that shows 100% of the time.
- (void)test115WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(5)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithPlacement:@"show_survey_with_other_v4" params:nil handler:nil feature:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert"
                                                                               message:@"This is an alert message"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:action];
      [[SWKRootViewController sharedInstance] presentViewController:alertController animated:NO completion:nil];
    });
  }];

  // Assert that paywall was presented
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Close the paywall
    CGPoint closeButton = CGPointMake(356, 86);
    [weakSelf touch:closeButton];

    // Assert the survey is displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Tap the other option
      CGPoint otherOption = CGPointMake(196, 790);
      [weakSelf touch:otherOption];

      // Assert that alert controller with textfield has disappeared and the feature block called.
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf typeText:@"Test" completionHandler:^{
          // Tap the other option
          CGPoint submitButton = CGPointMake(196, 350);
          [weakSelf touch:submitButton];

          // Assert that paywall has disappeared and the feature block called.
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
            NSString *value = surveyResponseEventHolder.description;
            TEST_ASSERT_VALUE_COMPLETION(value, ^{});
          }));
        }];
      }));
    }));
  }));
}

/// Assert survey is displayed after tapping exit button to dismiss a paywall presented by `getPaywall`.
/// Same as test70 but with v4 paywall
- (void)test116WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *superwallDelegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:superwallDelegate];

  // Set delegate
  [Superwall sharedInstance].delegate = superwallDelegate;

  // Create value handler
  SWKValueDescriptionHolder *surveyResponseEventHolder = [SWKValueDescriptionHolder new];
  surveyResponseEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [superwallDelegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *paywallDelegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:paywallDelegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [paywallDelegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"show_survey_with_other_v4" params:nil paywallOverrides:nil delegate:paywallDelegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert the paywall has displayed
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Close the paywall
      CGPoint point = CGPointMake(356, 86);
      [weakSelf touch:point];

      // Assert the survey is displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Tap the first option
        CGPoint point = CGPointMake(196, 733);
        [weakSelf touch:point];

        // Assert the survey is displayed
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
          // Assert that `.surveyResponse` and `.paywallClose` was called
          NSString *value = surveyResponseEventHolder.description;
          TEST_ASSERT_VALUE_COMPLETION(value, ^{});
        }));
      }));
    }));
  }];
}

/// Clusterfucks by Jake™
/// Same as test19 but with v4 paywalls.
- (void)test117WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(4)

  // Set identity
  [[Superwall sharedInstance] identifyWithUserId:@"test19a"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Jack"}];

  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] reset];
  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{

      [[Superwall sharedInstance] getPresentationResultForPlacement:@"present_and_rule_user_v4" completionHandler:^(SWKPresentationResult * _Nonnull result) {

        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{

          // Show a paywall
          [[Superwall sharedInstance] registerWithPlacement:@"present_always_v4"];

          // Assert that paywall was displayed
          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
            // Dismiss any view controllers
            [weakSelf dismissViewControllersWithCompletionHandler:^{
              // Assert that no paywall is displayed as a result of the Superwall-owned paywall_close standard event.
              TEST_ASSERT_DELAY_COMPLETION(0, (^{
                // Dismiss any view controllers
                [weakSelf dismissViewControllersWithCompletionHandler:^{

                  // Set identity
                  [[Superwall sharedInstance] identifyWithUserId:@"test19b"];
                  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Jack"}];

                  // Set new identity
                  [[Superwall sharedInstance] identifyWithUserId:@"test19c"];
                  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Kate"}];
                  [[Superwall sharedInstance] registerWithPlacement:@"present_data_v4"];

                  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
                }];
              }));
            }];
          }));
        }];
      }];
    }];
  }));
}

/// Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
/// Same as test7 but with v4 paywalls
- (void)test118WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @14}];
  [[Superwall sharedInstance] registerWithPlacement:@"present_and_rule_user_v4"];

  // Assert after a delay
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove those attributes.
      [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];
      [[Superwall sharedInstance] registerWithPlacement:@"present_and_rule_user_v4"];

      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    }];
  }));
}

/// Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
/// Same as test8 but with v4 paywall
- (void)test119WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @12}];
  [[Superwall sharedInstance] registerWithPlacement:@"present_and_rule_user_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

/// Presentation result: `noRuleMatch`
/// Same as test29 but with v4 paywall
- (void)test120WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Remove user attributes
  [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];

  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForPlacement:@"present_and_rule_user_v4" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

/// Open In-App Safari view controller from manually presented paywall
/// Same as test18 but with v4 paywall
- (void)test121WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:delegate];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_urls_v4" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });
    }

    // Assert that paywall is presented
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
      // Position of the perform button to open a URL in Safari
      CGPoint point = CGPointMake(330, 212);
      [weakSelf touch:point];

      // Verify that In-App Safari has opened
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Press the done button to go back
        CGPoint donePoint = CGPointMake(30, 70);
        [weakSelf touch:donePoint];

        // Verify that the paywall appears
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
      }));
    }));
  }];
}

/// Verify that external URLs can be opened in native Safari from paywall
- (void)test122WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  // Present paywall with URLs
  [[Superwall sharedInstance] registerWithPlacement:@"present_urls_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Position of the perform button to open a URL in Safari
    CGPoint point = CGPointMake(330, 136);
    [weakSelf touch:point];

    // Verify that Safari has opened.
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea safari], ^{
      // Relaunch the parent app.
      [weakSelf relaunchWithCompletionHandler:^{
        // Ensure nothing has changed.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
      }];
    });
  }));
}

/// Verify that an invalid URL like `#` doesn't crash the app
/// Same as test62 but with v4 paywall
- (void)test123WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  // Present paywall with URLs
  [[Superwall sharedInstance] registerWithPlacement:@"present_urls_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Tap the open # URL button
    CGPoint point = CGPointMake(330, 360);
    [weakSelf touch:point];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }));
}

/// Show paywall with override products. Paywall should appear with 2 products: 1 monthly at
/// $12.99 and 1 annual at $99.99.
/// Same as test5 but with v4 paywall
- (void)test124WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;
  SKProduct *secondary = [SWKStoreKitHelper sharedInstance].sk1AnnualProduct;

  if (!primary || !secondary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];

  SWKPaywallOverrides *paywallOverrides = [[SWKPaywallOverrides alloc] initWithProductsByName:@{@"primary": primaryProduct, @"secondary": secondaryProduct}];
  
  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:delegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_products_v4" params:nil paywallOverrides:paywallOverrides delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });

      // Assert after a delay
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    } else {
      // Handle error
      completionHandler(result.error);
    }
  }];
}

/// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
/// Same as test6 but with v4 paywall
- (void)test125WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Present the paywall.
  [[Superwall sharedInstance] registerWithPlacement:@"present_products_v4"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products. After dismiss, paywall should be presented one last time with no override products.
/// Same as test10 but with v4 paywall
- (void)test126WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Paywall Overrides don't work with register")
}

- (void)test127WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;
  SKProduct *secondary = [SWKStoreKitHelper sharedInstance].sk1AnnualProduct;

  if (!primary || !secondary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];

  SWKPaywallOverrides *paywallOverrides = [[SWKPaywallOverrides alloc] initWithProductsByName:@{@"primary": primaryProduct, @"secondary": secondaryProduct}];

  // Create and hold strongly the delegate
  SWKMockPaywallViewControllerDelegate *delegate = [SWKMockPaywallViewControllerDelegate new];
  [self holdStrongly:delegate];

  // Set the delegate's paywallViewControllerDidFinish block
  [delegate setPaywallViewControllerDidFinish:^(SWKPaywallViewController *viewController, SWKPaywallResult result, BOOL shouldDismiss) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [viewController dismissViewControllerAnimated:NO completion:nil];
    });
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForPlacement:@"present_products_v4" params:nil paywallOverrides:paywallOverrides delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
    UIViewController *viewController = result.paywall;
    if (viewController) {
      dispatch_async(dispatch_get_main_queue(), ^{
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [[SWKRootViewController sharedInstance] presentViewController:viewController animated:YES completion:nil];
      });

      // Assert after a delay
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
    } else {
      // Handle error
      completionHandler(result.error);
    }
  }];
}

// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products. After dismiss, paywall should be presented one last time with no override products.
/// Same as test78 but with v4 paywall
- (void)test128WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Paywall Overrides don't work with register")
}

// This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning with a 0 on the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and we want to capture the video as quickly as possible.
/// Same as test4 but with v4 paywall
- (void)test129WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START

  [[Superwall sharedInstance] registerWithPlacement:@"present_video_v4"];

  // Wait 4 seconds before dismissing the video
  [self sleepWithTimeInterval:4.0 completionHandler:^{
    [[Superwall sharedInstance] dismissWithCompletion:^{
      // Once the video has been dismissed, wait 1 second before dismissing again
      [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
        [[Superwall sharedInstance] registerWithPlacement:@"present_video_v4"];

        // Assert that the video has started from the 0 sec mark (video simply counts from 0sec to 2sec and only displays those 2 values)
        TEST_ASSERT_DELAY_COMPLETION(2.0, ^{})
      }];
    }];
  }];
}

/// Purchase a product without a paywall.
- (void)test130WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. Weirdly skips the capture area completion block so needs fixing.")
//  TEST_START_NUM_ASSERTS(3)
//
//  // Get the primary and secondary products
//  SKProduct *primary = [SWKStoreKitHelper sharedInstance].monthlyProduct;
//
//  if (!primary) {
//    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
//    return;
//  }
//
//  // Create Superwall delegate
//  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
//  [self holdStrongly:delegate];
//
//  // Set delegate
//  [Superwall sharedInstance].delegate = delegate;
//
//  // Create value handler
//  SWKValueDescriptionHolder *transactionCompleteEventHolder = [SWKValueDescriptionHolder new];
//  transactionCompleteEventHolder.stringValue = @"No";
//  SWKValueDescriptionHolder *subscriptionStartEventHolder = [SWKValueDescriptionHolder new];
//  subscriptionStartEventHolder.stringValue = @"No";
//  SWKValueDescriptionHolder *purchaseResultValueHolder = [SWKValueDescriptionHolder new];
//  purchaseResultValueHolder.stringValue = @"No";
//
//  // Respond to Superwall events
//  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
//    switch (eventInfo.event) {
//      case SWKSuperwallEventTransactionComplete:
//        transactionCompleteEventHolder.intValue += 1;
//        transactionCompleteEventHolder.stringValue = @"Yes";
//        break;
//      case SWKSuperwallEventSubscriptionStart:
//        subscriptionStartEventHolder.intValue += 1;
//        subscriptionStartEventHolder.stringValue = @"Yes";
//        break;
//      default:
//        break;
//    }
//  }];
//
//  [[Superwall sharedInstance] purchase:primary completion:^(enum SWKPurchaseResult result) {
//    switch (result) {
//      case SWKPurchaseResultPurchased:
//        purchaseResultValueHolder.intValue += 1;
//        purchaseResultValueHolder.stringValue = @"Yes";
//        break;
//      default:
//        break;
//    }
//  }];
//
//  // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
//  CGRect customFrame = CGRectMake(0, 488, 393, 300);
//  NSLog(@"Before TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION");
//
//  TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
//    NSLog(@"Inside TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION block");
//
//    // Tap the Subscribe button
//    CGPoint subscribeButton = CGPointMake(196, 766);
//    NSLog(@"Touching Subscribe Button");
//    [weakSelf touch:subscribeButton];
//
//    // Wait for subscribe to occur
//    [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
//      // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
//      CGPoint okButton = CGPointMake(196, 495);
//      NSLog(@"Touching OK Button");
//      [weakSelf touch:okButton];
//
//      TEST_ASSERT_VALUE_COMPLETION(purchaseResultValueHolder.description, ^{});
//      TEST_ASSERT_VALUE_COMPLETION(transactionCompleteEventHolder.description, ^{});
//    }];
//  }));
//
//  NSLog(@"After TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION");
}

/// Cancel purchase of product without a paywall.
- (SWKTestOptions *)testOptions131 {
  // For objc, they have to explicitly set the version to SK1 to test
  // the purchasing of an SK1 product.
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.storeKitVersion = SWKStoreKitVersionStoreKit1;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test131WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  if ([self.configuration isKindOfClass:[SWKConfigurationAdvanced class]]) {
    TEST_SKIP(@"Skipping test. In the advanced configuration we assume the purchase is within the purchase controller so the delegate won't get called and the result will not return.")
    return;
  }
  TEST_START_NUM_ASSERTS(3)

  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;

  if (!primary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionAbandonEventHolder = [SWKValueDescriptionHolder new];
  transactionAbandonEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *cancelledResultValueHolder = [SWKValueDescriptionHolder new];
  cancelledResultValueHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTransactionAbandon:
        transactionAbandonEventHolder.intValue += 1;
        transactionAbandonEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] purchase:primary completion:^(enum SWKPurchaseResult result) {
    switch (result) {
      case SWKPurchaseResultCancelled:
        cancelledResultValueHolder.intValue += 1;
        cancelledResultValueHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
  CGRect customFrame = CGRectMake(0, 488, 393, 300);
  TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
    // Abandon the transaction
    CGPoint abandonTransactionButton = CGPointMake(359, 20);
    [weakSelf touch:abandonTransactionButton];

    TEST_ASSERT_DELAY_VALUE_COMPLETION(kPaywallPresentationDelay, cancelledResultValueHolder.description, ^{
      TEST_ASSERT_VALUE_COMPLETION(transactionAbandonEventHolder.description, ^{});
    });
  }));
}

/// Restore purchases  with automatic configuration.
- (SWKTestOptions *)testOptions132 {
  // For objc, they have to explicitly set the version to SK1 to test
  // the purchasing of an SK1 product.
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.storeKitVersion = SWKStoreKitVersionStoreKit1;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test132WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  if ([self.configuration isKindOfClass:[SWKConfigurationAdvanced class]]) {
    TEST_SKIP(@"Skipping test. The restore performs differently in the advanced configuration.")
    return;
  }
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *restoreStartEventHolder = [SWKValueDescriptionHolder new];
  restoreStartEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoreCompleteEventHolder = [SWKValueDescriptionHolder new];
  restoreCompleteEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoredResultValueHolder = [SWKValueDescriptionHolder new];
  restoredResultValueHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementRestoreStart:
        restoreStartEventHolder.intValue += 1;
        restoreStartEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementRestoreComplete:
        restoreCompleteEventHolder.intValue += 1;
        restoreCompleteEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
    [[Superwall sharedInstance] restorePurchasesWithCompletion:^(enum SWKRestorationResult result) {
      switch (result) {
        case SWKRestorationResultRestored:
          restoredResultValueHolder.intValue += 1;
          restoredResultValueHolder.stringValue = @"Yes";
          break;
        default:
          break;
      }

      TEST_ASSERT_DELAY_VALUE_COMPLETION(kPaywallPresentationDelay,
          restoredResultValueHolder.description, ^{
        TEST_ASSERT_VALUE_COMPLETION(restoreStartEventHolder.description, ^{
          TEST_ASSERT_VALUE_COMPLETION(restoreCompleteEventHolder.description, ^{});
        });
      });
    }];
  }];
}

/// Failed restore of purchases under automatic configuration.
- (SWKTestOptions *)testOptions133 {
  // For objc, they have to explicitly set the version to SK1 to test
  // the purchasing of an SK1 product.
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.storeKitVersion = SWKStoreKitVersionStoreKit1;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test133WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  if ([self.configuration isKindOfClass:[SWKConfigurationAdvanced class]]) {
    TEST_SKIP(@"Skipping test. The restore performs differently in the advanced configuration.")
    return;
  }
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *restoreStartEventHolder = [SWKValueDescriptionHolder new];
  restoreStartEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoreFailEventHolder = [SWKValueDescriptionHolder new];
  restoreFailEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoredValueHolder = [SWKValueDescriptionHolder new];
  restoredValueHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementRestoreStart:
        restoreStartEventHolder.intValue += 1;
        restoreStartEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementRestoreFail:
        restoreFailEventHolder.intValue += 1;
        restoreFailEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // User is not subscribed

  [[Superwall sharedInstance] restorePurchasesWithCompletion:^(enum SWKRestorationResult result) {
    switch (result) {
      case SWKRestorationResultRestored:
        // Result is still restored even though alert shows. This is because
        // the user is unsubscribed but result is restored.
        restoredValueHolder.intValue += 1;
        restoredValueHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }

    TEST_ASSERT_DELAY_COMPLETION(kImplicitPaywallPresentationDelay, ^{
      TEST_ASSERT_VALUE_COMPLETION(restoredValueHolder.description, ^{
        TEST_ASSERT_VALUE_COMPLETION(restoreStartEventHolder.description, ^{
          TEST_ASSERT_VALUE_COMPLETION(restoreFailEventHolder.description, ^{});
        });
      });
    });
  }];
}

/// Failed restore of purchases  under advanced configuration.
- (SWKTestOptions *)testOptions134 {
  // For objc, they have to explicitly set the version to SK1 to test
  // the purchasing of an SK1 product.
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.storeKitVersion = SWKStoreKitVersionStoreKit1;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test134WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  if ([self.configuration isKindOfClass:[SWKConfigurationAutomatic class]]) {
    TEST_SKIP(@"Skipping test. The restore performs differently in the automatic configuration.")
    return;
  }
  TEST_START_NUM_ASSERTS(4)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *restoreStartEventHolder = [SWKValueDescriptionHolder new];
  restoreStartEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoreFailEventHolder = [SWKValueDescriptionHolder new];
  restoreFailEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoredValueHolder = [SWKValueDescriptionHolder new];
  restoredValueHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementRestoreStart:
        restoreStartEventHolder.intValue += 1;
        restoreStartEventHolder.stringValue = @"Yes";
        break;
      case SWKRestorationResultFailed:
        restoreFailEventHolder.intValue += 1;
        restoreFailEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // User is not subscribed

  [[Superwall sharedInstance] restorePurchasesWithCompletion:^(enum SWKRestorationResult result) {
    switch (result) {
      case SWKRestorationResultRestored:
        // Result is still restored even though alert shows. This is because
        // the user is unsubscribed but result is restored.
        restoredValueHolder.intValue += 1;
        restoredValueHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }

    TEST_ASSERT_DELAY_COMPLETION(kImplicitPaywallPresentationDelay, ^{});

    TEST_ASSERT_VALUE_COMPLETION(restoredValueHolder.description, ^{});
    TEST_ASSERT_VALUE_COMPLETION(restoreStartEventHolder.description, ^{});
    TEST_ASSERT_VALUE_COMPLETION(restoreFailEventHolder.description, ^{});
  }];
}

/// Restored result from purchase without a paywall.
- (void)test135WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Simulator sometimes returns purchased instead of restored so hard to use. Would need SK1 and SK2 versions of this.")
  return;
  /*
  TEST_START_NUM_ASSERTS(2)

  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;

  if (!primary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionCompleteEventHolder = [SWKValueDescriptionHolder new];
  transactionCompleteEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementRestoreComplete:
        transactionCompleteEventHolder.intValue += 1;
        transactionCompleteEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customMonthlyProductIdentifier completionHandler:^{
    [[Superwall sharedInstance] purchase:primary completion:^(enum SWKPurchaseResult result) {}];
  }];

  // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
  CGRect customFrame = CGRectMake(0, 0, 393, 390);
  TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
    // Abandon the OK button
    CGPoint okButton = CGPointMake(261, 526);
    [weakSelf touch:okButton];

    [self sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
      TEST_ASSERT_VALUE_COMPLETION(transactionCompleteEventHolder.description, ^{});
    }];
  }));*/
}

/// Restore purchases with advanced configuration.
- (SWKTestOptions *)testOptions136 {
  // For objc, they have to explicitly set the version to SK1 to test
  // the purchasing of an SK1 product.
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.storeKitVersion = SWKStoreKitVersionStoreKit1;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test136WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  if ([self.configuration isKindOfClass:[SWKConfigurationAutomatic class]]) {
    TEST_SKIP(@"Skipping test. The restore performs differently in the automatic configuration.")
    return;
  }
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *restoreStartEventHolder = [SWKValueDescriptionHolder new];
  restoreStartEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoreCompleteEventHolder = [SWKValueDescriptionHolder new];
  restoreCompleteEventHolder.stringValue = @"No";
  SWKValueDescriptionHolder *restoredResultValueHolder = [SWKValueDescriptionHolder new];
  restoredResultValueHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementRestoreStart:
        restoreStartEventHolder.intValue += 1;
        restoreStartEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallPlacementRestoreComplete:
        restoreCompleteEventHolder.intValue += 1;
        restoreCompleteEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
    [[Superwall sharedInstance] restorePurchasesWithCompletion:^(enum SWKRestorationResult result) {
      switch (result) {
        case SWKRestorationResultRestored:
          restoredResultValueHolder.intValue += 1;
          restoredResultValueHolder.stringValue = @"Yes";
          break;
        default:
          break;
      }

      TEST_ASSERT_VALUE_COMPLETION(restoredResultValueHolder.description, ^{});
      TEST_ASSERT_VALUE_COMPLETION(restoreStartEventHolder.description, ^{});
      TEST_ASSERT_VALUE_COMPLETION(restoreCompleteEventHolder.description, ^{});
    }];
  }];
}

/// Superwall purchases with observer mode enabled.
- (SWKTestOptions *)testOptions137 {
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.shouldObservePurchases = YES;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test137WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(5)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionCompleteEventHolder = [SWKValueDescriptionHolder new];
  transactionCompleteEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTransactionComplete: {
        transactionCompleteEventHolder.intValue += 1;
        NSString *transactionId = placementInfo.params[@"store_transaction_id"];
        bool isNil = transactionId == nil;
        NSString *productId = placementInfo.params[@"product_id"];
        NSString *paywallId = placementInfo.params[@"paywall_identifier"];

        transactionCompleteEventHolder.stringValue = [NSString stringWithFormat:@"%s,%@,%@", isNil ? "true" : "false", productId, paywallId];
        break;
      }
      default:
        break;
    }
  }];

  // Register event to present the paywall
  [[Superwall sharedInstance] registerWithPlacement:@"present_data"];

  // Assert that paywall appears
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Purchase on the paywall
    CGPoint purchaseButton = CGPointMake(196, 750);
    [weakSelf touch:purchaseButton];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    CGRect customFrame = CGRectMake(0, 488, 393, 300);
    TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
      // Tap the Subscribe button
      CGPoint subscribeButton = CGPointMake(196, 766);
      [weakSelf touch:subscribeButton];

      // Wait for subscribe to occur
      [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
        // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
        CGPoint okButton = CGPointMake(196, 495);
        [weakSelf touch:okButton];

        // Ensure the paywall doesn't present.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
          TEST_ASSERT_VALUE_COMPLETION(transactionCompleteEventHolder.description, ^{
            // Register event to present the paywall
            [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger"];

            // Assert that paywall appears
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}));
          })
        })
      }];
    }));
  }));
}

/// Native SK1 purchase with observer mode enabled.
- (SWKTestOptions *)testOptions138 {
  SWKSuperwallOptions *options = [[SWKSuperwallOptions alloc] init];
  options.shouldObservePurchases = YES;
  return [SWKTestOptions testOptionsWithOptions:options];
}
- (void)test138WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)

  SKProduct *primary = [SWKStoreKitHelper sharedInstance].sk1MonthlyProduct;

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionCompleteEventHolder = [SWKValueDescriptionHolder new];
  transactionCompleteEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallPlacement:^(SWKSuperwallPlacementInfo *placementInfo) {
    switch (placementInfo.placement) {
      case SWKSuperwallPlacementTransactionComplete: {
        transactionCompleteEventHolder.intValue += 1;
        NSString *transactionId = placementInfo.params[@"store_transaction_id"];
        bool isNil = transactionId == nil;
        NSString *productId = placementInfo.params[@"product_id"];
        NSString *paywallId = placementInfo.params[@"paywall_identifier"];

        transactionCompleteEventHolder.stringValue = [NSString stringWithFormat:@"%s,%@,%@", isNil ? "true" : "false", productId, paywallId];
        break;
      }
      default:
        break;
    }
  }];

  [SWKStoreKitHelper.sharedInstance purchaseWithProduct:primary completionHandler:^(enum SWKPurchaseResult result, NSError * _Nullable error) {
    if (result == SWKPurchaseResultPurchased) {
      NSSet *activeEntitlements = [NSSet setWithObject: [[SWKEntitlement alloc] initWithId:@"default"]];
      [[Superwall sharedInstance].entitlements setActiveStatusWith:activeEntitlements];
    }
  }];

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
  CGRect customFrame = CGRectMake(0, 488, 393, 300);
  TEST_ASSERT_DELAY_CAPTURE_AREA_COMPLETION(kPaywallPresentationDelay, [SWKCaptureArea customWithFrame:customFrame], (^{
    // Tap the Subscribe button
    CGPoint subscribeButton = CGPointMake(196, 766);
    [weakSelf touch:subscribeButton];

    // Wait for subscribe to occur
    [weakSelf sleepWithTimeInterval:kPaywallPresentationDelay completionHandler:^{
      // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
      CGPoint okButton = CGPointMake(196, 495);
      [weakSelf touch:okButton];

      // Assert .transactionComplete has been called with transaction details
      TEST_ASSERT_DELAY_VALUE_COMPLETION(kPaywallPresentationDelay, transactionCompleteEventHolder.description, ^{
        // Register event to present the paywall
        [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger"];

        // Assert that paywall appears
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}));
      })
    }];
  }));
}

/// Native SK2 purchase with observer mode enabled.
- (void)test139WithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test140WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test141WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test142WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test143WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test144WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test145WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test146WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test147WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test148WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test149WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test150WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test151WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test152WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test153WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test154WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test155WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test156WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test157WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test158WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test159WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test160WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test161WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test162WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test163WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test164WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test165WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test166WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test167WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test168WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test169WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test170WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

- (void)test171WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_SKIP(@"Skipping test. This test uses SK2 which isn't available in objective-c.")
}

/// Assert survey is displayed after tapping exit button to dismiss a paywall presented by `getPaywall`.
//- (void)test73WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
//  TEST_START_NUM_ASSERTS(2)
//
//  [[Superwall sharedInstance] registerWithPlacement:@"no_paywalljs"];
//
//  // Assert infinite loading
//  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
//    // Tap the close button
//    CGPoint point = CGPointMake(43, 103);
//    [weakSelf touch:point];
//
//    // Assert that the paywall has disappeared
//    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}))
//  }))
//}

@end
