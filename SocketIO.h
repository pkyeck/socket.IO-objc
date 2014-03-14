//
//  SocketIO.h
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

@class SocketIO;
@class SocketIOPacket;

typedef void(^SocketIOCallback)(id argsData);

extern NSString* const SocketIOError;

typedef enum {
    SocketIOServerRespondedWithInvalidConnectionData = -1,
    SocketIOServerRespondedWithDisconnect = -2,
    SocketIOHeartbeatTimeout = -3,
    SocketIOWebSocketClosed = -4,
    SocketIOTransportsNotSupported = -5,
    SocketIOHandshakeFailed = -6,
    SocketIODataCouldNotBeSend = -7,
    SocketIOUnauthorized = -8
} SocketIOErrorCodes;


@protocol SocketIODelegate <NSObject>
@optional
- (void) socketIODidConnect:(SocketIO *)socket;
- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error;
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didSendMessage:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket onError:(NSError *)error;
@end


@interface SocketIO : NSObject <NSURLConnectionDelegate, SocketIOTransportDelegate>
{
    NSString *_host;
    NSInteger _port;
    NSString *_sid;
    NSString *_endpoint;
    NSDictionary *_params;
    
    __weak id<SocketIODelegate> _delegate;
    
    NSObject <SocketIOTransport> *_transport;
    
    BOOL _isConnected;
    BOOL _isConnecting;
    BOOL _useSecure;
    
    NSArray *_cookies;
    
    NSURLConnection *_handshake;
    
    // heartbeat
    NSTimeInterval _heartbeatTimeout;
    dispatch_source_t _timeout;
    
    NSMutableArray *_queue;
    
    // acknowledge
    NSMutableDictionary *_acks;
    NSInteger _ackCount;
    
    // http request
    NSMutableData *_httpRequestData;
    
    // get all arguments from ack? (https://github.com/pkyeck/socket.IO-objc/pull/85)
    BOOL _returnAllDataFromAck;
}

@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSInteger port;
@property (nonatomic, readonly) NSString *sid;
@property (nonatomic, readonly) NSTimeInterval heartbeatTimeout;
@property (nonatomic) BOOL useSecure;
@property (nonatomic) NSArray *cookies;
@property (nonatomic, readonly) BOOL isConnected, isConnecting;
@property (nonatomic, weak) id<SocketIODelegate> delegate;
@property (nonatomic) BOOL returnAllDataFromAck;

- (id) initWithDelegate:(id<SocketIODelegate>)delegate;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withNamespace:(NSString *)endpoint;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withNamespace:(NSString *)endpoint withConnectionTimeout: (NSTimeInterval) connectionTimeout;

- (void) disconnect;
- (void) disconnectForced;

- (void) sendMessage:(NSString *)data;
- (void) sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function;
- (void) sendJSON:(NSDictionary *)data;
- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function;
- (void) sendEvent:(NSString *)eventName withData:(id)data;
- (void) sendEvent:(NSString *)eventName withData:(id)data andAcknowledge:(SocketIOCallback)function;
- (void) sendAcknowledgement:(NSString*)pId withArgs:(NSArray *)data;

- (void) setResourceName:(NSString *)name;

@end