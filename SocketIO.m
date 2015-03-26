//
//  SocketIO.m
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

#import "SocketIO.h"
#import "SocketIOPacket.h"
#import "SocketIOJSONSerialization.h"

#ifdef DEBUG
#define DEBUG_LOGS 1
#define DEBUG_CERTIFICATE 1
#else
#define DEBUG_LOGS 0
#define DEBUG_CERTIFICATE 0
#endif

#if DEBUG_LOGS
#define DEBUGLOG(...) NSLog(__VA_ARGS__)
#else
#define DEBUGLOG(...)
#endif

static NSString* kResourceName = @"socket.io";
static NSString* kTransportPolling = @"polling";
static NSString* kTransportWebsocket = @"websocket";
static NSString* kHandshakeURL = @"%@://%@%@/%@/1/?EIO=2&transport=%@&t=%.0f%@";
static NSString* kForceDisconnectURL = @"%@://%@%@/%@/1/xhr-polling/%@?disconnect";

float const defaultConnectionTimeout = 10.0f;

NSString* const SocketIOError     = @"SocketIOError";
NSString* const SocketIOException = @"SocketIOException";

# pragma mark -
# pragma mark SocketIO's private interface

@interface SocketIO (Private)

- (NSArray*) arrayOfCaptureComponentsMatchedByRegex:(NSString*)regex;

- (void) setTimeout;
- (void) onTimeout;

- (void) sendHeartbeat;
- (void) onConnect:(SocketIOPacket *)packet;
- (void) onDisconnect:(NSError *)error;
- (void) sendDisconnect;
- (void) send:(SocketIOPacket *)packet;

- (NSString *) addAcknowledge:(SocketIOCallback)function;
- (void) removeAcknowledgeForKey:(NSString *)key;
- (NSMutableArray*) getMatchesFrom:(NSString*)data with:(NSString*)regex;

@end

# pragma mark -
# pragma mark SocketIO implementation

@implementation SocketIO

@synthesize isConnected = _isConnected, 
            isConnecting = _isConnecting, 
            useSecure = _useSecure,
            cookies = _cookies,
            delegate = _delegate,
            heartbeatTimeout = _heartbeatTimeout,
            returnAllDataFromAck = _returnAllDataFromAck;

- (id) initWithDelegate:(id<SocketIODelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _queue = [[NSMutableArray alloc] init];
        _ackCount = 0;
        _acks = [[NSMutableDictionary alloc] init];
        _returnAllDataFromAck = NO;
    }
    return self;
}

- (void) connectToHost:(NSString *)host onPort:(NSInteger)port
{
    [self connectToHost:host onPort:port withParams:nil withNamespace:@"" withConnectionTimeout:defaultConnectionTimeout];
}

- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params
{
    [self connectToHost:host onPort:port withParams:params withNamespace:@"" withConnectionTimeout:defaultConnectionTimeout];
}

- (void) connectToHost:(NSString *)host
                onPort:(NSInteger)port
            withParams:(NSDictionary *)params
         withNamespace:(NSString *)endpoint
{
    [self connectToHost:host onPort:port withParams:params withNamespace:endpoint withConnectionTimeout:defaultConnectionTimeout];
}

- (void) connectToHost:(NSString *)host
                onPort:(NSInteger)port
            withParams:(NSDictionary *)params
         withNamespace:(NSString *)endpoint
 withConnectionTimeout:(NSTimeInterval)connectionTimeout
{
    if (!_isConnected && !_isConnecting) {
        _isConnecting = YES;
        
        _host = host;
        _port = port;
        _params = params;
        _endpoint = [endpoint copy];
        
        // create a query parameters string
        NSMutableString *query = [[NSMutableString alloc] initWithString:@""];
        [params enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL *stop) {
            [query appendFormat:@"&%@=%@", key, value];
        }];
        
        // do handshake via HTTP request
        NSString *protocol = _useSecure ? @"https" : @"http";
        NSString *port = _port ? [NSString stringWithFormat:@":%ld", (long)_port] : @"";
        NSTimeInterval time = [[NSDate date] timeIntervalSince1970] * 1000;
        NSString *handshakeUrl = [NSString stringWithFormat:kHandshakeURL, protocol, _host, port, kResourceName,kTransportPolling, time, query];
        //@"%@://%@%@/%@/1/?t=%.0f%@";
        //http://<host><port>/socket.io/1/?t=<time>f<query>
        
        DEBUGLOG(@"Connecting to socket with URL: %@", handshakeUrl);
        query = nil;
        
        // make a request
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:handshakeUrl]
                                                 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
                                             timeoutInterval:connectionTimeout];
        
        if (_cookies != nil) {
            DEBUGLOG(@"Adding cookie(s): %@", [_cookies description]);
            NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
            [request setAllHTTPHeaderFields:headers];
        }
        
        [request setHTTPShouldHandleCookies:YES];
        
        _handshake = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_handshake scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_handshake start];
        
        if (_handshake) {
            _httpRequestData = [NSMutableData data];
        }
        else {
            // connection failed
            [self connection:_handshake didFailWithError:nil];
        }
    }
}

