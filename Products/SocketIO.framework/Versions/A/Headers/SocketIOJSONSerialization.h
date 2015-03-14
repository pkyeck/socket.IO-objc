//
//  SocketIOJSONSerialization.h
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

@interface SocketIOJSONSerialization : NSObject

+ (id) objectFromJSONData:(NSData *)data error:(NSError **)error;
+ (NSString *) JSONStringFromObject:(id)object error:(NSError **)error;

@end
