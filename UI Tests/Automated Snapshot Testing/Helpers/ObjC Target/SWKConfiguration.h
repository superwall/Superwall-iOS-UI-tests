//
//  SWKConfiguration.h
//  UI Tests
//
//  Created by Bryan Dubno on 3/7/23.
//

#import <Foundation/Foundation.h>
#import "Automated_Snapshot_Testing-Swift.h"
#import "SnapshotTests-ObjC.h"

#define ASYNC_BEGIN \
ASYNC_BEGIN_WITH(1)

#define ASYNC_BEGIN_WITH(NUM_ASSERTS) \
XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@""]; __weak typeof(self) weakSelf = self; expectation.expectedFulfillmentCount = NUM_ASSERTS;

#define ASYNC_END \
[XCTestCase waitWithExpectation:expectation];

#define ASYNC_FULFILL \
[expectation fulfill]; weakSelf;

// After a delay, the snapshot will be taken and the expectation will be fulfilled. Don't confused this await. You'll need to use `[self sleepWithTimeInterval:completionHandler:]` if you need to wait.
#define ASYNC_TEST_ASSERT(timeInterval) \
[weakSelf assertAfter:timeInterval fulfill:expectation testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] precision:YES];

#define ASYNC_TEST_ASSERT_WITHOUT_PRECISION(timeInterval) \
[weakSelf assertAfter:timeInterval fulfill:expectation testName:[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] precision:NO];

@interface SnapshotTests_ObjC (Additions)
@property (nonatomic, strong, readonly) id<SWKTestConfiguration> configuration;
@end
