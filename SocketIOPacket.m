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
    return [self init:V09x];
}

- (id) init:(SocketIOVersion) version
{
    self = [super init];
    if (self)
    {
        switch (version) {
            case V09x:
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
                _typesMessage = nil;
                break;
                
            case V10x:
            {
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
            }   break;
        }
    }
    return self;
}

- (id) initWithType:(NSString *)packetType
{
    return [self initWithType:packetType using:V09x];
}

- (id) initWithTypeIndex:(int)index
{
    return [self initWithTypeIndex:index using:V09x];
}

- (id) initWithType:(NSString *)packetType
              using:(SocketIOVersion) version
{
    self = [self init:version];
    if (self) {
        self.type = packetType;
    }
    return self;
}

- (id) initWithTypeIndex:(int)index
                   using:(SocketIOVersion) version
{
    self = [self init:version];
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
    return [self toString:V09x];
}

- (NSString *) toString:(SocketIOVersion) version
{
    NSMutableArray *encoded = [NSMutableArray arrayWithObject:[self typeAsNumber]];
    //if([type isEqualToString:@"event"] && version == V10x)
    //    [encoded addObject:@"2"];
    
    NSString *pIdL = self.pId != nil ? self.pId : @"";
    if ([self.ack isEqualToString:@"data"])
    {
        pIdL = [pIdL stringByAppendingString:@"+"];
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
            ackpId = [NSString stringWithFormat:@":%@%@", pIdL, @"+"];
        }
        
        if(version ==V10x)
        {
            
        }
        [encoded addObject:[NSString stringWithFormat:@"%@%@", ackpId, data]];
    }
    NSString *separator = @"";
    if(version == V09x)
        separator = @":";
    return [encoded componentsJoinedByString:separator];
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
        num = [NSNumber numberWithUnsignedInteger:index];
    }
    num = @([num integerValue] + [[NSNumber numberWithUnsignedInteger:index] integerValue]);    
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

