//
//  SocketIO.m
//  v.01
//
//  based on 
//  socketio-cocoa https://github.com/fpotter/socketio-cocoa
//  by Fred Potter <fpotter@pieceable.com>
//
//  using
//  https://github.com/erichocean/cocoa-websocket
//  http://regexkit.sourceforge.net/RegexKitLite/
//  https://github.com/stig/json-framework/
//  http://allseeing-i.com/ASIHTTPRequest/
//
//  reusing some parts of
//  /socket.io/socket.io.js
//
//  Created by Philipp Kyeck http://beta_interactive.de
//

#import "SocketIO.h"

#import "ASIHTTPRequest.h"
#import "WebSocket.h"
#import "RegexKitLite.h"
#import "SBJson.h"

#define DEBUG_LOGS 1
#define HANDSHAKE_URL @"http://%@:%d/socket.io/1/?t=%d"
#define SOCKET_URL @"ws://%@:%d/socket.io/1/websocket/%@"


# pragma mark -
# pragma mark SocketIO's private interface

@interface SocketIO (FP_Private) <WebSocketDelegate>

- (void) log:(NSString *)message;

- (void) setTimeout;
- (void) onTimeout;

- (void) onConnect;
- (void) onDisconnect;

- (void) sendDisconnect;
- (void) sendHearbeat;
- (void) send:(SocketIOPacket *)packet;

- (NSString *) addAcknowledge:(SEL)function;
- (void) removeAcknowledgeForKey:(NSString *)key;

@end


# pragma mark -
# pragma mark SocketIO implementation

@implementation SocketIO

- (id) initWithDelegate:(id<SocketIODelegate>)delegate
{
    self = [super init];
    if (self)
    {
        _delegate = delegate;
        
        _queue = [[NSMutableArray alloc] init];
        
        _ackCount = 0;
        _acks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) connectToHost:(NSString *)host onPort:(NSInteger)port
{
    if (!_isConnected && !_isConnecting) 
    {
        _isConnecting = YES;
        
        _host = [host retain];
        _port = port;
        
        // do handshake via HTTP request
        NSString *s = [NSString stringWithFormat:HANDSHAKE_URL, _host, _port, rand()];
        NSURL *url = [NSURL URLWithString:s];
        
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void) disconnect
{
    [self sendDisconnect];
}

- (void) sendMessage:(NSString *)data
{
    [self sendMessage:data withAcknowledge:nil];
}

- (void) sendMessage:(NSString *)data withAcknowledge:(SEL)function
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"message"];
    packet.data = data;
    packet.pId = [self addAcknowledge:function];
    [self send:packet];
    [packet release];
}

- (void) sendJSON:(NSDictionary *)data
{
    [self sendJSON:data withAcknowledge:nil];
}

- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SEL)function
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"json"];
    packet.data = [data JSONRepresentation];
    packet.pId = [self addAcknowledge:function];
    [self send:packet];
    [packet release];
}

- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data
{
    [self sendEvent:eventName withData:data andAcknowledge:nil];
}

- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data andAcknowledge:(SEL)function
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObject:eventName forKey:@"name"];
    [dict setObject:data forKey:@"args"];
    
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"event"];
    packet.data = [dict JSONRepresentation];
    packet.pId = [self addAcknowledge:function];
    if (function) 
    {
        packet.ack = @"data";
    }
    [self send:packet];
    [packet release];
}


# pragma mark -
# pragma mark private methods

- (void) openSocket
{
    NSString *url = [NSString stringWithFormat:SOCKET_URL, _host, _port, _sid];
    
    [_webSocket release];
    _webSocket = nil;
    
    _webSocket = [[WebSocket alloc] initWithURLString:url delegate:self];
    [self log:[NSString stringWithFormat:@"Opening %@", url]];
    [_webSocket open];
}

- (void) sendDisconnect
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"disconnect"];
    [self send:packet];
    [packet release];
}

- (void) sendHeartbeat
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"heartbeat"];
    [self send:packet];
    [packet release];
}

- (void) send:(SocketIOPacket *)packet
{   
    [self log:@"send()"];
    NSNumber *type = [packet typeAsNumber];
    NSMutableArray *encoded = [NSMutableArray arrayWithObject:type];
    
    NSString *pId = packet.pId != nil ? packet.pId : @"";
    if ([packet.ack isEqualToString:@"data"])
    {
        pId = [pId stringByAppendingString:@"+"];
    }
    [encoded addObject:pId];
    
    // not yet sure what this is for
    NSString *endPoint = @"";
    [encoded addObject:endPoint];
    
    if (packet.data != nil)
    {
        [encoded addObject:packet.data];
    }
    
    NSString *req = [encoded componentsJoinedByString:@":"];
    if (!_isConnected) 
    {
        [self log:[NSString stringWithFormat:@"queue >>> %@", req]];
        [_queue addObject:packet];
    } 
    else 
    {
        [self log:[NSString stringWithFormat:@"send() >>> %@", req]];
        [_webSocket send:req];
        
        if ([_delegate respondsToSelector:@selector(socketIO:didSendMessage:)])
        {
            [_delegate socketIO:self didSendMessage:packet];
        }
    }
}



