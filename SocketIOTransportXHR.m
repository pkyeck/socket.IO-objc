//
//  SocketIOTransportXHR.m
//  v0.3.2 ARC
//
//  based on
//  socketio-cocoa https://github.com/fpotter/socketio-cocoa
//  by Fred Potter <fpotter@pieceable.com>
//
//  using
//  https://github.com/square/SocketRocket
//  https://github.com/stig/json-framework/
//
//  reusing some parts of
//  /socket.io/socket.io.js
//
//  Created by Philipp Kyeck http://beta-interactive.de
//
//  Updated by
//    samlown   https://github.com/samlown
//    kayleg    https://github.com/kayleg
//    taiyangc  https://github.com/taiyangc
//

#import "SocketIOTransportXHR.h"
#import "SocketIO.h"

#define DEBUG_LOGS 0

#if DEBUG_LOGS
#define DEBUGLOG(...) NSLog(__VA_ARGS__)
#else
#define DEBUGLOG(...)
#endif

static NSString* kInsecureXHRURL = @"http://%@/socket.io/1/xhr-polling/%@";
static NSString* kSecureXHRURL = @"https://%@/socket.io/1/xhr-polling/%@";
static NSString* kInsecureXHRPortURL = @"http://%@:%d/socket.io/1/xhr-polling/%@";
static NSString* kSecureXHRPortURL = @"https://%@:%d/socket.io/1/xhr-polling/%@";

@interface SocketIOTransportXHR (Private)
- (void) checkAndStartPoll;
- (void) poll:(NSString *)data;
- (void) poll:(NSString *)data retryNumber:(int)retry;
@end

@implementation SocketIOTransportXHR

@synthesize delegate;

- (id) initWithDelegate:(id<SocketIOTransportDelegate>)delegate_
{
    self = [super init];
    if (self) {
        self.delegate = delegate_;
        _data = [[NSMutableData alloc] init];
        _polls = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) open
{
    NSString *format;
    if (delegate.port) {
        format = delegate.useSecure ? kSecureXHRPortURL : kInsecureXHRPortURL;
        _url = [NSString stringWithFormat:format, delegate.host, delegate.port, delegate.sid];
    }
    else {
        format = delegate.useSecure ? kSecureXHRURL : kInsecureXHRURL;
        _url = [NSString stringWithFormat:format, delegate.host, delegate.sid];
    }
    DEBUGLOG(@"Opening XHR @ %@", _url);
    [self poll:nil];
}

- (void) close
{
    NSMutableDictionary *pollData;
    NSURLConnection *conn;
    for (NSString *key in _polls) {
        pollData = [_polls objectForKey:key];
        conn = [pollData objectForKey:@"connection"];
        [conn cancel];
    }
    [_polls removeAllObjects];
}

- (BOOL) isReady
{
    return YES;
}

- (void) send:(NSString *)request
{
    [self poll:request];
}


#pragma mark -
#pragma mark private methods

- (void) checkAndStartPoll
{
    BOOL restart = NO;
    // no polls currently running -> start one
    if ([_polls count] == 0) {
        restart = YES;
    }
    else {
        restart = YES;
        // look for polls w/o data -> if there, no need to restart
        for (NSString *key in _polls) {
            NSMutableDictionary *pollData = [_polls objectForKey:key];
            if ([pollData objectForKey:@"data"] == nil) {
                restart = NO;
                break;
            }
        }
    }
    
    if (restart) {
        [self poll:nil];
    }
}

- (void) poll:(NSString *)data
{
    [self poll:data retryNumber:0];
}

- (void) poll:(NSString *)data retryNumber:(int)retry
{
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    double unix = timeStamp * 1000;
    NSString *url = [_url stringByAppendingString:[NSString stringWithFormat:@"?t=%.0f", unix]];
    
    DEBUGLOG(@"---------------------------------------------------------------------------------------");
    DEBUGLOG(@"poll() %@", url);
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:[delegate heartbeatTimeout]];
    if (data != nil) {
        DEBUGLOG(@"poll() %@", data);
        [req setHTTPMethod:@"POST"];
        [req setValue:@"text/plain; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [req setHTTPBody:[data dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [req setValue:@"Keep-Alive" forHTTPHeaderField:@"Connection"];
    
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];

    // add pollData to polls dictionary
    NSMutableDictionary *pollData = [[NSMutableDictionary alloc] init];
    [pollData setObject:[NSNumber numberWithInt:retry] forKey:@"retries"];
    [pollData setObject:conn forKey:@"connection"];
    [pollData setValue:data forKey:@"data"];
    [_polls setObject:pollData forKey:conn.description];
    
    [conn start];
}


#pragma mark -
#pragma mark NSURLConnection delegate methods


- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_data setLength:0];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    DEBUGLOG(@"didReceiveData(): %@", data);
    [_data appendData:data];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    DEBUGLOG(@"didFailWithError: %@", [error localizedDescription]);
    
    // retry 3 times or throw error
    NSMutableDictionary *pollData = [_polls objectForKey:connection.description];
    NSString *data = [pollData objectForKey:@"data"];
    [_polls removeObjectForKey:connection.description];
    
    NSNumber *retries = [pollData objectForKey:@"retries"];
    if ([retries intValue] < 2) {
        [self poll:data retryNumber:[retries intValue] + 1];
    }
    else {
        NSMutableDictionary *errorInfo = [[NSMutableDictionary alloc] init];
        [errorInfo setValue:[error localizedDescription] forKey:@"reason"];
        [errorInfo setValue:data forKey:@"data"];
        
        if ([delegate respondsToSelector:@selector(onError:)]) {
            [delegate onError:[NSError errorWithDomain:SocketIOError
                                                  code:SocketIODataCouldNotBeSend
                                              userInfo:errorInfo]];
        }
    }
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSString *message = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
    DEBUGLOG(@"response: __%@__", message);
    
    if (![message isEqualToString:@"1"]) {
        [delegate onData:message];
    }
    
    // remove current connection from pool
    [_polls removeObjectForKey:connection.description];
    
    [self checkAndStartPoll];
}


@end
