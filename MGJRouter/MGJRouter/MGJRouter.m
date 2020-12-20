//
//  MGJRouter.m
//  MGJFoundation
//
//  Created by limboy on 12/9/14.
//  Copyright (c) 2014 juangua. All rights reserved.
//

#import "MGJRouter.h"
#import <objc/runtime.h>

static NSString * const MGJ_ROUTER_WILDCARD_CHARACTER = @"~";
static NSString *specialCharacters = @"/?&.";

NSString *const MGJRouterParameterURL = @"MGJRouterParameterURL";
NSString *const MGJRouterParameterCompletion = @"MGJRouterParameterCompletion";
NSString *const MGJRouterParameterUserInfo = @"MGJRouterParameterUserInfo";


@interface MGJRouter ()
/**
 *  保存了所有已注册的 URL
 *  结构类似 @{@"beauty": @{@":id": {@"_", [block copy]}}}
 */
@property (nonatomic) NSMutableDictionary *routes;
@end

@implementation MGJRouter

+ (instancetype)sharedInstance
{
    static MGJRouter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

// 注册 URLPattern 对应的 Handler，在 handler 中可以初始化 VC，然后对 VC 做各种操作
+ (void)registerURLPattern:(NSString *)URLPattern toHandler:(MGJRouterHandler)handler
{
    [[self sharedInstance] addURLPattern:URLPattern andHandler:handler];
}

// 取消注册某个 URL Pattern
+ (void)deregisterURLPattern:(NSString *)URLPattern
{
    [[self sharedInstance] removeURLPattern:URLPattern];
}

// 打开此 URL
+ (void)openURL:(NSString *)URL
{
    [self openURL:URL completion:nil];
}

// 打开此 URL，同时当操作完成时，执行额外的代码
+ (void)openURL:(NSString *)URL completion:(void (^)(id result))completion
{
    [self openURL:URL withUserInfo:nil completion:completion];
}

// 打开此 URL，带上附加信息，同时当操作完成时，执行额外的代码
+ (void)openURL:(NSString *)URL withUserInfo:(NSDictionary *)userInfo completion:(void (^)(id result))completion
{
    // utf8编码
    URL = [URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    // 匹配URL的参数
    NSMutableDictionary *parameters = [[self sharedInstance] extractParametersFromURL:URL matchExactly:NO];
    
    // 遍历参数
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, NSString *obj, BOOL *stop) {
        // 对字符串value进行编码
        if ([obj isKindOfClass:[NSString class]]) {
            parameters[key] = [obj stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }];
    
    // 参数存在
    if (parameters) {
        // 获取参数中的 handler block对象
        MGJRouterHandler handler = parameters[@"block"];
        if (completion) {
            // 添加完成block
            parameters[MGJRouterParameterCompletion] = completion;
        }
        if (userInfo) {
            // 添加用户信息
            parameters[MGJRouterParameterUserInfo] = userInfo;
        }
        // handler存在
        if (handler) {
            // 将参数中handler block移除
            [parameters removeObjectForKey:@"block"];
            // 执行handler block，并传递参数数据
            handler(parameters);
        }
    }
}

// 是否可以打开URL
+ (BOOL)canOpenURL:(NSString *)URL
{
    return [[self sharedInstance] extractParametersFromURL:URL matchExactly:NO] ? YES : NO;
}

// 是否可以打开URL，完全匹配
+ (BOOL)canOpenURL:(NSString *)URL matchExactly:(BOOL)exactly {
    return [[self sharedInstance] extractParametersFromURL:URL matchExactly:YES] ? YES : NO;
}

// 调用此方法来拼接 urlpattern 和 parameters
+ (NSString *)generateURLWithPattern:(NSString *)pattern parameters:(NSArray *)parameters
{
    // 冒号开始位置
    NSInteger startIndexOfColon = 0;
    // 占位符数组
    NSMutableArray *placeholders = [NSMutableArray array];
    
    // 遍历pattern
    for (int i = 0; i < pattern.length; i++) {
        // 当前位置字符
        NSString *character = [NSString stringWithFormat:@"%c", [pattern characterAtIndex:i]];
        if ([character isEqualToString:@":"]) {
            // 如果是冒号，记录位置
            startIndexOfColon = i;
        }
        // 冒号存在，当前字符比冒号的位置至少大一个位置，当前字符包含在指定字符串中
        if ([specialCharacters rangeOfString:character].location != NSNotFound && i > (startIndexOfColon + 1) && startIndexOfColon) {
            // 范围，从冒号到指定字符前一个
            NSRange range = NSMakeRange(startIndexOfColon, i - startIndexOfColon);
            // 获取占位符
            NSString *placeholder = [pattern substringWithRange:range];
            // 占位符中不存在指定字符串中的字符
            if (![self checkIfContainsSpecialCharacter:placeholder]) {
                // 添加到占位符数组
                [placeholders addObject:placeholder];
                // 冒号位置重新置为0
                startIndexOfColon = 0;
            }
        }
        // 
        if (i == pattern.length - 1 && startIndexOfColon) {
            NSRange range = NSMakeRange(startIndexOfColon, i - startIndexOfColon + 1);
            NSString *placeholder = [pattern substringWithRange:range];
            if (![self checkIfContainsSpecialCharacter:placeholder]) {
                [placeholders addObject:placeholder];
            }
        }
    }
    
    __block NSString *parsedResult = pattern;
    
    [placeholders enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        idx = parameters.count > idx ? idx : parameters.count - 1;
        parsedResult = [parsedResult stringByReplacingOccurrencesOfString:obj withString:parameters[idx]];
    }];
    
    return parsedResult;
}

+ (id)objectForURL:(NSString *)URL withUserInfo:(NSDictionary *)userInfo
{
    MGJRouter *router = [MGJRouter sharedInstance];
    
    URL = [URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *parameters = [router extractParametersFromURL:URL matchExactly:NO];
    MGJRouterObjectHandler handler = parameters[@"block"];
    
    if (handler) {
        if (userInfo) {
            parameters[MGJRouterParameterUserInfo] = userInfo;
        }
        [parameters removeObjectForKey:@"block"];
        return handler(parameters);
    }
    return nil;
}

+ (id)objectForURL:(NSString *)URL
{
    return [self objectForURL:URL withUserInfo:nil];
}

+ (void)registerURLPattern:(NSString *)URLPattern toObjectHandler:(MGJRouterObjectHandler)handler
{
    [[self sharedInstance] addURLPattern:URLPattern andObjectHandler:handler];
}

// 注册 URLPattern 对应的 Handler。在全局路由字典中保存
- (void)addURLPattern:(NSString *)URLPattern andHandler:(MGJRouterHandler)handler
{
    NSMutableDictionary *subRoutes = [self addURLPattern:URLPattern];
    if (handler && subRoutes) {
        subRoutes[@"_"] = [handler copy];
    }
}

// 添加URLPattern 与 handler 到全局路由字典中
- (void)addURLPattern:(NSString *)URLPattern andObjectHandler:(MGJRouterObjectHandler)handler
{
    NSMutableDictionary *subRoutes = [self addURLPattern:URLPattern];
    if (handler && subRoutes) {
        // 将handler进行保存，key为:_
        /*
         {
             mgj =     {
                 foo =         {
                     bar =             {
                         "_" = "<__NSMallocBlock__: 0x600000e29ce0>";
                     };
                 };
             };
         }
         */
        subRoutes[@"_"] = [handler copy];
    }
}

- (NSMutableDictionary *)addURLPattern:(NSString *)URLPattern
{
    // 路径组成
    NSArray *pathComponents = [self pathComponentsFromURL:URLPattern];

    // 全局路由数据
    /*
     格式：
     {
         mgj =     {
             foo =         {
                 bar =             {
                 };
             };
         };
     }
     */
    NSMutableDictionary* subRoutes = self.routes;
    
    for (NSString* pathComponent in pathComponents) {
        if (![subRoutes objectForKey:pathComponent]) {
            subRoutes[pathComponent] = [[NSMutableDictionary alloc] init];
        }
        subRoutes = subRoutes[pathComponent];
    }
    return subRoutes;
}

#pragma mark - Utils

// 从url提取参数,是否完全匹配
- (NSMutableDictionary *)extractParametersFromURL:(NSString *)url matchExactly:(BOOL)exactly
{
    // 创建本方法将要返回的参数
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    // 添加url键值对
    parameters[MGJRouterParameterURL] = url;
    
    // 全局路由字典
    NSMutableDictionary* subRoutes = self.routes;
    // 路径组成
    NSArray* pathComponents = [self pathComponentsFromURL:url];
    
    // 是否找到与url匹配的handler，默认为NO
    BOOL found = NO;
    // borrowed from HHRouter(https://github.com/Huohua/HHRouter)
    // 遍历URL组成
    for (NSString* pathComponent in pathComponents) {
        
        // 对 key 进行排序，这样可以把 ~ 放到最后
        NSArray *subRoutesKeys =[subRoutes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2];
        }];
        
        // 遍历全局路由字典的某一层的keys数组
        for (NSString* key in subRoutesKeys) {
            // 当全局路由字典的某一层的一个key与URL路径组成一样，或key是只有协议情况下的占位符
            if ([key isEqualToString:pathComponent] || [key isEqualToString:MGJ_ROUTER_WILDCARD_CHARACTER]) {
                // 找到
                found = YES;
                // 将全局路由信息的下一层，再次赋值
                subRoutes = subRoutes[key];
                break;
            } else if ([key hasPrefix:@":"]) {
                found = YES;
                subRoutes = subRoutes[key];
                NSString *newKey = [key substringFromIndex:1];
                NSString *newPathComponent = pathComponent;
                // 再做一下特殊处理，比如 :id.html -> :id
                if ([self.class checkIfContainsSpecialCharacter:key]) {
                    NSCharacterSet *specialCharacterSet = [NSCharacterSet characterSetWithCharactersInString:specialCharacters];
                    NSRange range = [key rangeOfCharacterFromSet:specialCharacterSet];
                    if (range.location != NSNotFound) {
                        // 把 pathComponent 后面的部分也去掉
                        newKey = [newKey substringToIndex:range.location - 1];
                        NSString *suffixToStrip = [key substringFromIndex:range.location];
                        newPathComponent = [newPathComponent stringByReplacingOccurrencesOfString:suffixToStrip withString:@""];
                    }
                }
                parameters[newKey] = newPathComponent;
                break;
            } else if (exactly) {
                found = NO;
            }
        }
        
        // 如果没有找到该 pathComponent 对应的 handler，则以上一层的 handler 作为 fallback
        if (!found && !subRoutes[@"_"]) {
            return nil;
        }
    }
    
    // Extract Params From Query.
    // 查询URL组件中名称/值对的数组
    NSArray<NSURLQueryItem *> *queryItems = [[NSURLComponents alloc] initWithURL:[[NSURL alloc] initWithString:url] resolvingAgainstBaseURL:false].queryItems;
    
    // 添加查询键值对
    for (NSURLQueryItem *item in queryItems) {
        parameters[item.name] = item.value;
    }

    if (subRoutes[@"_"]) {
        // 添加handler block
        parameters[@"block"] = [subRoutes[@"_"] copy];
    }
    
    // 返回参数
    return parameters;
}

