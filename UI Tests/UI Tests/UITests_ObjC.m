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
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
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
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];

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
  
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];

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
  
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning with a 0 on the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and we want to capture the video as quickly as possible.
- (void)test4WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] registerWithEvent:@"present_video"];
  
  // Wait 4 seconds before dismissing the video
  [self sleepWithTimeInterval:4.0 completionHandler:^{
    [[Superwall sharedInstance] dismissWithCompletion:^{
      // Once the video has been dismissed, wait 1 second before dismissing again
      [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
        [[Superwall sharedInstance] registerWithEvent:@"present_video"];
        
        // Assert that the video has started from the 0 sec mark (video simply counts from 0sec to 2sec and only displays those 2 values)
        TEST_ASSERT_DELAY_COMPLETION(2.0, ^{})
      }];
    }];
  }];
}

- (void)test5WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the primary and secondary products
  SKProduct *primary = [SWKStoreKitHelper sharedInstance].monthlyProduct;
  SKProduct *secondary = [SWKStoreKitHelper sharedInstance].annualProduct;
  
  if (!primary || !secondary) {
    FATAL_ERROR(@"WARNING: Unable to fetch custom products. These are needed for testing.");
    return;
  }
  
  SWKStoreProduct *primaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:primary];
  SWKStoreProduct *secondaryProduct = [[SWKStoreProduct alloc] initWithSk1Product:secondary];
  
  SWKPaywallProducts *products = [[SWKPaywallProducts alloc] initWithPrimary:primaryProduct secondary:secondaryProduct tertiary:nil];
  
  // Create PaywallOverrides
  SWKPaywallOverrides *paywallOverrides = [[SWKPaywallOverrides alloc] initWithProducts:products];
  
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
  [[Superwall sharedInstance] getPaywallForEvent:@"present_products" params:nil paywallOverrides:paywallOverrides delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] registerWithEvent:@"present_products"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
- (void)test7WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  [[Superwall sharedInstance] identifyWithUserId:@"test7"];
  [[Superwall sharedInstance] setUserAttributes:@{@"first_name": @"Charlie", @"should_display": @YES, @"some_value": @14}];
  [[Superwall sharedInstance] registerWithEvent:@"present_and_rule_user"];
  
  // Assert after a delay
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove those attributes.
      [[Superwall sharedInstance] removeUserAttributes:@[@"should_display", @"some_value"]];
      [[Superwall sharedInstance] registerWithEvent:@"present_and_rule_user"];

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
  [[Superwall sharedInstance] registerWithEvent:@"present_and_rule_user"];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Present regardless of status
- (SWKTestOptions *)testOptions9 { return [SWKTestOptions testOptionsWithPurchasedProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier]; }
- (void)test9WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [self.configuration mockSubscribedUserWithProductIdentifier:SWKStoreKitHelperConstants.customAnnualProductIdentifier completionHandler:^{
    [[Superwall sharedInstance] registerWithEvent:@"present_always"];

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
  //  [[Superwall sharedInstance] registerWithEvent:@"present_products"];
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
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
  // Assert that the first name is displayed
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Remove user attribute
      [[Superwall sharedInstance] removeUserAttributes:@[@"first_name"]];
      [[Superwall sharedInstance] registerWithEvent:@"present_data"];
      
      // Assert that the first name is NOT displayed
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Add new user attribute
          [[Superwall sharedInstance] setUserAttributes:@{ @"first_name": @"Sawyer" }];
          [[Superwall sharedInstance] registerWithEvent:@"present_data"];

          TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
        }];
      }));
    }];
  }));
}

// Test trigger: off
- (void)test12WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] registerWithEvent:@"keep_this_trigger_off"];
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Test trigger: not in the dashboard
- (void)test13WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  [[Superwall sharedInstance] registerWithEvent:@"i_just_made_this_up_and_it_dne"];
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Test trigger: not-allowed standard event (paywall_close)
- (void)test14WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  [[Superwall sharedInstance] registerWithEvent:@"present_always"];
  
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
  [[Superwall sharedInstance] registerWithEvent:@"present_always"];
  [[Superwall sharedInstance] registerWithEvent:@"present_always" params:@{@"some_param_1": @"hello"}];
  [[Superwall sharedInstance] registerWithEvent:@"present_always"];
  
  // After delay, assert that there was a presentation
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      
      [[Superwall sharedInstance] registerWithEvent:@"present_always"];
      [[Superwall sharedInstance] identifyWithUserId:@"1111"];
      [[Superwall sharedInstance] registerWithEvent:@"present_always"];
      
      // After delay, assert that there was a presentation
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          
          SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];
          __block NSString *experimentId;
          
          [handler onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
            [[Superwall sharedInstance] registerWithEvent:@"present_always"];
            experimentId = paywallInfo.experiment.id;
            // Wait and assert.
            TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{
              TEST_ASSERT_VALUE_COMPLETION(experimentId, ^{});
            });
          }];
          
          // Present paywall
          [[Superwall sharedInstance] registerWithEvent:@"present_always" params:nil handler:handler];
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
  
  [[Superwall sharedInstance] registerWithEvent:@"present_always" params:nil handler:handler];

  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