- (void) disconnect
{
    if (_isConnected) {
        [self sendDisconnect];
    }
    else if (_isConnecting) {
        [_handshake cancel];
        [self onDisconnect: nil];
    }
}

- (void) disconnectForced
{
    NSString *protocol = [self useSecure] ? @"https" : @"http";
    NSString *port = _port ? [NSString stringWithFormat:@":%ld", (long)_port] : @"";
    NSString *urlString = [NSString stringWithFormat:kForceDisconnectURL, protocol, _host, port, kResourceName, _sid];
    NSURL *url = [NSURL URLWithString:urlString];
    DEBUGLOG(@"Force disconnect at: %@", urlString);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSError *error = nil;
    NSHTTPURLResponse *response = nil;
    
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error || [response statusCode] != 200) {
        DEBUGLOG(@"Error during disconnect: %@", error);
    }
    
    [self onDisconnect:error];
}

- (void) sendMessage:(NSString *)data
{
    [self sendMessage:data withAcknowledge:nil];
}

- (void) sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function
{
    switch (_version)
    {
        case V09x:
        {
            SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"message"];
            packet.data = data;
            packet.pId = [self addAcknowledge:function];
            [self send:packet];
        }break;
        case V10x:
        {
            [self sendEvent:@"message" withData:data];
        }break;
    }
}

- (void) sendJSON:(NSDictionary *)data
{
    [self sendJSON:data withAcknowledge:nil];
}

- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function
{
    switch (_version)
    {
        case V09x:
        {
            SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"json"];
            packet.data = [SocketIOJSONSerialization JSONStringFromObject:data error:nil];
            packet.pId = [self addAcknowledge:function];
            [self send:packet];
        }break;
        case V10x:
        {
            [self sendEvent:@"message" withData:data andAcknowledge:function];
        }break;
    }
}

- (void) sendEvent:(NSString *)eventName withData:(id)data
{
    [self sendEvent:eventName withData:data andAcknowledge:nil];
}

- (void) sendEvent:(NSString *)eventName withData:(id)data andAcknowledge:(SocketIOCallback)function
{
    SocketIOPacket *packet ;
    switch (_version) {
        case V10x:
        {
            packet = [[SocketIOPacketV10x alloc] initWithType:@"event"];
            NSMutableArray *array = [NSMutableArray arrayWithObjects:eventName, nil];
            
            // do not require arguments
            if (data != nil)
            {
                [array addObject:data];
            }
            packet.data = [SocketIOJSONSerialization JSONStringFromObject:array error:nil];
            //packet.data = [packet.data stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        }break;
            
        case V09x:
        {
            packet = [[SocketIOPacket alloc] initWithType:@"event"];
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObject:eventName forKey:@"name"];
            
            // do not require arguments
            if (data != nil)
            {
                [dict setObject:[NSArray arrayWithObject:data] forKey:@"args"];
            }
            packet.data = [SocketIOJSONSerialization JSONStringFromObject:dict error:nil];
        }break;
    }
    
    packet.name =eventName;
    packet.pId = [self addAcknowledge:function];
    if (function) {
        packet.ack = @"data";
    }
    NSLog(@"%@", packet.data);
    [self send:packet];
}

- (void) sendAcknowledgement:(NSString *)pId withArgs:(NSArray *)data 
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"ack"];
    packet.data = [SocketIOJSONSerialization JSONStringFromObject:data error:nil];
    packet.pId = pId;
    packet.ack = @"data";

    [self send:packet];
}

- (void) setResourceName:(NSString *)name
{
    kResourceName = [name copy];
}

# pragma mark -
# pragma mark private methods

