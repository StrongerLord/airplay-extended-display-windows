//go:build windows

// parsec-vdd plugs a virtual monitor into the Parsec Virtual Display Driver and
// keeps it alive while it runs. Ctrl+C unplugs it.
//
// The driver drops its displays when nobody pings it (IOCTL update) for
// ~1 s, hence the 100 ms loop. Based on the protocol documented by
// nomi-san/parsec-vdd.
package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"
	"unsafe"
)

const (
	ioctlAdd     = 0x0022e004
	ioctlRemove  = 0x0022a008
	ioctlUpdate  = 0x0022a00c
	ioctlVersion = 0x0022e010

	fileFlagNoBuffering  = 0x20000000
	fileFlagWriteThrough = 0x80000000
)

// Device interface GUID of the Parsec VDD adapter
var vddGUID = syscall.GUID{
	Data1: 0x00b41627,
	Data2: 0x04c4,
	Data3: 0x429e,
	Data4: [8]byte{0xa2, 0x6e, 0x02, 0x65, 0xcf, 0x50, 0xc8, 0xfa},
}

var (
	cfgmgr32                = syscall.NewLazyDLL("cfgmgr32.dll")
	kernel32                = syscall.NewLazyDLL("kernel32.dll")
	procGetIfaceListSize    = cfgmgr32.NewProc("CM_Get_Device_Interface_List_SizeW")
	procGetIfaceList        = cfgmgr32.NewProc("CM_Get_Device_Interface_ListW")
	procDeviceIoControl     = kernel32.NewProc("DeviceIoControl")
	procGetOverlappedResult = kernel32.NewProc("GetOverlappedResult")
	procCreateEventW        = kernel32.NewProc("CreateEventW")
)

func devicePath() (string, error) {
	var size uint32
	r, _, _ := procGetIfaceListSize.Call(uintptr(unsafe.Pointer(&size)), uintptr(unsafe.Pointer(&vddGUID)), 0, 0)
	if r != 0 || size <= 1 {
		return "", fmt.Errorf("Parsec Virtual Display Driver not found (CM error %d)", r)
	}
	buf := make([]uint16, size)
	r, _, _ = procGetIfaceList.Call(uintptr(unsafe.Pointer(&vddGUID)), 0, uintptr(unsafe.Pointer(&buf[0])), uintptr(size), 0)
	if r != 0 {
		return "", fmt.Errorf("CM_Get_Device_Interface_ListW failed (%d)", r)
	}
	return syscall.UTF16ToString(buf), nil
}

// ioctl sends a control code with a 32-byte input buffer and reads a DWORD,
// using overlapped I/O as the driver expects.
func ioctl(h syscall.Handle, code uint32, in [32]byte) (uint32, error) {
	ev, _, err := procCreateEventW.Call(0, 1, 0, 0)
	if ev == 0 {
		return 0, err
	}
	defer syscall.CloseHandle(syscall.Handle(ev))
	var ov syscall.Overlapped
	ov.HEvent = syscall.Handle(ev)
	var out, n uint32
	procDeviceIoControl.Call(uintptr(h), uintptr(code),
		uintptr(unsafe.Pointer(&in[0])), 32,
		uintptr(unsafe.Pointer(&out)), 4,
		uintptr(unsafe.Pointer(&n)), uintptr(unsafe.Pointer(&ov)))
	r, _, err := procGetOverlappedResult.Call(uintptr(h), uintptr(unsafe.Pointer(&ov)), uintptr(unsafe.Pointer(&n)), 1)
	if r == 0 {
		return 0, err
	}
	return out, nil
}

func main() {
	path, err := devicePath()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	p, _ := syscall.UTF16PtrFromString(path)
	h, err := syscall.CreateFile(p, syscall.GENERIC_READ|syscall.GENERIC_WRITE,
		syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE, nil, syscall.OPEN_EXISTING,
		syscall.FILE_ATTRIBUTE_NORMAL|fileFlagNoBuffering|syscall.FILE_FLAG_OVERLAPPED|fileFlagWriteThrough, 0)
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open the driver:", err)
		os.Exit(1)
	}
	defer syscall.CloseHandle(h)

	ver, _ := ioctl(h, ioctlVersion, [32]byte{})
	idx, err := ioctl(h, ioctlAdd, [32]byte{})
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not add the display:", err)
		os.Exit(1)
	}
	ioctl(h, ioctlUpdate, [32]byte{})
	fmt.Printf("Virtual display plugged in (driver v%d, index %d). Ctrl+C to remove it.\n", ver&0xffff, idx)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	t := time.NewTicker(100 * time.Millisecond)
	defer t.Stop()
	for {
		select {
		case <-t.C:
			ioctl(h, ioctlUpdate, [32]byte{})
		case <-stop:
			var in [32]byte
			// The driver expects the index as a byte-swapped 16-bit value
			in[0] = byte(idx >> 8)
			in[1] = byte(idx)
			ioctl(h, ioctlRemove, in)
			ioctl(h, ioctlUpdate, [32]byte{})
			fmt.Println("Virtual display removed.")
			return
		}
	}
}