// Clusterfucks by Jake™
- (void)test17WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  [[Superwall sharedInstance] identifyWithUserId:@"test0"];
  [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      // Set identity
      [[Superwall sharedInstance] identifyWithUserId:@"test2"];
      [[Superwall sharedInstance] setUserAttributes:@{ @"first_name" : @"Jack" }];
      
      // Reset the user identity
      [[Superwall sharedInstance] reset];
      
      [[Superwall sharedInstance] registerWithEvent:@"present_data"];
      
      TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          // Present paywall
          [[Superwall sharedInstance] registerWithEvent:@"present_always"];
          [[Superwall sharedInstance] registerWithEvent:@"present_always" params:@{@"some_param_1": @"hello"}];
          [[Superwall sharedInstance] registerWithEvent:@"present_always"];

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
  [[Superwall sharedInstance] getPaywallForEvent:@"present_urls" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    // Dismiss any view controllers
    [weakSelf dismissViewControllersWithCompletionHandler:^{
      
      [[Superwall sharedInstance] getPresentationResultForEvent:@"present_and_rule_user" completionHandler:^(SWKPresentationResult * _Nonnull result) {
        
        // Dismiss any view controllers
        [weakSelf dismissViewControllersWithCompletionHandler:^{
          
          // Show a paywall
          [[Superwall sharedInstance] registerWithEvent:@"present_always"];
          
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
                  [[Superwall sharedInstance] registerWithEvent:@"present_data"];

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
  [[Superwall sharedInstance] registerWithEvent:@"present_urls"];
  
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
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
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
        [[Superwall sharedInstance] registerWithEvent:@"present_data"];
        
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
  [[Superwall sharedInstance] registerWithEvent:@"register_nongated_paywall"];
  
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
    [[Superwall sharedInstance] registerWithEvent:@"register_nongated_paywall"];

    // Assert that paywall DOES not appear
    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
  }];
}

/// Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
/// Result: paywall should display, after user subscribes, don't show another paywall
- (void)test25WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(3)
  
  // Register event
  [[Superwall sharedInstance] registerWithEvent:@"register_nongated_paywall"];
  
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
          [[Superwall sharedInstance] registerWithEvent:@"register_nongated_paywall"];

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
  [[Superwall sharedInstance] registerWithEvent:@"register_gated_paywall" params:nil handler:nil feature:^{
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
    [[Superwall sharedInstance] registerWithEvent:@"register_gated_paywall" params:nil handler:nil feature:^{
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
  [[Superwall sharedInstance] getPresentationResultForEvent:@"present_data" completionHandler:^(SWKPresentationResult * _Nonnull result) {
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
  [[Superwall sharedInstance] getPresentationResultForEvent:@"present_and_rule_user" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

// Presentation result: `eventNotFound`
- (void)test30WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForEvent:@"some_random_not_found_event" completionHandler:^(SWKPresentationResult * _Nonnull result) {
    // Assert the value of the result's description
    NSString *value = [SWKPresentationValueObjcHelper description:result.value];
    TEST_ASSERT_VALUE_COMPLETION(value, ^{})
  }];
}

// Presentation result: `holdOut`
- (void)test31WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START
  
  // Get the presentation result for the specified event
  [[Superwall sharedInstance] getPresentationResultForEvent:@"holdout" completionHandler:^(SWKPresentationResult * _Nonnull result) {
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
    [[Superwall sharedInstance] getPresentationResultForEvent:@"present_data" completionHandler:^(SWKPresentationResult * _Nonnull result) {
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
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
  // Assert after a delay
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
}

/// Call reset while a paywall is displayed should not cause a crash
- (void)test34WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)
  
  // Register event
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];
  
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
  [[Superwall sharedInstance] getPaywallForEvent:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] getPaywallForEvent:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] getPaywallForEvent:@"restore" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] getPaywallForEvent:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] getPaywallForEvent:@"restore" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [[Superwall sharedInstance] getPaywallForEvent:@"present_data" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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

    [[Superwall sharedInstance] registerWithEvent:event params:nil handler:paywallPresentationHandler feature:^{
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventAppInstall:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventAppLaunch:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSessionStart:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventAppClose:
        appCloseEventHolder.intValue += 1;
        appCloseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventAppOpen:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventDeepLink:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventDeepLink:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventTransactionAbandon:
        transactionAbandonEventHolder.intValue += 1;
        transactionAbandonEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithEvent:@"campaign_trigger"];

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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventPaywallDecline:
        paywallDeclineEventHolder.intValue += 1;
        paywallDeclineEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithEvent:@"campaign_trigger"];

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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventTransactionFail:
        transactionFailEventHolder.intValue += 1;
        transactionFailEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Fail all transactions
  [self failTransactionsWithCompletionHandler:^{
    [[Superwall sharedInstance] registerWithEvent:@"campaign_trigger"];

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
  [[Superwall sharedInstance] registerWithEvent:@"present_urls"];

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
  [[Superwall sharedInstance] getPaywallForEvent:@"restore" params:nil paywallOverrides:nil delegate:delegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithEvent:@"show_survey_with_other" params:nil handler:nil feature:^{
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
        [[Superwall sharedInstance] registerWithEvent:@"show_survey_with_other" params:nil handler:nil];

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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithEvent:@"show_survey_with_other" params:nil handler:nil feature:^{
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithEvent:@"zero_percent_survey" params:nil handler:nil feature:^{
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithEvent:@"modal_paywall_with_survey" params:nil handler:nil feature:^{
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithEvent:@"campaign_trigger" params:nil handler:nil feature:^{
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
  [superwallDelegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
        surveyResponseEventHolder.intValue += 1;
        break;
      default:
        break;
    }
  }];

  // Get the paywall view controller
  [[Superwall sharedInstance] getPaywallForEvent:@"modal_paywall_with_survey" params:nil paywallOverrides:nil delegate:paywallDelegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [superwallDelegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      case SWKSuperwallEventPaywallClose:
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
  [[Superwall sharedInstance] getPaywallForEvent:@"show_survey_with_other" params:nil paywallOverrides:nil delegate:paywallDelegate completion:^(SWKGetPaywallResult * _Nonnull result) {
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyResponse:
        surveyResponseEventHolder.intValue += 1;
        surveyResponseEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  // Register event and present an alert controller
  [[Superwall sharedInstance] registerWithEvent:@"survey_with_purchase_button" params:nil handler:nil feature:^{
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

  [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
    NSDictionary *userAttributes = [[Superwall sharedInstance] userAttributes];
    NSString *seedValueString = userAttributes[@"seed"];
    int seedValueInt = [seedValueString intValue];
    seedHolder.intValue = seedValueInt;

    NSString *value = seedHolder.description;
    TEST_ASSERT_VALUE_COMPLETION(value, ^{
      [[Superwall sharedInstance] reset];

      [[Superwall sharedInstance] identifyWithUserId:@"abc"];

      [weakSelf sleepWithTimeInterval:1.0 completionHandler:^{
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventTouchesBegan:
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
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventSurveyClose:
        surveyCloseEventHolder.intValue += 1;
        surveyCloseEventHolder.stringValue = @"Yes";
        break;
      default:
        break;
    }
  }];

  [[Superwall sharedInstance] registerWithEvent:@"survey_with_close_option"];

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
  TEST_START_NUM_ASSERTS(3)

  // Create Superwall delegate
  SWKMockSuperwallDelegate *delegate = [[SWKMockSuperwallDelegate alloc] init];
  [self holdStrongly:delegate];

  // Set delegate
  [Superwall sharedInstance].delegate = delegate;

  // Create value handler
  SWKValueDescriptionHolder *transactionCompleteEventHolder = [SWKValueDescriptionHolder new];
  transactionCompleteEventHolder.stringValue = @"No";

  // Respond to Superwall events
  [delegate handleSuperwallEvent:^(SWKSuperwallEventInfo *eventInfo) {
    switch (eventInfo.event) {
      case SWKSuperwallEventTransactionComplete: {
        transactionCompleteEventHolder.intValue += 1;
        NSString *transactionId = eventInfo.params[@"transaction_id"];
        NSString *productId = eventInfo.params[@"product_id"];
        NSString *paywallId = eventInfo.params[@"paywall_id"];
        
        transactionCompleteEventHolder.stringValue = [NSString stringWithFormat:@"%@,%@,%@", transactionId, productId, paywallId];
        break;
      }
      default:
        break;
    }
  }];

  // Register event to present the paywall
  [[Superwall sharedInstance] registerWithEvent:@"present_data"];

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
        [[Superwall sharedInstance] registerWithEvent:@"present_data"];

        // Ensure the paywall doesn't present.
        TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, ^{})
      }];
    }));
  }));
}

/// Register event and land in holdout. Register again and present paywall.
- (void)test76WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
  TEST_START_NUM_ASSERTS(2)

  [[Superwall sharedInstance] registerWithEvent:@"holdout_one_time_occurrence"];

  // Assert that no paywall appears (holdout)
  TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{
    [[Superwall sharedInstance] registerWithEvent:@"holdout_one_time_occurrence"];

    TEST_ASSERT_DELAY_COMPLETION(kPaywallPresentationDelay, (^{}));
  }));
}

/// Assert survey is displayed after tapping exit button to dismiss a paywall presented by `getPaywall`.
//- (void)test73WithCompletionHandler:(void (^ _Nonnull)(NSError * _Nullable))completionHandler {
//  TEST_START_NUM_ASSERTS(2)
//
//  [[Superwall sharedInstance] registerWithEvent:@"no_paywalljs"];
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
