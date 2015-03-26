Pod::Spec.new do |spec|
spec.name             = 'socket.io-objc'
spec.version          = '0.6.4'
spec.license          = 'MIT'
spec.homepage         = 'https://github.com/francoisp/socket.IO-objc/'
spec.authors          = { 'Philipp Kyeck' => 'philipp@beta-interactive.de' }
spec.summary          = 'Socket.io 1.x client for Objective-C projects., with backward 0.9 compatibility'
spec.description      = "Interface to communicate between Objective C and Socket.IO with the help of websockets. Originally based on fpotter's socketio-cocoa and uses square's SocketRocket.\n"
spec.source           = { :git => 'https://github.com/francoisp/socket.IO-objc.git' }
spec.source_files     = '*.{h,m}'
spec.requires_arc     = true
spec.dependency 'SocketRocket'
spec.platforms        = { "ios" => "6.0",
"osx" => "10.8" }
end