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

/*
 * The "AVFI" (alter-vnode-for-inode) ioctls all require an inode number as an
 * argument. In the user-space library, you can get the inode number from a
 * path by using fuse_lookup_inode_by_path_np().
 *
 * To see an example of using this, see the implementation of
 * fuse_purge_path_np() in lib/fuse_darwin.c.
 */

struct fuse_avfi_ioctl
{
    uint64_t inode;
    uint64_t cmd;
    uint32_t ubc_flags;
    uint32_t note;
    off_t    size;
};

// Alter the vnode (if any) specified by the given inode
#define FUSEDEVIOCALTERVNODEFORINODE  _IOW('F', 6,  struct fuse_avfi_ioctl)
#define FSCTLALTERVNODEFORINODE       IOCBASECMD(FUSEDEVIOCALTERVNODEFORINODE)

/* Possible cmd values for AVFI */

#define FUSE_AVFI_MARKGONE       0x00000001 // no ubc_flags
#define FUSE_AVFI_PURGEATTRCACHE 0x00000002 // no ubc_flags
#define FUSE_AVFI_PURGEVNCACHE   0x00000004 // no ubc_flags
#define FUSE_AVFI_UBC            0x00000008 // uses ubc_flags
#define FUSE_AVFI_UBC_SETSIZE    0x00000010 // uses ubc_flags, size
#define FUSE_AVFI_KNOTE          0x00000020 // uses note

// Enable or disable ACL
#define FUSE_SETACLSTATE              _IOW('h', 10, int32_t)
#define FSCTLSETACLSTATE              IOCBASECMD(FUSE_SETACLSTATE)

#endif /* _FUSE_IOCTL_H_ */
