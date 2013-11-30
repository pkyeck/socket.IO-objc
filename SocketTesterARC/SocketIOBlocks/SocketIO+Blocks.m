//
//  SocketIO+Blocks.m
//  LetterWar
//
//  Created by Антон Домашнев on 06.11.13.
//  Copyright (c) 2013 Anton Domashnev. All rights reserved.
//

#import "SocketIO+Blocks.h"

#import <objc/runtime.h>

#define SocketIOBlockSafeRun(block, ...) block ? block(__VA_ARGS__) : nil

@interface SocketIOBlocksDelegate()<SocketIODelegate>

@property (nonatomic, copy) void (^onStart)(SocketIO *, NSError *);

@property (nonatomic, strong) NSMutableDictionary *onErrorBlocksDictionary;
@property (nonatomic, strong) NSMutableDictionary *onMessageBlocksDictionary;
@property (nonatomic, strong) NSMutableDictionary *onJSONBlocksDictionary;
@property (nonatomic, strong) NSMutableDictionary *onEventBlocksDictionary;

@end

@implementation SocketIOBlocksDelegate

- (instancetype)init{
    
    if(self = [super init]){
        
        self.onErrorBlocksDictionary = [NSMutableDictionary new];
        self.onMessageBlocksDictionary = [NSMutableDictionary new];
        self.onJSONBlocksDictionary = [NSMutableDictionary new];
        self.onEventBlocksDictionary = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)socketIODidConnect:(SocketIO *)socket{
    
    SocketIOBlockSafeRun(self.onStart, socket, nil);
}

- (void)socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error{
    
    SocketIOBlockSafeRun(self.onStart, socket, error);
}

- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet{
    
    [self.onMessageBlocksDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        void(^block)(SocketIO *, SocketIOPacket *) = obj;
        SocketIOBlockSafeRun(block, socket, packet);
    }];
}

- (void) socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet{
    
    [self.onJSONBlocksDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        void(^block)(SocketIO *, SocketIOPacket *) = obj;
        SocketIOBlockSafeRun(block, socket, packet);
    }];
}

- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet{
    
    [self.onEventBlocksDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        void(^block)(SocketIO *, SocketIOPacket *) = obj;
        SocketIOBlockSafeRun(block, socket, packet);
    }];
}

- (void) socketIO:(SocketIO *)socket onError:(NSError *)error{
    
    [self.onErrorBlocksDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        void(^block)(SocketIO *, NSError *) = obj;
        SocketIOBlockSafeRun(block, socket ,error);
    }];
}

@end

@interface SocketIO(Private)

@property (nonatomic, strong) SocketIOBlocksDelegate *blocksDelegate;

@end

@implementation SocketIO (Blocks)

- (void)setBlocksDelegate:(SocketIOBlocksDelegate *)blocksDelegate{
    
    objc_setAssociatedObject(self, @"SocketIOBlocksDelegate", blocksDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SocketIOBlocksDelegate *)blocksDelegate{
    
    return objc_getAssociatedObject(self, @"SocketIOBlocksDelegate");
}

#pragma mark - Helpers

- (void)setBlocksDelegateIfNeeded{
    
    if(!self.delegate || ![self.delegate isKindOfClass:[SocketIOBlocksDelegate class]]){
        self.blocksDelegate = [SocketIOBlocksDelegate new];
        self.delegate = self.blocksDelegate;
    }
}

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withCallback:(void (^)(SocketIO *, NSError *))callback{
    
    [self connectToHost:host onPort:port withParams:nil withCallback:callback];
}

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withCallback:(void (^)(SocketIO *, NSError *))callback{
    
    [self connectToHost:host onPort:port withParams:params withNamespace:nil withCallback:callback];
}

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withNamespace:(NSString *)endpoint withCallback:(void (^)(SocketIO *, NSError *))callback{
    
    [self setBlocksDelegateIfNeeded];
    ((SocketIOBlocksDelegate *)self.delegate).onStart = callback;
    
    [self connectToHost:host onPort:port withParams:params withNamespace:endpoint];
}

#pragma mark - @selector(socketIO:onError:)

- (void)addErrorHandler:(void (^)(SocketIO *, NSError *))handler forKey:(NSString *)key{
    
    NSParameterAssert(key);
    NSParameterAssert(handler);
    
    [self setBlocksDelegateIfNeeded];
    ((SocketIOBlocksDelegate *)self.delegate).onErrorBlocksDictionary[key] = handler;
}

- (void)removeErrorHandlerForKey:(NSString *)key{
    
    NSParameterAssert(key);
    
    if(self.delegate){
        [((SocketIOBlocksDelegate *)self.delegate).onErrorBlocksDictionary removeObjectForKey:key];
    }
}

#pragma mark - @selector(socketIO:didReceiveMessage:)

- (void)addMessageHandler:(void (^)(SocketIO *, SocketIOPacket *))handler forKey:(NSString *)key{
    
    NSParameterAssert(key);
    NSParameterAssert(handler);
    
    [self setBlocksDelegateIfNeeded];
    ((SocketIOBlocksDelegate *)self.delegate).onMessageBlocksDictionary[key] = handler;
}

- (void)removeMessageHandlerForKey:(NSString *)key{
    
    NSParameterAssert(key);
    
    if(self.delegate){
        [((SocketIOBlocksDelegate *)self.delegate).onMessageBlocksDictionary removeObjectForKey:key];
    }
}

#pragma mark - @selector(socketIO:didReceiveJSON:)

- (void)addJSONHandler:(void (^)(SocketIO *, SocketIOPacket *))handler forKey:(NSString *)key{
    
    NSParameterAssert(key);
    NSParameterAssert(handler);
    
    [self setBlocksDelegateIfNeeded];
    ((SocketIOBlocksDelegate *)self.delegate).onJSONBlocksDictionary[key] = handler;
}

- (void)removeJSONHandlerForKey:(NSString *)key{
    
    NSParameterAssert(key);
    
    if(self.delegate){
        [((SocketIOBlocksDelegate *)self.delegate).onJSONBlocksDictionary removeObjectForKey:key];
    }
}

#pragma mark - @selector(socketIO:didReceiveEvent:)

- (void)addEventHandler:(void (^)(SocketIO *, SocketIOPacket *))handler forKey:(NSString *)key{
    
    NSParameterAssert(key);
    NSParameterAssert(handler);
    
    [self setBlocksDelegateIfNeeded];
    ((SocketIOBlocksDelegate *)self.delegate).onEventBlocksDictionary[key] = handler;
}

- (void)removeEventHandlerForKey:(NSString *)key{
    
    NSParameterAssert(key);
    
    if(self.delegate){
        [((SocketIOBlocksDelegate *)self.delegate).onEventBlocksDictionary removeObjectForKey:key];
    }
}

@end
