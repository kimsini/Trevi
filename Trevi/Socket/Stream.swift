//
//  Stream.swift
//  Trevi
//
//  Created by JangTaehwan on 2016. 2. 17..
//  Copyright © 2016년 LeeYoseob. All rights reserved.
//


import Libuv

public class Stream : Handle {
    
    public let streamHandle : uv_stream_ptr
    
    var readCallback : ((Int, uv_buf_const_ptr, uv_handle_type)->())! = nil
    
    public init (streamHandle : uv_stream_ptr){
        self.streamHandle = streamHandle
        super.init(handle: uv_handle_ptr(streamHandle))
    }
    deinit {
        
    }
    
    // Should be removed. It just for testing Stream module right now.
    public func readStart(callback : uv_read_cb!) -> Int32 {
        return uv_read_start(self.streamHandle, Stream.onAlloc, callback)
    }
    
    public func readStart() -> Int32 {
        return uv_read_start(self.streamHandle, Stream.onAlloc, Stream.onRead)
    }
    
    public func readStop() -> Int32 {
        return uv_read_stop(self.streamHandle)
    }
    
    public func doShutDown(req : uv_shutdown_ptr) -> Int32 {
        var error : Int32
        
        error = uv_shutdown(req, self.streamHandle, Stream.afterShutdown)
        
        return error
    }
    
    public func doTryWrite(bufs: UnsafeMutablePointer<uv_buf_ptr>, count : UnsafeMutablePointer<UInt32>) -> Int32 {
        var error : Int32
        var written : Int32
        var vbufs : uv_buf_ptr = bufs.memory
        var vcount : UInt32 = count.memory
        
        error = uv_try_write(self.streamHandle, vbufs, vcount)
        
        guard  (error != UV_ENOSYS.rawValue && error != UV_EAGAIN.rawValue) else {
            return 0
        }
        guard error >= 0 else {
            return error
        }
        
        written = error
        for ; vcount > 0 ; vbufs++, vcount-- {
            
            if vbufs[0].len > Int(written) {
                vbufs[0].base.initialize(vbufs[0].base[Int(written)])
                vbufs[0].len -= Int(written)
                written = 0
                break;
            }
            else {
                written -= vbufs[0].len;
            }
        }
        
        bufs.memory = vbufs;
        count.memory = vcount;
        
        return 0
    }
    
    public func doWrite(bufs: uv_buf_ptr, count : UInt32, sendHandle : uv_stream_ptr!) -> Int {
        let req : uv_write_ptr = uv_write_ptr.alloc(1)
        
        let ret : Int32
        
        if let handle = sendHandle {
            ret = uv_write2(req, self.streamHandle, bufs, count, handle, Stream.afterWrite)
        }
        else {
            ret = uv_write(req, self.streamHandle, bufs, count, Stream.afterWrite)
        }
        
        if ret == 0 {
            // Should add count module
            
            //
        }
        
        return 1
    }
    
}


// Stream static properties and methods

extension Stream {
    
    public static func isNamedPipe(handle : uv_stream_ptr) -> Bool {
        return handle.memory.type == UV_NAMED_PIPE
    }
    
    public static func isNamedPipeIpc(handle : uv_stream_ptr) -> Bool {
        return Stream.isNamedPipe(handle) && uv_pipe_ptr(handle).memory.ipc != 0
    }
    
    public static func getHandleType(handle : uv_stream_ptr) -> uv_handle_type {
        var type : uv_handle_type = UV_UNKNOWN_HANDLE
        
        if Stream.isNamedPipe(handle) && uv_pipe_pending_count(uv_pipe_ptr(handle)) > 0 {
            type = uv_pipe_pending_type(uv_pipe_ptr(handle))
        }
        
        return type
    }
    
    public static var onAlloc : uv_alloc_cb! = { (_, size, buf) in
        buf.initialize(uv_buf_init(UnsafeMutablePointer.alloc(size), UInt32(size)))
    }
    
    public typealias uv_read_com_cb = @convention(c) (uv_stream_ptr, Int, uv_buf_const_ptr, uv_handle_type) -> ()
    public static let onReadCommon : uv_read_com_cb = { (handle, nread, buf, type) in
        
        let wrap : Stream = Stream(streamHandle: uv_stream_ptr(handle.memory.data))
        // Should add count module
        
        //
        if let callback  = wrap.readCallback {
            callback(nread, buf, type)
        }
    }
    
    public static var onRead : uv_read_cb! = { (handle, nread, buf) in
        
        let wrap : Stream = Stream(streamHandle: uv_stream_ptr(handle.memory.data))
        var type : uv_handle_type = Stream.getHandleType(handle)
        
        Stream.onReadCommon(handle, nread, buf, type)
    }
    
    public static var afterShutdown : uv_shutdown_cb! = { (req, status) in
        // State after shutdown callback
    }
    
    public static var afterWrite : uv_write_cb! = { (req, status) in
        // State after write callback
    }
    
    func onAfterWriteImpl() -> Void {
        
    }
    
    func onAllocImpl() -> Void {
        
    }
    
    func onReadImpl() -> Void {
        
    }
}