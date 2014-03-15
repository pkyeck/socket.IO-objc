# Socket.IO / Objective C Library

  Interface to communicate between Objective C and [Socket.IO](http://socket.io/)
  with the help of websockets or [Long-Polling](http://en.wikipedia.org/wiki/Push_technology#Long_polling). Originally based on fpotter's [socketio-cocoa](https://github.com/fpotter/socketio-cocoa)
  it uses other libraries/classes like

   * [SocketRocket](https://github.com/square/SocketRocket)
  Look [here](https://github.com/square/SocketRocket#installing-ios) for further instructions how to use/install SocketRocket.


## Requirements

As of version 0.4, this library requires at least OS X 10.7 or iOS 5.0.
Because of this, we were able to remove the external JSON frameworks in v0.5 and only rely on iOS' own `NSJSONSerialization`.


## Usage

The easiest way to connect to your Socket.IO / node.js server is

``` objective-c
SocketIO *socketIO = [[SocketIO alloc] initWithDelegate:self];
[socketIO connectToHost:@"localhost" onPort:3000];
```

If required, additional parameters can be included in the handshake by adding an `NSDictionary` to the `withParams` option:

``` objective-c
[socketIO connectToHost:@"localhost"
                 onPort:3000
             withParams:[NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"auth_token", nil]
];
```

A namespace can also be defined in the connection details:

``` objective-c
[socketIO connectToHost:@"localhost" onPort:3000 withParams:nil withNamespace:@"/users"];
```

There are different methods to send data to the server

``` objective-c
- (void) sendMessage:(NSString *)data;
- (void) sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function;
- (void) sendJSON:(NSDictionary *)data;
- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function;
- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data;
- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data andAcknowledge:(SocketIOCallback)function;
```

So you could send a normal Message like this

``` objective-c
[socketIO sendMessage:@"hello world"];
```

or an Event (including some data) like this

``` objective-c
NSMutableDictionary *dict = [NSMutableDictionary dictionary];
[dict setObject:@"test1" forKey:@"key1"];
[dict setObject:@"test2" forKey:@"key2"];

[socketIO sendEvent:@"welcome" withData:dict];
```

If you want the server to acknowledge your Message/Event you would also pass a SocketIOCallback block

``` objective-c
SocketIOCallback cb = ^(id argsData) {
    NSDictionary *response = argsData;
    // do something with response
};
[socketIO sendEvent:@"welcomeAck" withData:dict andAcknowledge:cb];
```

All delegate methods are optional - you could implement the following

``` objective-c
- (void) socketIODidConnect:(SocketIO *)socket;
- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error;
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket didSendMessage:(SocketIOPacket *)packet;
- (void) socketIO:(SocketIO *)socket onError:(NSError *)error;
```

To process an incoming `message` or `event` just

``` objective-c
// message delegate
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveMessage >>> data: %@", packet.data);
}

// event delegate
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveEvent >>> data: %@", packet.data);
}
```

## Usage with OS X

Running the socket.io-objc library with OS X requires some minor changes:

- you have to use the SocketRocket.framework for OSX instead of just the submodule  
see: [SocketRocket's Installing OS X](https://github.com/square/SocketRocket#installing-os-x)  
(best way I got this to work was as a subproject and I didn't have to add the "copy file" stuff)

- when using the osx-framework, you have to fix the import-statement in SocketIOTransportWebsocket.h

``` objective-c
// replace
#import SRWebSocket.h

// with
#import <SocketRocket/SRWebSocket.h>
```
	
## Authors

Initial project by Philipp Kyeck <http://beta-interactive.de>.  
Additional support from these [amazing people](https://github.com/pkyeck/socket.IO-objc/blob/master/CONTRIBUTORS.md).

## License

(The MIT License)

Copyright (c) 2011-14 Philipp Kyeck <http://beta-interactive.de>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
