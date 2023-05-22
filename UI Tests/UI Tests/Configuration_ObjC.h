//
//  Configuration_ObjC.h
//  UI Tests
//
//  Created by Bryan Dubno on 3/7/23.
//

#import <Foundation/Foundation.h>

@protocol SWKTestConfiguration;
@interface SWKConfigurationAutomatic : NSObject <SWKTestConfiguration>
@end

@protocol SWKTestConfiguration;
@interface SWKConfigurationAdvanced : NSObject <SWKTestConfiguration>
@end

@protocol SWKPaywallViewControllerDelegate;
@interface SWKMockPaywallViewControllerDelegate : NSObject <SWKPaywallViewControllerDelegate>
@property (nonatomic, copy) void (^paywallViewControllerDidFinish)(SWKPaywallViewController *controller, SWKPaywallResult result, BOOL shouldDismiss);
@end
