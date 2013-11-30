//
//  SocketIO+Blocks.h
//  LetterWar
//
//  Created by Антон Домашнев on 06.11.13.
//  Copyright (c) 2013 Anton Domashnev. All rights reserved.
//

#import "SocketIO.h"

@interface SocketIOBlocksDelegate : NSObject<SocketIODelegate>

@end

@interface SocketIO (Blocks)

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withCallback:(void (^)(SocketIO *, NSError *))callback;
- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withCallback:(void (^)(SocketIO *, NSError *))callback;
- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withNamespace:(NSString *)endpoint withCallback:(void (^)(SocketIO *, NSError *))callback;

- (void)addErrorHandler:(void (^)(SocketIO *, NSError *))handler forKey:(NSString *)key;
- (void)removeErrorHandlerForKey:(NSString *)key;

- (void)addMessageHandler:(void (^)(SocketIO *, SocketIOPacket *))handler forKey:(NSString *)key;
- (void)removeMessageHandlerForKey:(NSString *)key;

- (void)addJSONHandler:(void (^)(SocketIO *, SocketIOPacket *))handler forKey:(NSString *)key;
- (void)removeJSONHandlerForKey:(NSString *)key;

- (void)addEventHandler:(void (^)(SocketIO *, SocketIOPacket *))handler forKey:(NSString *)key;
- (void)removeEventHandlerForKey:(NSString *)key;

@end
