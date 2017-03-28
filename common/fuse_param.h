/*
 * Copyright (c) 2006-2008 Amit Singh/Google Inc.
 * Copyright (c) 2010 Tuxera Inc.
 * Copyright (c) 2011-2016 Benjamin Fleischer
 * All rights reserved.
 */

#ifndef _FUSE_PARAM_H_
#define _FUSE_PARAM_H_

#include <fuse_preprocessor.h>
#include <fuse_version.h>

#include <mach/vm_param.h>

#ifdef KERNEL
    #include <libkern/version.h>
#endif

/*
 * Compile-time tunables
 */

#ifdef KERNEL
    /* Kernel-space compile-time tunables */

    #define M_OSXFUSE_ENABLE_FIFOFS                     0
    #define M_OSXFUSE_ENABLE_SPECFS                     0
    #define M_OSXFUSE_ENABLE_TSLOCKING                  1
    #define M_OSXFUSE_ENABLE_UNSUPPORTED                1
    #define M_OSXFUSE_ENABLE_XATTR                      1
    #define M_OSXFUSE_ENABLE_DSELECT                    1

    #if M_OSXFUSE_ENABLE_UNSUPPORTED
        #define M_OSXFUSE_ENABLE_EXCHANGE               1
        #define M_OSXFUSE_ENABLE_INTERIM_FSNODE_LOCK    1

        /*
         * In Mac OS X 10.5 the file system implementation is responsible for
         * posting kqueue events. Starting with Mac OS X 10.6 the VFS layer
         * takes over the job.
         */
        #if VERSION_MAJOR < 10
            #define M_OSXFUSE_ENABLE_KQUEUE             1
        #endif
    #endif /* M_OSXFUSE_ENABLE_UNSUPPORTED */

    #if M_OSXFUSE_ENABLE_INTERIM_FSNODE_LOCK
        /*
         * Options M_OSXFUSE_ENABLE_BIG_LOCK and M_OSXFUSE_ENABLE_HUGE_LOCK are
         * mutually exclusive.
         */
        #define M_OSXFUSE_ENABLE_HUGE_LOCK              0
        #define M_OSXFUSE_ENABLE_BIG_LOCK               1

        #define M_OSXFUSE_ENABLE_LOCK_LOGGING           0
    #endif /* M_OSXFUSE_ENABLE_INTERIM_FSNODE_LOCK */

#endif /* KERNEL */

/*
 * Availability
 */

// Minimum supported Darwin version
#define OSXFUSE_MIN_DARWIN_VERSION      9 /* Mac OS X 10.5 */

/* Compatible API version */

#define FUSE_ABI_VERSION_MAX            (FUSE_KERNEL_VERSION * 100 + FUSE_KERNEL_MINOR_VERSION)
#define FUSE_ABI_VERSION_MIN            708

/*
 * Paths
 */

#ifndef OSXFUSE_BUNDLE_PREFIX_LITERAL
    #define OSXFUSE_BUNDLE_PREFIX_LITERAL
#endif
#define OSXFUSE_BUNDLE_PREFIX           FUSE_PP_STRINGIFY(OSXFUSE_BUNDLE_PREFIX_LITERAL)

#define OSXFUSE_BUNDLE_PATH             OSXFUSE_BUNDLE_PREFIX "/Library/Filesystems/osxfuse.fs"
#define OSXFUSE_RESOURCES_PATH          OSXFUSE_BUNDLE_PATH "/Contents/Resources"
#define OSXFUSE_EXTENSIONS_PATH         OSXFUSE_BUNDLE_PATH "/Contents/Extensions"
#define OSXFUSE_KEXT_NAME               "osxfuse.kext"
#define OSXFUSE_LOAD_PROG               OSXFUSE_RESOURCES_PATH "/load_osxfuse"
#define OSXFUSE_MOUNT_PROG              OSXFUSE_RESOURCES_PATH "/mount_osxfuse"
#define SYSTEM_KEXTLOAD                 "/sbin/kextload"
#define SYSTEM_KEXTUNLOAD               "/sbin/kextunload"

/*
 * User Control
 */

#define MACOSX_ADMIN_GROUP_NAME         "admin"
#define FUSE_DEFAULT_ALLOW_OTHER        0

#define OSXFUSE_SYSCTL_TUNABLES_ADMIN   "vfs.generic." OSXFUSE_NAME ".tunables.admin_group"
#define OSXFUSE_SYSCTL_VERSION_NUMBER   "vfs.generic." OSXFUSE_NAME ".version.number"

#if OSXFUSE_ENABLE_MACFUSE_MODE
    #define OSXFUSE_SYSCTL_MACFUSE_MODE "vfs.generic." OSXFUSE_NAME ".control.macfuse_mode"
#endif

/*
 * Device interface
 */

/*
 * This is the prefix of the name of a FUSE device node in devfs. The suffix is
 * the device number. "/dev/osxfuse0" is the first FUSE device by default.
 */
#define OSXFUSE_DEVICE_BASENAME                 OSXFUSE_NAME

/*
 * This is the number of /dev/osxfuse{n} nodes we will create. {n} goes from
 * 0 to (OSXFUSE_NDEVICES - 1).
 */
#define OSXFUSE_NDEVICES                        64

/*
 * File system interface
 */

#define FUSE_MAX_UPL_SIZE                       8192

/*
 * This is the default block size of the virtual storage devices that are
 * implicitly implemented by the FUSE kernel extension. This can be changed
 * on a per-mount basis.
 */
#define FUSE_DEFAULT_BLOCKSIZE                  4096

#define FUSE_MIN_BLOCKSIZE                      128
#define FUSE_MAX_BLOCKSIZE                      MAXBSIZE

/*
 * This is the default I/O size used while accessing the virtual storage
 * devices. It can be changed on a per-mount and per-file basis.
 *
 * Nevertheless, the I/O size must be at least as big as the block size.
 */
#define FUSE_DEFAULT_IOSIZE                     (16 * PAGE_SIZE)

#define FUSE_MIN_IOSIZE                         PAGE_SIZE
#define FUSE_MAX_IOSIZE                         (FUSE_MAX_UPL_SIZE * PAGE_SIZE)

/* User-Kernel IPC buffer */

#define FUSE_DEFAULT_USERKERNEL_BUFSIZE         FUSE_MAX_IOSIZE
#define FUSE_MIN_USERKERNEL_BUFSIZE             (128 * 1024)
#define FUSE_MAX_USERKERNEL_BUFSIZE             FUSE_MAX_IOSIZE

/* Daemon timeout */

#define FUSE_DEFAULT_DAEMON_TIMEOUT             60  /* s */
#define FUSE_MIN_DAEMON_TIMEOUT                 0   /* s */
#define FUSE_MAX_DAEMON_TIMEOUT                 600 /* s */

#ifdef KERNEL
    /*
     * This is the soft upper limit on the number of "request tickets" FUSE's
     * user-kernel IPC layer can have for a given mount. This can be modified
     * through the vfs.generic.osxfuse.* sysctl interface.
     */
    #define FUSE_DEFAULT_MAX_FREE_TICKETS       1024
    #define FUSE_DEFAULT_IOV_PERMANENT_BUFSIZE  (1 << 19)
    #define FUSE_DEFAULT_IOV_CREDIT             16

    #define FUSE_REASONABLE_XATTRSIZE           FUSE_MIN_USERKERNEL_BUFSIZE

    #define FUSE_LINK_MAX                       LINK_MAX
    #define FUSE_UIO_BACKUP_MAX                 8

    #define FUSE_MAXNAMLEN                      255
#endif /* KERNEL */

#endif /* _FUSE_PARAM_H_ */
