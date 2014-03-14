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

#import "SocketIOPacket.h"
#import "SocketIOJSONSerialization.h"

@implementation SocketIOPacket

@synthesize type, pId, name, ack, data, args, endpoint;

- (id) init
{
    self = [super init];
    if (self) {
        _types = [NSArray arrayWithObjects: @"disconnect",
                  @"connect",
                  @"heartbeat",
                  @"message",
                  @"json",
                  @"event",
                  @"ack",
                  @"error",
                  @"noop",
                  nil];
    }
    return self;
}

- (id) initWithType:(NSString *)packetType
{
    self = [self init];
    if (self) {
        self.type = packetType;
    }
    return self;
}

- (id) initWithTypeIndex:(int)index
{
    self = [self init];
    if (self) {
        self.type = [self typeForIndex:index];
    }
    return self;
}

- (id) dataAsJSON
{
    if (self.data) {
        NSData *utf8Data = [self.data dataUsingEncoding:NSUTF8StringEncoding];
        return [SocketIOJSONSerialization objectFromJSONData:utf8Data error:nil];
    }
    else {
        return nil;
    }
}

- (NSNumber *) typeAsNumber
{
    NSUInteger index = [_types indexOfObject:self.type];
    NSNumber *num = [NSNumber numberWithUnsignedInteger:index];
    return num;
}

- (NSString *) typeForIndex:(int)index
{
    return [_types objectAtIndex:index];
}

- (void) dealloc
{
    _types = nil;
    
    type = nil;
    pId = nil;
    name = nil;
    ack = nil;
    data = nil;
    args = nil;
    endpoint = nil;
}

@end