//
- (void)removeURLPattern:(NSString *)URLPattern
{
    // 路径组成
    NSMutableArray *pathComponents = [NSMutableArray arrayWithArray:[self pathComponentsFromURL:URLPattern]];
    
    // 只删除该 pattern 的最后一级
    if (pathComponents.count >= 1) {
        // 假如 URLPattern 为 a/b/c, components 就是 @"a.b.c" 正好可以作为 KVC 的 key
        // 对数组中字符串以 . 进行拼接
        NSString *components = [pathComponents componentsJoinedByString:@"."];
        // 通过kvc获取，URLPattern在全局路由中最深一层的字典
        /*格式
         {
             "_" = "<__NSMallocBlock__: 0x6000021ab030>";
         }
         */
        NSMutableDictionary *route = [self.routes valueForKeyPath:components];
        
        // 说明存在URLPattern对应的路由注册数据
        if (route.count >= 1) {
            // 路径组成最后一项
            NSString *lastComponent = [pathComponents lastObject];
            // 移除路径组成最后一项
            [pathComponents removeLastObject];
            
            // 有可能是根 key，这样就是 self.routes 了
            route = self.routes;
            if (pathComponents.count) {
                // 路径组成中移除最后一项，组成的字符串
                NSString *componentsWithoutLast = [pathComponents componentsJoinedByString:@"."];
                // 通过kvc获取，URLPattern最后一项组成对应的路由数据
                route = [self.routes valueForKeyPath:componentsWithoutLast];
            }
            // 移除URLPattern最后一项组成对应的路由数据，handler数据同时被移除
            [route removeObjectForKey:lastComponent];
        }
    }
}

