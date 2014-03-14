//
//  SocketIOTransport.h
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

@protocol SocketIOTransportDelegate <NSObject>

- (void) onData:(id)message;
- (void) onDisconnect:(NSError*)error;
- (void) onError:(NSError*)error;

@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSInteger port;
@property (nonatomic, readonly) NSString *sid;
@property (nonatomic, readonly) NSTimeInterval heartbeatTimeout;
@property (nonatomic) BOOL useSecure;

@end

@protocol SocketIOTransport <NSObject>

- (id) initWithDelegate:(id <SocketIOTransportDelegate>)delegate;
- (void) open;
- (void) close;
- (BOOL) isReady;
- (void) send:(NSString *)request;

@property (nonatomic, weak) id <SocketIOTransportDelegate> delegate;

@end
