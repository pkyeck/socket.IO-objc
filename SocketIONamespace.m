//
//  SocketIONamespace.m
//
//  Created by jbaez https://github.com/jbaez on 04/07/2014.
//
//

#import "SocketIONamespace.h"
#import "SocketIOPacket.h"

@interface SocketIONamespace()

@property (nonatomic, strong) SocketIO *socket;
@property (nonatomic, strong) NSString *endpoint;

@end

@implementation SocketIONamespace

#pragma mark - initializers

+ (SocketIO *)sharedSocket
{
    static SocketIO *socket;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        socket = [[SocketIO alloc] init];
    });

    return socket;
}

+ (instancetype)namespaceWithEndpoint:(NSString *)endpoint
                             delegate:(id<SocketIODelegate>)delegate
{
    SocketIO *socket = [SocketIONamespace sharedSocket];

    SocketIONamespace *namespace = [[SocketIONamespace alloc] initWithSocket:socket
                                                                   namespace:endpoint
                                                                    delegate:delegate];

    return namespace;
}

+ (instancetype)namespaceWithEndpoint:(NSString *)endpoint
{
    SocketIO *socket = [SocketIONamespace sharedSocket];

    SocketIONamespace *namespace = [[SocketIONamespace alloc] initWithSocket:socket
                                                                   namespace:endpoint
                                                                    delegate:nil];

    return namespace;
}

/// Private initializer
- (instancetype)initWithSocket:(SocketIO *)socket
                     namespace:(NSString *)endpoint
                      delegate:(id<SocketIODelegate>)delegate
{
    self = [super init];
    if (self) {
        _socket = socket;
        _endpoint = endpoint;
        _delegate = delegate;

        [_socket addNamespaceDelegate:self];
    }
    return self;
}

#pragma mark - private methods

- (void)sendConnectPackage
{
    if([self.socket isConnected] && ![self.socket isConnecting]) {
        // socket already connected. Send connect package for new namespace
        [self.socket sendConnectForNamespace:self.endpoint];
    }
}

#pragma mark - SocketIOProtocol

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port
{
    if (![self.socket isConnected] && ![self.socket isConnecting]) {
        [self.socket connectToHost:host
                            onPort:port];
    } else {
        // socket already connected. Send connect package for new namespace
        [self sendConnectPackage];
    }
}

- (void)connectToHost:(NSString *)host
               onPort:(NSInteger)port
           withParams:(NSDictionary *)params
{
    if (![self.socket isConnected] && ![self.socket isConnecting]) {
        [self.socket connectToHost:host
                            onPort:port
                        withParams:params];
    } else {
        // socket already connected. Send connect package for new namespace
        [self sendConnectPackage];
    }
}

- (void)connectToHost:(NSString *)host
               onPort:(NSInteger)port
           withParams:(NSDictionary *)params
withConnectionTimeout:(NSTimeInterval)connectionTimeout
{
    if (![self.socket isConnected] && ![self.socket isConnecting]) {
        [self.socket connectToHost:host
                            onPort:port
                        withParams:params
             withConnectionTimeout:connectionTimeout];
    } else {
        // socket already connected. Send connect package for new namespace
        [self sendConnectPackage];
    }
}

- (void)sendMessage:(NSString *)data
{
    [self.socket sendMessage:data forNamespace:self.endpoint];
}

- (void)sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function
{
    [self.socket sendMessage:data forNamespace:self.endpoint withAcknowledge:function];
}

- (void)sendJSON:(NSDictionary *)data
{
    [self.socket sendJSON:data forNamespace:self.endpoint];
}

- (void)sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function
{
    [self.socket sendJSON:data forNamespace:self.endpoint withAcknowledge:function];
}

- (void)sendEvent:(NSString *)eventName withData:(id)data
{
    [self.socket sendEvent:eventName forNamespace:self.endpoint withData:data];
}

- (void)sendEvent:(NSString *)eventName
         withData:(id)data
   andAcknowledge:(SocketIOCallback)function
{
    [self.socket sendEvent:eventName
              forNamespace:self.endpoint
                  withData:data
            andAcknowledge:function];
}

#pragma mark - socketIONamespace delegate protocol

- (void)socketIODidConnect:(SocketIO *)socket
{
    if ([_delegate respondsToSelector:@selector(socketIODidConnect:)]) {
        [_delegate socketIODidConnect:socket];
    }
}

- (void)socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error
{
    if ([_delegate respondsToSelector:@selector(socketIODidDisconnect:
                                                disconnectedWithError:)]) {
        [_delegate socketIODidDisconnect:socket
                   disconnectedWithError:error];
    }
}

- (void)socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveMessage:)]) {
        [_delegate socketIO:socket didReceiveMessage:packet];
    }
}

- (void)socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet
{
    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveJSON:)]) {
        [_delegate socketIO:socket didReceiveJSON:packet];
    }
}

- (void)socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    if ([_delegate respondsToSelector:@selector(socketIO:didReceiveEvent:)]) {
        [_delegate socketIO:socket didReceiveEvent:packet];
    }
}

- (void)socketIO:(SocketIO *)socket didSendMessage:(SocketIOPacket *)packet
{
    if ([_delegate respondsToSelector:@selector(socketIO:didSendMessage:)]) {
        [_delegate socketIO:socket didSendMessage:packet];
    }
}

- (void)socketIO:(SocketIO *)socket onError:(NSError *)error
{
    if ([_delegate respondsToSelector:@selector(socketIO:onError:)]) {
        [_delegate socketIO:socket onError:error];
    }
}

@end
