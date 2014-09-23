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
    if (self)
    {
        _separator = @":";
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


- (NSString *) toString
{
    NSMutableArray *encoded = [NSMutableArray arrayWithObject:[self typeAsNumber]];
    
    NSString *pIdL = self.pId != nil ? self.pId : @"";


    if( !([self isKindOfClass:[SocketIOPacketV10x class]]) ){
        if ([self.ack isEqualToString:@"data"])
        {
            pIdL = [pIdL stringByAppendingString:@"+"];
        }
    }
    
    // Do not write pid for acknowledgements
    if ([type intValue] != 6) {
        [encoded addObject:pIdL];
    }
    
    // Add the end point for the namespace to be used, as long as it is not
    // an ACK, heartbeat, or disconnect packet
    if ([type intValue] != 6 && [type intValue] != 2 && [type intValue] != 0) {
        [encoded addObject:endpoint];
    }
    else {
        [encoded addObject:@""];
    }
    
    if (data != nil)
    {
        NSString *ackpId = @"";
        // This is an acknowledgement packet, so, prepend the ack pid to the data
        if ([type intValue] == 6)
        {
            if( !([self isKindOfClass:[SocketIOPacketV10x class]]) )
                ackpId = [NSString stringWithFormat:@":%@%@", pIdL, @"+"];
        }
        [encoded addObject:[NSString stringWithFormat:@"%@%@", ackpId, data]];
    }
    
    return [encoded componentsJoinedByString:_separator];
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

+ (SocketIOPacket *) createPacketWithType:(NSString *)type
                              version:(SocketIOVersion) version
{
    switch (version) {
        case V09x:
            return [[SocketIOPacket alloc] initWithType:type];
            break;
        case V10x:
            return [[SocketIOPacketV10x alloc] initWithType:type];
            break;
    }
}

+ (SocketIOPacket *) createPacketWithTypeIndex:(int) type
                              version:(SocketIOVersion) version
{
    switch (version) {
        case V09x:
            return [[SocketIOPacket alloc] initWithTypeIndex:type];
            break;
        case V10x:
            return [[SocketIOPacketV10x alloc] initWithTypeIndex:type];
            break;
    }
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

@implementation SocketIOPacketV10x

- (id) init
{
    self = [super init];
    
    _separator = @"";
    _types = [NSArray arrayWithObjects: @"disconnected",
              @"connected",
              @"heartbeat",
              @"pong",
              @"message",
              @"upgrade",
              @"noop",
              nil];
    _typesMessage = [NSArray arrayWithObjects: @"connect",
                     @"disconnect",
                     @"event",
                     @"ack",
                     @"error",
                     @"binarevent",
                     @"binaryack",
                     nil];
    return self;
}

- (NSNumber *) typeAsNumber
{
    NSNumber *num = 0;
    NSUInteger index;
    if(_typesMessage != nil && (index = [_typesMessage indexOfObject:self.type]) != NSNotFound)
    {
        //it's a message type
        index = [_typesMessage indexOfObject:self.type];
        num = @([num integerValue] + 40);
    }
    else
    {
        index = [_types indexOfObject:self.type];
    }
    num = @([num integerValue] + [[NSNumber numberWithUnsignedInteger:index] integerValue]);
    return num;
}

- (void) dealloc
{
    _typesMessage = nil;
    
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