- (void) sendDisconnect
{
    SocketIOPacket *packet = [SocketIOPacket createPacketWithType:@"disconnect" version:_version];
    [self send:packet];
    [self onDisconnect:nil];
}

- (void) sendConnect
{
    SocketIOPacket *packet = [SocketIOPacket createPacketWithType:@"connect" version:_version];
    [self send:packet];
}

- (void) sendHeartbeat
{
    SocketIOPacket *packet = [SocketIOPacket createPacketWithType:@"heartbeat" version:_version];
    [self send:packet];
}

- (void) send:(SocketIOPacket *)packet
{
    if (![self isConnected] && ![self isConnecting]) {
        DEBUGLOG(@"Already disconnected!");
        return;
    }
    DEBUGLOG(@"Prepare to send()");
    packet.endpoint = _endpoint;
    
    NSString *req = [packet toString];
    if (![_transport isReady]) {
        DEBUGLOG(@"queue >>> %@", req);
        [_queue addObject:packet];
    } 
    else {
        DEBUGLOG(@"send() >>> %@", req);
        [_transport send:req];
        
        if ([_delegate respondsToSelector:@selector(socketIO:didSendMessage:)]) {
            [_delegate socketIO:self didSendMessage:packet];
        }
    }
}

- (void) doQueue 
{
    DEBUGLOG(@"doQueue() >> %lu", (unsigned long)[_queue count]);
    
    // TODO send all packets at once ... not as seperate packets
    while ([_queue count] > 0) {
        SocketIOPacket *packet = [_queue objectAtIndex:0];
        [self send:packet];
        [_queue removeObject:packet];
    }
}

- (void) onConnect:(SocketIOPacket *)packet
{
    DEBUGLOG(@"onConnect()");
    
    _isConnected = YES;

    // Send the connected packet so the server knows what it's dealing with.
    // Only required when endpoint/namespace is present
    if ([_endpoint length] > 0) {
        // Make sure the packet we received has an endpoint, otherwise send it again
        if (![packet.endpoint isEqualToString:_endpoint]) {
            DEBUGLOG(@"onConnect() >> End points do not match, resending connect packet");
            [self sendConnect];
            return;
        }
    }
    
    _isConnecting = NO;
    
    if ([_delegate respondsToSelector:@selector(socketIODidConnect:)]) {
        [_delegate socketIODidConnect:self];
    }
    
    // send any queued packets
    [self doQueue];
    [self setTimeout];
}

# pragma mark -
# pragma mark Acknowledge methods

- (NSString *) addAcknowledge:(SocketIOCallback)function
{
    if (function) {
        ++_ackCount;
        NSString *ac = [NSString stringWithFormat:@"%ld", (long)_ackCount];
        [_acks setObject:[function copy] forKey:ac];
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
    if (_timeout) {
        dispatch_source_cancel(_timeout);
        _timeout = NULL;
    }
    
    DEBUGLOG(@"Timed out waiting for heartbeat.");
    [self onDisconnect:[NSError errorWithDomain:SocketIOError
                                           code:SocketIOHeartbeatTimeout
                                       userInfo:nil]];
}

- (void) setTimeout 
{
    //DEBUGLOG(@"start/reset timeout");
    if (_timeout) {
        dispatch_source_cancel(_timeout);
        _timeout = NULL;
    }
    
    _timeout = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                      0,
                                      0,
                                      dispatch_get_main_queue());
    
    dispatch_source_set_timer(_timeout,
                              dispatch_time(DISPATCH_TIME_NOW, _connectionTimeout * NSEC_PER_SEC),
                              0,
                              0);
    
    __weak SocketIO *weakSelf = self;
    
    dispatch_source_set_event_handler(_timeout, ^{
        [weakSelf onTimeout];
    });
    
    dispatch_resume(_timeout);    
}

- (void) onHeartBeat
{
    [self sendHeartbeat];
}

- (void) setHeartBeat
{
    DEBUGLOG(@"start/reset Heartbeat");
    if (_heartbeat)
    {
        dispatch_source_cancel(_heartbeat);
        _heartbeat = NULL;
    }
    
    _heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                      0,
                                      0,
                                      dispatch_get_main_queue());
    
    dispatch_source_set_timer(_heartbeat,
                              dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_NOW),
                              _heartbeatTimeout * NSEC_PER_SEC,
                              0);
    
    __weak SocketIO *weakSelf = self;
    
    dispatch_source_set_event_handler(_heartbeat, ^{
        [weakSelf onHeartBeat];
    });
    
    dispatch_resume(_heartbeat);
}


