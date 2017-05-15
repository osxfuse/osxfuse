/*
 * Copyright (c) 2006-2008 Amit Singh/Google Inc.
 * All rights reserved.
 */

#ifndef _FUSE_IOCTL_H_
#define _FUSE_IOCTL_H_

#include <stdint.h>
#include <sys/ioctl.h>

// Get mounter's pid
#define FUSEDEVGETMOUNTERPID           _IOR('F', 1,  u_int32_t)

// Check if FUSE_INIT kernel-user handshake is complete
#define FUSEDEVIOCGETHANDSHAKECOMPLETE _IOR('F', 2,  u_int32_t)

// Mark the daemon as dead
#define FUSEDEVIOCSETDAEMONDEAD        _IOW('F', 3,  u_int32_t)

// Get device's random "secret"
#define FUSEDEVIOCGETRANDOM            _IOR('F', 5, u_int32_t)

// Enable or disable ACL
#define FUSE_SETACLSTATE              _IOW('h', 10, int32_t)
#define FSCTLSETACLSTATE              IOCBASECMD(FUSE_SETACLSTATE)

#endif /* _FUSE_IOCTL_H_ */
