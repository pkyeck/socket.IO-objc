//
//  SocketIONamespace.h
//
//  Created by jbaez https://github.com/jbaez on 04/07/2014.
//
//

#import <Foundation/Foundation.h>
#import "SocketIO_NSInterface.h"

@interface SocketIONamespace : NSObject <SocketIOProtocol, SocketIONamespaceDelegate>
{
    __weak id<SocketIODelegate> _delegate;
}

/// The namespace enpoint
@property (nonatomic, strong, readonly) NSString *endpoint;

/// SocketIO delegate for this namespace
@property (nonatomic, weak) id<SocketIODelegate> delegate;

/// Shared socket instance
@property (nonatomic, strong, readonly) SocketIO *socket;

/// Namespace connection instance
+ (instancetype)namespaceWithEndpoint:(NSString *)endpoint
                             delegate:(id<SocketIODelegate>)delegate;

/// Namespace connection instance
+ (instancetype)namespaceWithEndpoint:(NSString *)endpoint;

/// Shared socket used for namespace connections
+ (SocketIO *)sharedSocket;

#pragma mark - SocketIOProtocol

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port;
- (void)connectToHost:(NSString *)host
               onPort:(NSInteger)port
           withParams:(NSDictionary *)params;
- (void)connectToHost:(NSString *)host
               onPort:(NSInteger)port
           withParams:(NSDictionary *)params
withConnectionTimeout:(NSTimeInterval)connectionTimeout;

- (void)sendMessage:(NSString *)data;
- (void)sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function;
- (void)sendJSON:(NSDictionary *)data;
- (void)sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function;
- (void)sendEvent:(NSString *)eventName withData:(id)data;
- (void)sendEvent:(NSString *)eventName
         withData:(id)data
   andAcknowledge:(SocketIOCallback)function;

@end
