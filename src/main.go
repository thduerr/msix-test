package main

import (
	"syscall"
	"unsafe"
)

func main() {
	user32 := syscall.NewLazyDLL("user32.dll")
	msgBox := user32.NewProc("MessageBoxW")
	text, _ := syscall.UTF16PtrFromString("Hello, World!")
	title, _ := syscall.UTF16PtrFromString("Hello World MSIX")
	msgBox.Call(0, uintptr(unsafe.Pointer(text)), uintptr(unsafe.Pointer(title)), 0x40)
}
