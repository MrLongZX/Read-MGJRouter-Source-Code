//
//  PublicProtocl.h
//  MGJRouterDemo
//
//  Created by suyoulong on 2020/12/24.
//  Copyright © 2020 suyoulong. All rights reserved.
//

#ifndef PublicProtocl_h
#define PublicProtocl_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol DetailModuleEntryProtocol <NSObject>

@required;
- (UIViewController *)detailViewControllerWithId:(NSString*)Id withName:(NSString *)name;

@end


#endif /* PublicProtocl_h */
