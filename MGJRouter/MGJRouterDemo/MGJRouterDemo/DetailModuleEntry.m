//
//  DetailModuleEntry.m
//  MGJRouterDemo
//
//  Created by suyoulong on 2020/12/24.
//  Copyright © 2020 suyoulong. All rights reserved.
//

#import "DetailModuleEntry.h"
#import "PublicProtocl.h"
#import "DemoDetailViewController.h"
#import "ModuleProtocolManager.h"

@interface DetailModuleEntry ()<DetailModuleEntryProtocol>

@end

@implementation DetailModuleEntry

+ (void)load
{
    [ModuleProtocolManager registServiceProvide:[[self alloc] init] forProtocol:@protocol(DetailModuleEntryProtocol)];
}

- (UIViewController *)detailViewControllerWithId:(NSString*)idString withName:(NSString *)name
{
    DemoDetailViewController *detailVC = [[DemoDetailViewController alloc] initWithId:idString withName:name];
    return detailVC;
}


@end
