//
//  SocketIO_NSInterface.h
//  Pods
//
//  Created by jbaez on 04/07/2014.
//
//  SocketIO Interface used by SocketIONamespace
//

#import "SocketIO.h"

@interface SocketIO ()

/// For reusing socket connection with multiple namespaces
- (void)addNamespaceDelegate:(id<SocketIONamespaceDelegate>) delegate;

- (void)sendMessage:(NSString *)data forNamespace:(NSString *)endpoint;

- (void)sendMessage:(NSString *)data
       forNamespace:(NSString *)endpoint
    withAcknowledge:(SocketIOCallback)function;

- (void)sendJSON:(NSDictionary *)data forNamespace:(NSString *)endpoint;

- (void)sendJSON:(NSDictionary *)data
    forNamespace:(NSString *)endpoint
 withAcknowledge:(SocketIOCallback)function;

- (void)sendEvent:(NSString *)eventName
     forNamespace:(NSString *)endpoint
         withData:(id)data;

- (void)sendEvent:(NSString *)eventName
     forNamespace:(NSString *)endpoint
         withData:(id)data
   andAcknowledge:(SocketIOCallback)function;

- (void)sendConnectForNamespace:(NSString *)endpoint;

@end
