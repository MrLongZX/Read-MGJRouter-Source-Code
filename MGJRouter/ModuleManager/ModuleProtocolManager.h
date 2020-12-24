//
//  ModuleProtocolManager.h
//  MGJRouterDemo
//
//  Created by suyoulong on 2020/12/24.
//  Copyright © 2020 suyoulong. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ModuleProtocolManager : NSObject

+ (void)registServiceProvide:(id)provide forProtocol:(Protocol *)protocol;
+ (id)serviceProvideForProtocol:(Protocol *)protocol;

@end

NS_ASSUME_NONNULL_END