# pragma mark -
# pragma mark Regex helper method
- (NSMutableArray*) getMatchesFrom:(NSString*)data with:(NSString*)regex
{
    NSRegularExpression *nsregexTest = [NSRegularExpression regularExpressionWithPattern:regex options:0 error:nil];
    NSArray *nsmatchesTest = [nsregexTest matchesInString:data options:0 range:NSMakeRange(0, [data length])];
    NSMutableArray *arr = [NSMutableArray array];
    
    for (NSTextCheckingResult *nsmatchTest in nsmatchesTest) {
        NSMutableArray *localMatch = [NSMutableArray array];
        for (NSUInteger i = 0, l = [nsmatchTest numberOfRanges]; i < l; i++) {
            NSRange range = [nsmatchTest rangeAtIndex:i];
            NSString *nsmatchStr = nil;
            if (range.location != NSNotFound && NSMaxRange(range) <= [data length]) {
                nsmatchStr = [data substringWithRange:[nsmatchTest rangeAtIndex:i]];
            } 
            else {
                nsmatchStr = @"";
            }
            [localMatch addObject:nsmatchStr];
        }
        [arr addObject:localMatch];
    }
    
    return arr;
}


#pragma mark -
#pragma mark SocketIOTransport callbacks

- (void) onData:(NSString *)data
{
    DEBUGLOG(@"onData %@", data);
    
    // data arrived -> reset timeout
    [self setTimeout];
    
    // check if data is valid (from socket.io.js)
    switch(_version)
    {
        case V09x:
        {
            NSString *regex = @"^([^:]+):([0-9]+)?(\\+)?:([^:]+)?:?(.*)?$";
            NSString *regexPieces = @"^([0-9]+)(\\+)?(.*)";
            
            // create regex result
            NSMutableArray *test = [self getMatchesFrom:data with:regex];
            
            // valid data-string arrived
            if ([test count] > 0) {
                NSArray *result = [test objectAtIndex:0];
                
                int idx = [[result objectAtIndex:1] intValue];
                SocketIOPacket *packet = [[SocketIOPacket alloc] initWithTypeIndex:idx];
                
                packet.pId = [result objectAtIndex:2];
                
                packet.ack = [result objectAtIndex:3];
                packet.endpoint = [result objectAtIndex:4];
                packet.data = [result objectAtIndex:5];
                
                //
                switch (idx)
                {
                    case 0: {
                        DEBUGLOG(@"disconnect");
                        [self onDisconnect:[NSError errorWithDomain:SocketIOError
                                                               code:SocketIOServerRespondedWithDisconnect
                                                           userInfo:nil]];
                        break;
                    }
                    case 1: {
                        DEBUGLOG(@"connected");
                        // from socket.io.js ... not sure when data will contain sth?!
                        // packet.qs = data || '';
                        [self onConnect:packet];
                        break;
                    }
                    case 2: {
                        DEBUGLOG(@"heartbeat");
                        [self sendHeartbeat];
                        break;
                    }
                    case 3: {
                        DEBUGLOG(@"message");
                        if (packet.data && ![packet.data isEqualToString:@""]) {
                            if ([_delegate respondsToSelector:@selector(socketIO:didReceiveMessage:)]) {
                                [_delegate socketIO:self didReceiveMessage:packet];
                            }
                        }
                        break;
                    }
                    case 4: {
                        DEBUGLOG(@"json");
                        if (packet.data && ![packet.data isEqualToString:@""]) {
                            if ([_delegate respondsToSelector:@selector(socketIO:didReceiveJSON:)]) {
                                [_delegate socketIO:self didReceiveJSON:packet];
                            }
                        }
                        break;
                    }
                    case 5: {
                        DEBUGLOG(@"event");
                        if (packet.data && ![packet.data isEqualToString:@""]) {
                            NSDictionary *json = [packet dataAsJSON];
                            packet.name = [json objectForKey:@"name"];
                            packet.args = [json objectForKey:@"args"];
                            if ([_delegate respondsToSelector:@selector(socketIO:didReceiveEvent:)]) {
                                [_delegate socketIO:self didReceiveEvent:packet];
                            }
                        }
                        break;
                    }
                    case 6: {
                        DEBUGLOG(@"ack");
                        
                        // create regex result
                        NSMutableArray *pieces = [self getMatchesFrom:packet.data with:regexPieces];
                        
                        if ([pieces count] > 0) {
                            NSArray *piece = [pieces objectAtIndex:0];
                            int ackId = [[piece objectAtIndex:1] intValue];
                            DEBUGLOG(@"ack id found: %d", ackId);
                            
                            NSString *argsStr = [piece objectAtIndex:3];
                            id argsData = nil;
                            if (argsStr && ![argsStr isEqualToString:@""]) {
                                argsData = [SocketIOJSONSerialization objectFromJSONData:[argsStr dataUsingEncoding:NSUTF8StringEncoding] error:nil];
                                // either send complete response or only the first arg to callback
                                if (!_returnAllDataFromAck && [argsData count] > 0) {
                                    argsData = [argsData objectAtIndex:0];
                                }
                            }
                            
                            // get selector for ackId
                            NSString *key = [NSString stringWithFormat:@"%d", ackId];
                            SocketIOCallback callbackFunction = [_acks objectForKey:key];
                            if (callbackFunction != nil) {
                                callbackFunction(argsData);
                                [self removeAcknowledgeForKey:key];
                            }
                        }
                        
                        break;
                    }
                    case 7: {
                        DEBUGLOG(@"error");
                        break;
                    }
                    case 8: {
                        DEBUGLOG(@"noop");
                        break;
                    }
                    default: {
                        DEBUGLOG(@"command not found or not yet supported");
                        break;
                    }
                }
                
                packet = nil;
            }
            else {
                DEBUGLOG(@"ERROR: data that has arrived wasn't valid");
            }
        }break;
        case V10x:
        {
            //42<NAMESPACE>["<event>","{}"]
            //GET VERSION
            NSUInteger control = [[NSNumber numberWithUnsignedChar:[data characterAtIndex:0]] integerValue]
                                    -[[NSNumber numberWithUnsignedChar:'0'] integerValue];
            
            NSUInteger ack = 0;
            
            SocketIOPacket *packet = [[SocketIOPacketV10x alloc] initWithTypeIndex:control];            
            
            //dont care about the endpoint here
            packet.endpoint = @"";
            
            //GET GETDATA
            if(data.length>1)
                packet.data = [data substringFromIndex:1];
            else
                packet.data = @"";
            
            switch (control)
            {
                case 0:
                    //??
                    break;
                case 1:
                    //??
                    break;
                case 2:
                
                    //Ping->Pong
                    [self sendMessage:[NSString stringWithFormat:@"3:%@", data]];
                    break;
                case 3:
                    //Pong
                    if([data isEqualToString:@"probe"])
                        [self sendMessage:@"5"];
                    break;
                case 4:
                {
                    //Message
                    control = [[NSNumber numberWithUnsignedChar:[packet.data characterAtIndex:0]] integerValue]
                                                    -[[NSNumber numberWithUnsignedChar:'0'] integerValue];
                    if([packet.data length] > 1){
                        NSRange range = NSMakeRange(1, [packet.data rangeOfString:@"["].location-1);
                        NSString *ackStr = [packet.data substringWithRange:range];
                        ack = [ackStr integerValue];
                    }
                    //GET ENDPOINT
                    NSUInteger rendpoint = [packet.data rangeOfString:@"["].location;
                    if(rendpoint == NSNotFound)
                        packet.endpoint = packet.data;
                    else
                        packet.endpoint = [packet.data substringToIndex:rendpoint];
                    
                    //GET GETDATA
                    if(rendpoint == NSNotFound)
                        packet.data = @"";
                    else
                        packet.data = [packet.data substringFromIndex:rendpoint];
                    
                    switch (control) {
                        case 0:
                            //Connected
                            [self onConnect:packet];
                            break;
                        case 1:
                            //Disconnected
                            [self onDisconnect:[NSError errorWithDomain:SocketIOError
                                                                   code:SocketIOServerRespondedWithDisconnect
                                                               userInfo:nil]];
                            break;
                        case 2:
                        {
                            //Event
                            if([packet.data characterAtIndex:0] == '[' && [packet.data characterAtIndex:packet.data.length-1] == ']')
                            {
                                NSData *utf8Data = [packet.data dataUsingEncoding:NSUTF8StringEncoding];
                                NSArray *parsedData = [SocketIOJSONSerialization objectFromJSONData:utf8Data error:nil];
                                DEBUGLOG(@"Event Type:%@",parsedData[0]);
                                packet.name = parsedData[0];
                                packet.args = [parsedData subarrayWithRange:NSMakeRange(1, parsedData.count-1)];
                                if([packet.name isEqualToString:@"message"])
                                {
                                    // data is specified as NSString, so rewrap it...
                                    packet.data = [SocketIOJSONSerialization JSONStringFromObject:packet.args[0] error:nil];
                                    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveMessage:)]) {
                                        [_delegate socketIO:self didReceiveMessage:packet];
                                    }
                                }
                                else
                                {
                                    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveEvent:)]) {
                                        [_delegate socketIO:self didReceiveEvent:packet];
                                    }
                                }
                                
                            }
                        }    break;
                        case 3:
                        {
                            
                            if (ack > 0) {
                                NSUInteger ackId = ack;
                                DEBUGLOG(@"ack id found: %d", (unsigned int)ackId);
                                
                                NSString *argsStr = [packet.data substringFromIndex:1 ];
                                argsStr = [argsStr substringToIndex:argsStr.length-1];
                                id argsData = nil;
                                if (argsStr && ![argsStr isEqualToString:@""]) {
                                    argsData = [SocketIOJSONSerialization objectFromJSONData:[argsStr dataUsingEncoding:NSUTF8StringEncoding] error:nil];
                                    // either send complete response or only the first arg to callback
//                                    if (!_returnAllDataFromAck && [argsData count] > 0) {
//                                        argsData = [argsData objectAtIndex:0];
//                                    }
                                }
                                
                                // get selector for ackId
                                NSString *key = [NSString stringWithFormat:@"%d", (unsigned int)ackId];
                                SocketIOCallback callbackFunction = [_acks objectForKey:key];
                                if (callbackFunction != nil) {
                                    callbackFunction(argsData);
                                    [self removeAcknowledgeForKey:key];
                                }
                            }

                        }    break;
                        case 4:
                            //Error
                            break;
                        case 5:
                            //Binary Event
                            break;
                        case 6:
                            //Binary Ack
                            break;
                            
                        default:
                            break;
                    }
                    
                }    break;
                case 5:
                    //Upgrade Required
                    break;
                case 6:
                    //Noop
                    break;
                    
                default:
                    break;
            }
            
        }break;
    }
    }

