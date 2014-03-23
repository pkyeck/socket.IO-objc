## 0.5.2 (2014-03-23)

  - check HTTP status code of NSURLConnection responses during xhr polling transport


## 0.5.1 (2014-03-14)

  - add method to pass cookies on handshake
  - distinguish between handshake failed and unauthorized handshake


## 0.5 (2014-02-21)

  - finally remove deprecated delegate methods
  - remove external JSON frameworks


## 0.4.1 (2013-11-18)

  - fix unix timecode bug in handshake url. close #118.
  - Instantiate errorInfo NSMutableDictionary using mutableCopy as suggested by Elshad. close #125.
  - introduce closed flag to XHR transport. fix #130.
  - Changed delegates from unsafe_unretained to weak
  - Fix improper use of NSLocalizedDescriptionKey.


## 0.4.0.1 (2013-09-19)

  - bugfix for namespace param error


## 0.4 (2013-07-18)

  - update example code to also include the new setResourceName: method
  - allow socket.io resource to be renamed from outside. close #80.
  - cleaned up URL schemas and their usage
  - try forced disconnect in SocketTester example
  - adjust the forced disconnect method a bit
  - change deployment target to iOS 5 (because socket-rocket needs it and we're using __weak now)
  - update submodules
  - SocketIO: don't use NSURLConnection delegate property in -dealloc - not available without BlocksKit
  - Synchronous disconnect
  - Fixed for sending events before socket is connected
  - Ensure to cleanup properly in -disconnect & -dealloc - fixes crashes
  - Add initial connection timeout
  - Fixed disconnect error loop
  - Changed timeout timer from NSTimer to GCD timer to avoid retain cycle.


## 0.3.3 (2013-04-25)

  - Payloads cause disconnects. fixes #65
  - Fixes inability to reconnect as described in #76
  - Send all arguments to the callback, not just the first one. fixes #85


## 0.3.2 (2013-02-06)

  - Suppress deprecation warning (it's already checked with respondsToSelector)
  - cleanup + SR submodule update fixes #70
  - Fixed bug where SocketIOTransportWebsocket didn't clear the delegate on the SRWebSocket.


## 0.3.1 (2012-12-26)

  - fixes connect/disconnect problems. close #46


## 0.3 (2012-12-24)

  - added long polling. fixed #8.
  - handshake response data check updated. fixes #62.
