//
//  SocketIOPacket.h
//  v0.5.1
//
//  based on
//  socketio-cocoa https://github.com/fpotter/socketio-cocoa
//  by Fred Potter <fpotter@pieceable.com>
//
//  using
//  https://github.com/square/SocketRocket
//
//  reusing some parts of
//  /socket.io/socket.io.js
//
//  Created by Philipp Kyeck http://beta-interactive.de
//
//  With help from
//    https://github.com/pkyeck/socket.IO-objc/blob/master/CONTRIBUTORS.md
//

#import <Foundation/Foundation.h>
#import "SocketIOTransport.h"

@interface SocketIOPacket : NSObject
{
    NSString *type;
    NSString *pId;
    NSString *ack;
    NSString *name;
    NSString *data;
    NSArray *args;
    NSString *endpoint;
    NSArray *_types;
    NSArray *_typesMessage;
}

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *pId;
@property (nonatomic, copy) NSString *ack;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *data;
@property (nonatomic, copy) NSString *endpoint;
@property (nonatomic, copy) NSArray *args;

- (id) initWithType:(NSString *)packetType;
- (id) initWithType:(NSString *)packetType
                   using:(SocketIOVersion) version;
- (id) initWithTypeIndex:(int)index;
- (id) initWithTypeIndex:(int)index
                   using:(SocketIOVersion) version;
- (id) dataAsJSON;
- (NSString *) toString;
- (NSString *) toString:(SocketIOVersion) version;
- (NSNumber *) typeAsNumber;
- (NSString *) typeForIndex:(int)index;

@end
