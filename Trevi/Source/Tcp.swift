//
//  Tcp.swift
//  Trevi
//
//  Created by JangTaehwan on 2016. 2. 17..
//  Copyright © 2016년 LeeYoseob. All rights reserved.
//

import Libuv

public class Tcp : Stream {
    
    public let tcpHandle : uv_tcp_ptr
    
    public init () {
        
        self.tcpHandle = uv_tcp_ptr.alloc(1)
        
        uv_tcp_init(uv_default_loop(), self.tcpHandle)
    
        super.init(streamHandle : uv_stream_ptr(self.tcpHandle))
    }
    
    deinit {
        print("Tcp deinit")
    }
    
}



// Tcp static functions.

extension Tcp {
    
    public static func open (handle : uv_tcp_ptr, fd : uv_os_fd_t) {
        
        // It sets fd to non-block.
        uv_tcp_open(handle, fd)
    }
    
    public static func bind(handle : uv_tcp_ptr, address: String, port: Int32) {
        var sockaddr = sockaddr_in()
        
        let error = withUnsafeMutablePointer(&sockaddr) { (ptr) -> Int32 in
            uv_ip4_addr(address, port, ptr)
            return uv_tcp_bind(handle , UnsafePointer(ptr), 0)
        }
        
        if error != 0 {
            // Should handle error
        }
    }
    
    public static func bind6(handle : uv_tcp_ptr, address: String, port: Int32) {
        var sockaddr = sockaddr_in6()
        
        let error = withUnsafeMutablePointer(&sockaddr) { (ptr) -> Int32 in
            uv_ip6_addr(address, port, ptr)
            return uv_tcp_bind(handle , UnsafePointer(ptr), 0)
        }
        
        if error != 0 {
            // Should handle error
        }
    }
    
    public static func listen(handle : uv_stream_ptr, backlog : Int32 = 50) {
        
        let error = uv_listen(handle, backlog, Tcp.onConnection)
        
        if error != 0 {
            // Should handle error
        }
        
    }
    
    public static func connect(handle : uv_tcp_ptr) {
        let request = uv_connect_ptr.alloc(1)
        let address = Tcp.getSocketName(handle)
        let error = uv_tcp_connect(request, handle, address, Tcp.afterConnect)
        
        if error != 0 {
            // Should handle error
        }
    }
    
    //  Enable / disable Nagle’s algorithm.
    public static func setNoDelay (handle : uv_tcp_ptr, enable : Int32) {
        
        uv_tcp_nodelay(handle, enable)
    }
    
    public static func setKeepAlive (handle : uv_tcp_ptr, enable : Int32, delay : UInt32) {
        
        uv_tcp_keepalive(handle, enable, delay)
    }
    
    public static func setSimultaneousAccepts (handle : uv_tcp_ptr, enable : Int32) {
        
        uv_tcp_simultaneous_accepts(handle, enable)
    }
    
    public static func getSocketName(handle : uv_tcp_ptr) -> sockaddr_ptr {
        
        var len = Int32(sizeof(sockaddr))
        let name = sockaddr_ptr.alloc(Int(len))
        
        uv_tcp_getsockname(handle, name, &len)
        
        return name
    }
    
    public static func getPeerName(handle : uv_tcp_ptr) -> sockaddr_ptr {
        
        var len = Int32(sizeof(sockaddr))
        let name = sockaddr_ptr.alloc(Int(len))
        
        uv_tcp_getpeername(handle, name, &len)
        
        return name
    }
    
}


// Tcp static callbacks.

extension Tcp {
    
    public static var onConnection : uv_connection_cb = { (handle, status) in
        
        var client = Tcp()
        
        if uv_accept(handle, client.streamHandle) != 0 {
            return
        }
        
        if let wrap = Handle.dictionary[uv_handle_ptr(handle)] {
            if let callback =  wrap.event.onConnection {
                callback(client.streamHandle)
            }
        }
        
        client.readStart()
    }
    
    public static var afterConnect : uv_connect_cb = { (request, status) in
        
    }
}


// Socket options.
public enum SocketOption {
    case BROADCAST(Bool),
    DEBUG(Bool),
    DONTROUTE(Bool),
    OOBINLINE(Bool),
    REUSEADDR(Bool),
    KEEPALIVE(Bool),
    NOSIGPIPE(Bool),
    
    SNDBUF(Int32),
    RCVBUF(Int32)
    
    var match : (name : Int32, value : Int32) {
        switch self {
        case .BROADCAST(let value) :   return (SO_BROADCAST, Int32(value.hashValue))
        case .DEBUG(let value) :            return (SO_DEBUG, Int32(value.hashValue))
        case .DONTROUTE(let value) :   return (SO_DONTROUTE, Int32(value.hashValue))
        case .OOBINLINE(let value) :      return (SO_OOBINLINE, Int32(value.hashValue))
        case .REUSEADDR(let value):     return (SO_REUSEADDR, Int32(value.hashValue))
        case .KEEPALIVE(let value) :      return (SO_KEEPALIVE, Int32(value.hashValue))
        case .NOSIGPIPE(let value) :      return (SO_NOSIGPIPE, Int32(value.hashValue))
            
        case .SNDBUF(let value):            return (SO_SNDBUF, value)
        case .RCVBUF(let value):            return (SO_RCVBUF, value)
        }
    }
}


// Socket option functions.
extension Tcp {
    
    public static func setSocketOption (handle : uv_tcp_ptr, options: [SocketOption]?) -> Bool {
        if options == nil { return false }
        
        for option in options!{
            let name = option.match.name
            var buffer = option.match.value
            let bufferLen = socklen_t(sizeof(Int32))
            
            #if os(Linux)
                let status  = SwiftGlibc.setsockopt(getFD(uv_handle_ptr(handle)), SOL_SOCKET, name, &buffer, bufferLen)
            #else
                let status  = Darwin.setsockopt(getFD(uv_handle_ptr(handle)), SOL_SOCKET, name, &buffer, bufferLen)
            #endif
            
            if status == -1 {
                print("Failed to set socket option : \(option), value : \(buffer)")
                return false
            }
        }
        
        return true
    }
    
    public static func getSocketOption(handle : uv_tcp_ptr, option: SocketOption) -> Int32 {
        let name = option.match.name
        var buffer = Int32(0)
        var bufferLen = socklen_t(sizeof(Int32))
        
        #if os(Linux)
            let status  = SwiftGlibc.getsockopt(getFD(uv_handle_ptr(handle)), SOL_SOCKET, name, &buffer, &bufferLen)
        #else
            let status  = Darwin.getsockopt(getFD(uv_handle_ptr(handle)), SOL_SOCKET, name, &buffer, &bufferLen)
        #endif
        
        if status == -1 {
            print("Failed to get socket option name : \(name)")
            return status
        }
        
        return buffer
    }
}
