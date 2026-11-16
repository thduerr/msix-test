package main

import (
	"encoding/binary"
	"fmt"
	"syscall"
	"unsafe"
)

// packageVersion returns the installed MSIX package version, e.g. "1.0.0.0".
// Updates themselves are handled by Windows via the .appinstaller file.
func packageVersion() string {
	proc := syscall.NewLazyDLL("kernel32.dll").NewProc("GetCurrentPackageId")
	if proc.Find() != nil {
		return "unknown"
	}
	var size uint32
	proc.Call(uintptr(unsafe.Pointer(&size)), 0) // query required buffer size
	if size < 16 {
		return "not packaged"
	}
	buf := make([]byte, size)
	if r, _, _ := proc.Call(uintptr(unsafe.Pointer(&size)), uintptr(unsafe.Pointer(&buf[0]))); r != 0 {
		return "not packaged"
	}
	// PACKAGE_ID: reserved(u32), processorArchitecture(u32), version(u64: revision, build, minor, major)
	v := binary.LittleEndian.Uint64(buf[8:16])
	return fmt.Sprintf("%d.%d.%d.%d", v>>48, (v>>32)&0xffff, (v>>16)&0xffff, v&0xffff)
}

func main() {
	msgBox := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
	text, _ := syscall.UTF16PtrFromString("Hello, World!\n\nVersion " + packageVersion())
	title, _ := syscall.UTF16PtrFromString("Hello World MSIX")
	msgBox.Call(0, uintptr(unsafe.Pointer(text)), uintptr(unsafe.Pointer(title)), 0x40)
}