- (void) onDisconnect:(NSError *)error
{
    DEBUGLOG(@"onDisconnect()");
    BOOL wasConnected = _isConnected;
    BOOL wasConnecting = _isConnecting;
    
    _isConnected = NO;
    _isConnecting = NO;
    _sid = nil;
    
    [_queue removeAllObjects];
    
    // Kill the heartbeat timer
    if (_heartbeat) {
        dispatch_source_cancel(_heartbeat);
        _heartbeat = NULL;
    }
    if (_timeout) {
        dispatch_source_cancel(_timeout);
        _timeout = NULL;
    }
    
    // Disconnect the websocket, just in case
    if (_transport != nil) {
        // clear websocket's delegate - otherwise crashes
        _transport.delegate = nil;
        [_transport close];
    }
    
    if ((wasConnected || wasConnecting)) {
        if ([_delegate respondsToSelector:@selector(socketIODidDisconnect:disconnectedWithError:)]) {
            [_delegate socketIODidDisconnect:self disconnectedWithError:error];
        }
    }
}

- (void) onError:(NSError *)error
{
    if ([_delegate respondsToSelector:@selector(socketIO:onError:)]) {
        [_delegate socketIO:self onError:error];
    }
}


# pragma mark -
# pragma mark Handshake callbacks (NSURLConnectionDataDelegate)
- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response 
{
    // check for server status code (http://gigliwood.com/weblog/Cocoa/Q__When_is_an_conne.html)
    if ([response respondsToSelector:@selector(statusCode)]) {
        NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
        DEBUGLOG(@"didReceiveResponse() %i", (int)statusCode);
        
        if (statusCode >= 400) {
            // stop connecting; no more delegate messages
            [connection cancel];
            
            NSString *error = [NSString stringWithFormat:NSLocalizedString(@"Server returned status code %d", @""), statusCode];
            NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:error forKey:NSLocalizedDescriptionKey];
            NSError *statusError = [NSError errorWithDomain:SocketIOError
                                                       code:statusCode
                                                   userInfo:errorInfo];
            // call error callback manually
            [self connection:connection didFailWithError:statusError];
        }
    }
    
    [_httpRequestData setLength:0];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{
    [_httpRequestData appendData:data]; 
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
    NSLog(@"ERROR: handshake failed ... %@", [error localizedDescription]);
    
    int errorCode = [error code] == 403 ? SocketIOUnauthorized : SocketIOHandshakeFailed;
    
    _isConnected = NO;
    _isConnecting = NO;
    
    if ([_delegate respondsToSelector:@selector(socketIO:onError:)]) {
        NSMutableDictionary *errorInfo = [[NSDictionary dictionaryWithObject:error
                                                                      forKey:NSUnderlyingErrorKey] mutableCopy];
        
        NSError *err = [NSError errorWithDomain:SocketIOError
                                           code:errorCode
                                       userInfo:errorInfo];
        
        [_delegate socketIO:self onError:err];
    }
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection 
{ 	
 	NSString *responseString = [[NSString alloc] initWithData:_httpRequestData encoding:NSASCIIStringEncoding];

    DEBUGLOG(@"connectionDidFinishLoading()");
    NSString *responseV09Regex = @"([^:]+):([^:]+):([^:]+):([^:]+)";
    NSPredicate *version09predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", responseV09Regex];

    BOOL connectionFailed = false;
    NSError* error;
    
    if([version09predicate evaluateWithObject:responseString])
    {
        DEBUGLOG(@"Response %@", responseString);
        //version 09x
        _version = V09x;
        NSArray *data = [responseString componentsSeparatedByString:@":"];
        // should be SID : heartbeat timeout : connection timeout : supported transports in V09x
        // should be ...0{"sid":"<sid>","upgrades":[<transports>,...],"pingInterval":<timeHeartbeat>,"pingTimeout":<timeOut>} in V10x
        
        // check each returned value (thanks for the input https://github.com/taiyangc)
        
        _sid = [data objectAtIndex:0];
        if ([_sid length] < 1 || [data count] < 4) {
            // did not receive valid data, possibly missing a useSecure?
            connectionFailed = true;
        }
        else
        {
            // check SID
            DEBUGLOG(@"sid: %@", _sid);
            NSString *regex = @"[^0-9]";
            NSPredicate *regexTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
            if ([_sid rangeOfString:@"error"].location != NSNotFound || [regexTest evaluateWithObject:_sid])
            {
                [self connectToHost:_host onPort:_port withParams:_params withNamespace:_endpoint];
                return;
            }
            
            // check heartbeat timeout
            _heartbeatTimeout = [[data objectAtIndex:1] floatValue];
            if (_heartbeatTimeout == 0.0) {
                // couldn't find float value -> fail
                connectionFailed = true;
            }
            else {
                // add small buffer of 7sec (magic xD) otherwise heartbeat will be too late and connection is closed
                _heartbeatTimeout += 7.0;
            }
            
            _connectionTimeout = [[data objectAtIndex:2] floatValue];
            if (_connectionTimeout == 0.0) {
                // couldn't find float value -> fail
                connectionFailed = true;
            }
            else {
                // add small buffer of 7sec (magic xD) otherwise connection will be too late and connection is closed
                _connectionTimeout += 7.0;
            }
            DEBUGLOG(@"heartbeatTimeout: %f", _heartbeatTimeout);
            
            // index 2 => connection timeout
            
            // get transports
            NSString *t = [data objectAtIndex:3];
            NSArray *transports = [t componentsSeparatedByString:@","];
            DEBUGLOG(@"transports: %@", transports);
            
            static Class webSocketTransportClass;
            static Class xhrTransportClass;
            
            if (webSocketTransportClass == nil) {
                webSocketTransportClass = NSClassFromString(@"SocketIOTransportWebsocket");
            }
            if (xhrTransportClass == nil) {
                xhrTransportClass = NSClassFromString(@"SocketIOTransportXHR");
            }
            
            if (webSocketTransportClass != nil && [transports indexOfObject:@"websocket"] != NSNotFound) {
                DEBUGLOG(@"websocket supported -> using it now");
                _transport = [[webSocketTransportClass alloc] initWithDelegate:self];
            }
            else if (xhrTransportClass != nil && [transports indexOfObject:@"xhr-polling"] != NSNotFound) {
                DEBUGLOG(@"xhr polling supported -> using it now");
                _transport = [[xhrTransportClass alloc] initWithDelegate:self];
            }
            else {
                DEBUGLOG(@"no transport found that is supported :( -> fail");
                connectionFailed = true;
                error = [NSError errorWithDomain:SocketIOError
                                            code:SocketIOTransportsNotSupported
                                        userInfo:nil];
            }
        }
    }
    else
    {
        DEBUGLOG(@"VERSION 10x");
        _version = V10x;
        //...0{"sid":"<sid>","upgrades":[<transports>,...],"pingInterval":<timeHeartbeat>,"pingTimeout":<timeOut>}
        if([responseString rangeOfString:@"{"].location != NSNotFound)
            responseString = [responseString substringFromIndex:[responseString rangeOfString:@"{"].location];
        DEBUGLOG(@"Response %@", responseString);
        connectionFailed = true;
        NSData *utf8Data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [SocketIOJSONSerialization objectFromJSONData:utf8Data error:nil];
        if([json valueForKey:@"sid"] != nil
           && [json valueForKey:@"upgrades"] != nil
           && [json valueForKey:@"pingInterval"] != nil
           && [json valueForKey:@"pingTimeout"] != nil)
        {
            connectionFailed = false;
            _sid = [json objectForKey:@"sid"];
            _heartbeatTimeout = [[json objectForKey:@"pingInterval"] floatValue] / 1000;
            _connectionTimeout = [[json objectForKey:@"pingTimeout"] floatValue] / 1000;

            
            NSArray *transports = [json objectForKey:@"upgrades"];
            static Class webSocketTransportClass;
            static Class xhrTransportClass;
            
            if (webSocketTransportClass == nil) {
                webSocketTransportClass = NSClassFromString(@"SocketIOTransportWebsocket");
            }
            if (xhrTransportClass == nil) {
                xhrTransportClass = NSClassFromString(@"SocketIOTransportXHR");
            }
            
            if (webSocketTransportClass != nil && [transports indexOfObject:@"websocket"] != NSNotFound) {
                DEBUGLOG(@"websocket supported -> using it now");
                _transport = [[webSocketTransportClass alloc] initWithDelegate:self];
            }
            else if (xhrTransportClass != nil && [transports indexOfObject:@"xhr-polling"] != NSNotFound) {
                DEBUGLOG(@"xhr polling supported -> using it now");
                _transport = [[xhrTransportClass alloc] initWithDelegate:self];
            }
            else {
                DEBUGLOG(@"no transport found that is supported :( -> fail");
                connectionFailed = true;
                error = [NSError errorWithDomain:SocketIOError
                                            code:SocketIOTransportsNotSupported
                                        userInfo:nil];
            }
        }
    }
    
    // if connection didn't return the values we need -> fail
    if (connectionFailed)
    {
        // error already set!?
        if (error == nil) {
            error = [NSError errorWithDomain:SocketIOError
                                        code:SocketIOServerRespondedWithInvalidConnectionData
                                    userInfo:nil];
        }

        if ([_delegate respondsToSelector:@selector(socketIO:onError:)]) {
            [_delegate socketIO:self onError:error];
        }
        
        // make sure to do call all cleanup code
        [self onDisconnect:error];
        
        return;
    }
    
    DEBUGLOG(@"Received All information:\n\tsid: %@\n\theartbeat: %f\n\tTransport: %@",_sid,_heartbeatTimeout,_transport);
    
    [_transport openUsing:_version];
    [self setHeartBeat];
}

#if DEBUG_CERTIFICATE

// to deal with self-signed certificates
- (BOOL) connection:(NSURLConnection *)connection
canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void) connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([challenge.protectionSpace.authenticationMethod
         isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        // we only trust our own domain
        if ([challenge.protectionSpace.host isEqualToString:_host]) {
            SecTrustRef trust = challenge.protectionSpace.serverTrust;
            NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];
            [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
        }
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}
#endif


# pragma mark -

- (void) dealloc
{
    [_handshake cancel];
    _handshake = nil;

    _host = nil;
    _sid = nil;
    _endpoint = nil;
    
    _transport.delegate = nil;
    _transport = nil;
    
    if (_timeout) {
        dispatch_source_cancel(_timeout);
        _timeout = NULL;
    }
    
    _queue = nil;
    _acks = nil;
}


@end