- (void) onData:(NSString *)data 
{
    [self log:[NSString stringWithFormat:@"onData %@", data]];
    
    // data arrived -> reset timeout
    [self setTimeout];
    
    // check if data is valid (from socket.io.js)
    NSString *regex = @"^([^:]+):([0-9]+)?(\\+)?:([^:]+)?:?(.*)?$";
    NSString *regexPieces = @"^([0-9]+)(\\+)?(.*)";
    NSArray *test = [data arrayOfCaptureComponentsMatchedByRegex:regex];
    
    // valid data-string arrived
    if ([test count] > 0) 
    {
        NSArray *result = [test objectAtIndex:0];
        
        int idx = [[result objectAtIndex:1] intValue];
        SocketIOPacket *packet = [[SocketIOPacket alloc] initWithTypeIndex:idx];
        
        packet.pId = [result objectAtIndex:2];
        
        // 3 => ack
        // 4 => endpoint (TODO)        
        packet.data = [result objectAtIndex:5];
        
        //
        switch (idx) 
        {
            case 0:
                [self log:@"disconnect"];
                [self onDisconnect];
                break;
                
            case 1:
                [self log:@"connect"];
                // from socket.io.js ... not sure when data will contain sth?! 
                // packet.qs = data || '';
                [self onConnect];
                break;
                
            case 2:
                [self log:@"heartbeat"];
                [self sendHeartbeat];
                break;
                
            case 3:
                [self log:@"message"];
                if (packet.data && ![packet.data isEqualToString:@""])
                {
                    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveMessage:)]) 
                    {
                        [_delegate socketIO:self didReceiveMessage:packet];
                    }
                }
                break;
                
            case 4:
                [self log:@"json"];
                if (packet.data && ![packet.data isEqualToString:@""])
                {
                    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveJSON:)]) 
                    {
                        [_delegate socketIO:self didReceiveJSON:packet];
                    }
                }
                break;
                
            case 5:
                [self log:@"event"];
                if (packet.data && ![packet.data isEqualToString:@""])
                { 
                    NSDictionary *json = [packet dataAsJSON];
                    packet.name = [json objectForKey:@"name"];
                    packet.args = [json objectForKey:@"args"];
                    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveEvent:)]) 
                    {
                        [_delegate socketIO:self didReceiveEvent:packet];
                    }
                }
                break;
                
            case 6:
                [self log:@"ack"];
                NSArray *pieces = [packet.data arrayOfCaptureComponentsMatchedByRegex:regexPieces];
                
                if ([pieces count] > 0) 
                {
                    NSArray *piece = [pieces objectAtIndex:0];
                    int ackId = [[piece objectAtIndex:1] intValue];
                    [self log:[NSString stringWithFormat:@"ack id found: %d", ackId]];
                    
                    NSString *argsStr = [piece objectAtIndex:3];
                    id argsData = nil;
                    if (argsStr && ![argsStr isEqualToString:@""])
                    {
                        argsData = [argsStr JSONValue];
                        if ([argsData count] > 0)
                        {
                            argsData = [argsData objectAtIndex:0];
                        }
                    }
                    
                    // get selector for ackId
                    NSString *key = [NSString stringWithFormat:@"%d", ackId];
                    SEL function = NSSelectorFromString([_acks objectForKey:key]);
                    if ([_delegate respondsToSelector:function])
                    {
                        if (argsData != nil)
                        {
                            [_delegate performSelector:function withObject:argsData];
                        }
                        else
                        {
                            [_delegate performSelector:function];
                        }
                        [self removeAcknowledgeForKey:key];
                    }
                }
                
                break;
                
            case 7:
                [self log:@"error"];
                break;
                
            case 8:
                [self log:@"noop"];
                break;
                
            default:
                [self log:@"command not found or not yet supported"];
                break;
        }
        
        [packet release];
    }
    else
    {
        [self log:@"ERROR: data that has arrived wasn't valid"];
    }
}


- (void) doQueue 
{
    [self log:[NSString stringWithFormat:@"doQueue() >> %d", [_queue count]]];
    
    // TODO send all packets at once ... not as seperate packets
    while ([_queue count] > 0) 
    {
        SocketIOPacket *packet = [_queue objectAtIndex:0];
        [self send:packet];
        [_queue removeObject:packet];
    }
}

- (void) onConnect
{
    [self log:@"onConnect()"];
    
    _isConnected = YES;
    _isConnecting = NO;
    
    if ([_delegate respondsToSelector:@selector(socketIODidConnect:)]) 
    {
        [_delegate socketIODidConnect:self];
    }
    
    // semd amy queued packets
    [self doQueue];
    
    [self setTimeout];
}

