import Foundation

/// Resolves process information from PID.
public struct ProcessResolver: Sendable {
    public init() {}

    /// Resolves the full path of a process from its PID using /proc or proc_pidpath.
    public func resolvePath(pid: Int) -> String {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(Int32(pid), &pathBuffer, UInt32(MAXPATHLEN))
        if length > 0 {
            return String(cString: pathBuffer)
        }
        return ""
    }
}

// Import for proc_pidpath
#if canImport(Darwin)
import Darwin

@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutableRawPointer, _ bufferSize: UInt32) -> Int32
#endif