// 获取url路径组成
- (NSArray*)pathComponentsFromURL:(NSString*)URL
{
    NSMutableArray *pathComponents = [NSMutableArray array];
    // 是否包含://
    if ([URL rangeOfString:@"://"].location != NSNotFound) {
        // 对url分割
        NSArray *pathSegments = [URL componentsSeparatedByString:@"://"];
        // 如果 URL 包含协议，那么把协议作为第一个元素放进去
        [pathComponents addObject:pathSegments[0]];
        
        // 如果只有协议，那么放一个占位符
        URL = pathSegments.lastObject;
        if (!URL.length) {
            [pathComponents addObject:MGJ_ROUTER_WILDCARD_CHARACTER];
        }
    }

    for (NSString *pathComponent in [[NSURL URLWithString:URL] pathComponents]) {
        if ([pathComponent isEqualToString:@"/"]) continue;
        if ([[pathComponent substringToIndex:1] isEqualToString:@"?"]) break;
        [pathComponents addObject:pathComponent];
    }
    return [pathComponents copy];
}

- (NSMutableDictionary *)routes
{
    if (!_routes) {
        _routes = [[NSMutableDictionary alloc] init];
    }
    return _routes;
}

#pragma mark - Utils
// 检查是否包含指定字符
+ (BOOL)checkIfContainsSpecialCharacter:(NSString *)checkedString {
    // 指定字符串的字符集
    NSCharacterSet *specialCharactersSet = [NSCharacterSet characterSetWithCharactersInString:specialCharacters];
    // checkedString中的字符 是否在 specialCharactersSet 中存在
    return [checkedString rangeOfCharacterFromSet:specialCharactersSet].location != NSNotFound;
}

@end