- (void) onDisconnect 
{
    [self log:@"onDisconnect()"];
    BOOL wasConnected = _isConnected;
    
    _isConnected = NO;
    _isConnecting = NO;
    _sid = nil;
    
    [_queue removeAllObjects];
    
    if (wasConnected && [_delegate respondsToSelector:@selector(socketIODidDisconnect:)]) 
    {
        [_delegate socketIODidDisconnect:self];
    }
}

# pragma mark -
# pragma mark Acknowledge methods

- (NSString *) addAcknowledge:(SEL)function
{
    if (function)
    {
        ++_ackCount;
        NSString *ac = [NSString stringWithFormat:@"%d", _ackCount];
        [_acks setObject:NSStringFromSelector(function) forKey:ac];
        return ac;
    }
    return nil;
}

- (void) removeAcknowledgeForKey:(NSString *)key
{
    [_acks removeObjectForKey:key];
}

# pragma mark -
# pragma mark Heartbeat methods

- (void) onTimeout 
{
    [self log:@"Timed out waiting for heartbeat."];
    [self onDisconnect];
}

- (void) setTimeout 
{
    [self log:@"setTimeout()"];
    if (_timeout != nil) 
    {   
        [_timeout invalidate];
        [_timeout release];
        _timeout = nil;
    }
    
    _timeout = [[NSTimer scheduledTimerWithTimeInterval:_heartbeatTimeout
                                                 target:self 
                                               selector:@selector(onTimeout) 
                                               userInfo:nil 
                                                repeats:NO] retain];
}


# pragma mark -
# pragma mark Handshake callbacks

- (void) requestFinished:(ASIHTTPRequest *)request
{
    NSString *responseString = [request responseString];
    [self log:[NSString stringWithFormat:@"requestFinished() %@", responseString]];
    NSArray *data = [responseString componentsSeparatedByString:@":"];
    
    _sid = [[data objectAtIndex:0] retain];
    [self log:[NSString stringWithFormat:@"sid: %@", _sid]];
    
    // add small buffer of 7sec (magic xD)
    _heartbeatTimeout = [[data objectAtIndex:1] floatValue] + 7.0;
    [self log:[NSString stringWithFormat:@"heartbeatTimeout: %f", _heartbeatTimeout]];
    
    // index 2 => connection timeout
    
    NSString *t = [data objectAtIndex:3];
    NSArray *transports = [t componentsSeparatedByString:@","];
    [self log:[NSString stringWithFormat:@"transports: %@", transports]];
    
    [self openSocket];
}

- (void) requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"ERROR: handshake failed ... %@", [error localizedDescription]);
}

# pragma mark -
# pragma mark WebSocket Delegate Methods

- (void) webSocketDidClose:(WebSocket*)webSocket 
{
    [self log:[NSString stringWithFormat:@"Connection closed."]];
    [self onDisconnect];
}

- (void) webSocketDidOpen:(WebSocket *)ws 
{
    [self log:[NSString stringWithFormat:@"Connection opened."]];
}

- (void) webSocket:(WebSocket *)ws didFailWithError:(NSError *)error 
{
    NSLog(@"ERROR: Connection failed with error ... %@", [error localizedDescription]);
}

- (void) webSocket:(WebSocket *)ws didReceiveMessage:(NSString*)message 
{
    [self onData:message];
}

# pragma mark -

- (void) log:(NSString *)message 
{
#if DEBUG_LOGS
    NSLog(@"%@", message);
#endif
}

- (void) dealloc
{
    [_host release];
    [_sid release];
    
    [_webSocket release];
    
    [_timeout invalidate];
    [_timeout release];
    
    [_queue release];
    [_acks release];
    
    [super dealloc];
}


@end


# pragma mark -
# pragma mark SocketIOPacket implementation

@implementation SocketIOPacket

@synthesize type, pId, name, ack, data, args;

- (id) init
{
    self = [super init];
    if (self)
    {
        _types = [[NSArray arrayWithObjects: @"disconnect", 
                   @"connect", 
                   @"heartbeat", 
                   @"message", 
                   @"json", 
                   @"event", 
                   @"ack", 
                   @"error", 
                   @"noop", 
                   nil] retain];
    }
    return self;
}

- (id) initWithType:(NSString *)packetType
{
    self = [self init];
    if (self)
    {
        self.type = packetType;
    }
    return self;
}

- (id) initWithTypeIndex:(int)index
{
    self = [self init];
    if (self)
    {
        self.type = [self typeForIndex:index];
    }
    return self;
}

- (id) dataAsJSON
{
    return [self.data JSONValue];
}

- (NSNumber *) typeAsNumber
{
    int index = [_types indexOfObject:self.type];
    NSNumber *num = [NSNumber numberWithInt:index];
    return num;
}

- (NSString *) typeForIndex:(int)index
{
    return [_types objectAtIndex:index];
}

- (void) dealloc
{
    [_types release];
    
    [type release];
    [pId release];
    [name release];
    [ack release];
    [data release];
    [args release];
    
    [super dealloc];
}

@end
