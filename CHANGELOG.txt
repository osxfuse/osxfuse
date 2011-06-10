= Changes and Feature Additions in MacFUSE Binary Releases =

== MacFUSE 2.0 (December 8, 2008) ==

  * Feature: MacFUSE Preference Pane. Makes it easy and straightforward to keep up-to-date with MacFUSE releases, with the user in full control.

  * Feature: 64-Bit Support. The entire MacFUSE software stack: the kernel extension, the MacFUSE user-space C library, and the Objective-C framework now also come in 64-bit versions. You must be running Leopard or above for this. Naturally, you also need 64-bit hardware to make use of these capabilities. [*Experimental*]

  * Feature: Support for Snow Leopard. You can now install and use MacFUSE on the *latest* Snow Leopard developer seed. [*Highly Experimental*]

  * Feature: Enhanced DTrace support. MacFUSE.framework now contains USDT probes that will be helpful to those developing file systems in Objective-C. For example, look at the updated LoopbackFS example file system: the logging code from it has been removed because better tracing information can be had using DTrace. Consequently, the file system code is shorter and easier to read.

  * Feature: Xcode project templates. MacFUSE now comes with project templates for helping developers get started even faster on their new file systems. You can now even create a file system with the proverbial "zero lines of code".

  * Feature: Debugging symbol bundles included for MacFUSE Objective-C and C libraries. Developers can now do source-level debugging within the Objective-C and C libraries even with the official MacFUSE builds. Look for `dSYM` bundles in the `Resources/Debug/` subdirectory within `MacFUSE.framework`.

  * Feature: Support for 64-bit inode numbers in the user-space library on Leopard and above. Developers can now choose to use 64-bit inode numbers in their file systems. To do so, a developer would have to compile their file system with `-D__DARWIN_64_BIT_INO_T=1` as part of `CFLAGS`. Then, *instead* of linking against `libfuse`, they would have to link against `libfuse_ino64`--that is, `-lfuse_ino64` instead of `-lfuse`.

  * Feature: New option `auto_cache`. When you enable this option, MacFUSE will automatically purge the buffer cache and/or attributes of files based on changes it detects in modification times. By default, if MacFUSE detects a change in a file's size during `getattr()`, it will purge that file's buffer cache. When `auto_cache` is enabled,  MacFUSE will additionally detect modification time changes during `getattr()` and `open()`. Relevant knote messages are also generated. All this is subject to the attribute timeout. (That is, up to one purge per attribute timeout window.) As long as your file system's `getattr()` returns up-to-date size and modification time information, this should work as intended. For file systems that wish the kernel to keep up with "remote" changes, this should obviate the need for explicit purging through `fuse_purge_np()` (see below).

  * Feature: New user-space library function `fuse_purge_np()`; can be used by a user-space file system daemon to purge a given file's buffer cache, tell the kernel that the file's size has changed, invalidate the file's in-kernel attributes cache, and generate an appropriate kernel event (kevent) that can be received through `kqueue()`. Note that the `auto_cache` option described above should make explicit use of this function unnecessary in most cases. [*Experimental*]

  * Feature: New user-space library function `fuse_knote_np()`; can be used by a user-space file system daemon to generate arbitrary kernel events (kevent) for a given file. Note that the `auto_cache` option described above should make explicit use of this function unnecessary in most cases. [*Experimental*]

  * Feature: Support for multiple concurrent file systems in a single process; enhancements to the user-space library should allow developers to run multiple instances of either a given file system or even different file systems without having to create a separate process for each instance. Moreover, each instance can be managed (mounted, accessed, unmounted) independently. [*Experimental*]

  * Feature: New callback `exchange`; provides support for exchanging data between two files. (See `exchangedata(2)`.)

  * Feature: New callback `getxtimes`; provides support for reading backup and creation times. (See `ATTR_CMN_BKUPTIME` and `ATTR_CMN_CRTIME` in `getattrlist(2)`.)

  * Feature: New callback `chflags`; provides support for setting file flags. (See `chflags(2)`.)

  * Feature: New callback `setbkuptime`; provides support for setting backup time.

  * Feature: New callback `setcrtime`; provides support for setting creation time.

  * Feature: New callbacks `setattr_x` and `fsetattr_x`; provides support for setting many attributes in a single call. Not only Mac OS X has a large number of settable attributes, heavy file system metadata activity, which is quite common and can occur behind the scenes, can generate a really large number of calls to set one or more attributes. In line with the "keeping things simple" philosophy, the MacFUSE API fans out a kernel-level `setattr` call into individual calls such as `chmod`, `chown`, `utimens`, `truncate`, `ftruncate`, and the newly introduced `chflags`, `setbkuptime`, and `setcrtime`. Depending on your user-space file system, you may really wish that you could handle all this in one call instead of receiving numerous back-to-back calls. `setattr_x` and `fsetattr_x` let you do that. *NOTE* that if you implement these calls, you will *NOT* receive *ANY* of the other "set" calls even if you do implement the latter. In other words, you will only receive `setattr_x` and `fsetattr_x`; the `chmod`, `chown`, `utimens`, `truncate`, `ftruncate`, `chflags`, `setcrtime`, and `setbkuptime` callbacks will never be called. (You must therefore handle everything at once.) Use this callback only if you *know* you need to use it. See the reference file system source (`loopbackc`) to see an example of how to use `[f]setattr_x`.

  * Feature: Backward compatibility (both binary and source levels) despite new callbacks; existing file system binaries linked against older MacFUSE versions should continue to work; file systems can choose to opt out of all the aforementioned new callbacks.

  * Update: Better version of the `loopback` reference file system; implements newly introduced callbacks and provides higher fidelity with the native file system.

  * Packaging: The user-space library is now installed with proper "current" and "compatibility" version numbers; it is also installed with an appropriate file name such as `libfuse.2.7.3.dylib` instead of the constant name `libfuse.0.0.0.dylib`. To maintain compatibility with existing binaries, a new symbolic link `libfuse.0.dylib` is included for the time being.

  * Packaging: A streamlined install/update mechanism is now part of MacFUSE. The mechanism greatly simplifies and improves install/update experience both for end users and for developers who use MacFUSE in their software. There is a single "unified" MacFUSE package that contains binaries for all supported platforms.

  * Building: A new build/packaging mechanism is now part of the MacFUSE source tree. This is relevant only to those who experiment with MacFUSE internals.

  * Bugfix: Fixed a bug that could cause a getattr call to report the older size after a write call if the former came before the server could finish the write.

  * Bugfix: Fixed a bug that could cause the call for setting the modification time for a file system object to be ignored under certain circumstances.

== MacFUSE 1.7 (June 30, 2008) ==

  * Bugfix: Fixed a kernel issue that could cause resource forks larger than 128KB to be truncated when accessed through the Finder.

  * Bugfix: Fixed a kernel issue where the file system could fail to "catch up" on a file's size when the size changed unbeknownst to MacFUSE (say, on a remote server.)

  * Fix: Changed a kernel policy that could prevent generation of certain fsevents. Although generally harmless in Leopard 10.5.2 and below, this could confuse higher layers of system software in 10.5.3. (The issue manifested as problematic file saves.)

  * Fix: 10.4: Fixed a compilation artifact issue where the MacFUSE 1.5 kernel extension could fail to load on PowerPC 10.4.x systems with an "unknown cmd field" error from `kextload`.

  * Fix: Packaging: The `IFPkgFlagInstalledSize` field is handled better in the package.

  * MacFUSE.framework Changes
     * Support for a `position` parameter in extended attributes delegate methods. The old methods are deprecated, although they will still be called (for now) if the file system does not implement the newer methods.

== MacFUSE 1.5 (April 25, 2008) ==

  * Bugfix: Fixed bug where the Finder would sometimes report zero KB free in a newly mounted MacFUSE volume.

  * Bugfix: Fixed a signal-related bug that prevented a process from calling `fuse_main()` more than once (for example, if the process wanted to remount a volume after it had been unmounted.)

  * Bugfix: Fixed an `exit(3)` call that should have been `_exit(3)`. Could cause tear-down issues for certain file systems.

  * Feature: If a user file system becomes dead or unreachable (for example, if the daemon crashed), MacFUSE will report `-1` as the file system subtype (the `f_fssubtype` field of `struct statfs64` and the `f_reserved1` field of `struct statfs`.) The MacFUSE file system property list files now identify subtype `-1` as the "dead" file system.

  * Feature: 10.5: Experimental support for `select(2)` on the user-kernel device. Must be explicitly enabled at kernel extension compile time through `M_MACFUSE_ENABLE_DSELECT`.

  * Feature: 10.5: Added support for file flags (see `chflags(2)`). Currently, a user file system can only provide these flags for reading. Support for setting these flags will come in the next release.

  * Update: 10.5: User-space library now based on FUSE library version 2.7.3.

  * Packaging: 10.5: MacFUSE for Tiger (the ready-to-install package) can now also be compiled on Leopard.

  * MacFUSE.framework Changes
     * 10.5: Support for garbage collection.
     * 10.5: Includes !BridgeSupport data.
     * Improved mount failure handling and notifications.
     * Improved documentation in header file; explicitly called out the keys that are supported in various delegate methods that use `NSDictionary`.
     * Support for `typeCode` and `creatorCode` in `GMFinderInfo` class.
     * Explicit constants to use as keys for notification dictionary, etc.
     * Added read support for the `st_flags` field of `struct stat`.
     * Fixed bug where the `st_ctimespec` field of `struct stat` was being set to `NSFileCreationDate`. The framework now sets `st_ctimespec` to equal `st_mtimespec`; the `NSFileCreationDate` is not currently supported.
     * Improved resolutions of times used by `AttributesOfItemAtPath:error` and `setAttributes:ofItemAtPath:error:`.
     * Added code for calling `createSymbolicLinkAtPath:` and `linkItemAtPath:`.
     * Added support for `mode_t` in `mkdir`. Tightened up `NSFilePosixPermissions` code in `mkdir`, `chmod`, and `create`.
     * 10.4: Improved create support when using custom icons (synthesized !AppleDouble files) on 10.4.

== MacFUSE 1.3 (January 8, 2008) ==

  * Includes the new `MacFUSE.framework` (installed in `/Library/Frameworks/`), a framework designed to simplify file-system development for Objective-C programmers.
  * [Leopard-only] Added new built-in stacking module `threadid` to the user-space library. It can be used when you want each file system request to come in to the user-space file system with the user/group IDs of the caller making the request.
  * [Leopard-only] Now includes version 2.7.2 of the user-space FUSE library.
  * Fixed an issue that caused sparse disk images on SSHFS fail to mount on Leopard.
  * Fixed an issue with the handling of the `nosyncwrites` option.
  * Fixed an issue with the handling of `.DS_Store` files when the `noappledouble` option was specified.
  * Fixed an issue with the handling of extended attributes when a user-space file system returned ENOTSUP in `setxattr()`.
  * Fixed an incorrect error message that users saw if they attempted to use a version of MacFUSE mismatched with their operating system version.
  * User-space library now exports operating-system version-detection routines.

== MacFUSE 1.1 (November 6, 2007) ==

== Improvements (Kernel) ==

  * Improved handling of synchronous I/O and uncached I/O.
  * `vnop_access()` now summarily allows calls for symbolic links.

=== Bugfixes (Kernel) ===

  * Fixed issue with writes to newly created `._` files in `noubc` (no unified buffer cache) mode. The issue could lead to failed file creation and/or failed file copies.
  * Fixed issue with handling the root vnode's parent ID when `use_ino` is in effect. The issue led to the Finder refusing to copy _from_ certain volumes.

== Improvements (User Space) ==

  * Added `const char *macfuse_version(void)` to the user-space library.
  * Added `void fuse_unmount_compat22(const char *mountpoint)` to the user-space library.
  * Simplified `xmp_access()` in the `fusexmp_fh` example file system.

== Bugfixes (User Space)

  * Fixed incorrect `listxattr()` behavior In the `fusexmp_fh` example file system. The issue could lead to a failed file copy when the source had both ACLs and non-ACL extended attributes.

=== Build and Packaging Improvements ===

  * MacFUSE releases for "Leopard" and "Tiger" now have different version numbers. See [MACFUSE_VERSIONING] for details.
  * Fixed `make-pkg.sh` so as not to include spurious `.svn` directories in its output on Leopard.
  * Added operating system version to the disk image volume name.

== MacFUSE 1.0.0 (October 26, 2007) ==

=== Leopard Support ===

  * Largely identical codebases for Mac OS X "Tiger" and "Leopard". Platform-specific optimizations and improvements where possible and appropriate.
  * Leopard binaries, both for kernel and user code, link against 10.5 SDKs.
  * Operating environment compatibility now checked and ensured at various levels: in the user-space library, in the mount utility, and in the load utility. Compatibility failure is reported through system-wide notifications and through GUI dialogs, which can optionally be suppressed.
  * `open` now supports `O_SYMLINK`.
  * Reference file system now supports `lchmod`.
  * Leopard-specific volume capabilities, volume attributes, and file attributes recognized.
  * Much improved Finder interaction: better mount-time behavior, better support for Finder metadata, better handling of file system failure.
  * Custom volume icon support based entirely on extended attributes.
  * Installed under `/Library/Filesystems/` on Leopard.

=== New/Improved Mount-Time Options ===

  * This release has several new mount-time options. Please see http://code.google.com/p/macfuse/wiki/OPTIONS for details.

=== Improvements and Feature Additions (Kernel) ===

  * Improved operation when in direct I/O mode: better pagein/pageout failure handling; cached file size purged appropriately upon writes; execution denial when direct I/O enabled.
  * Improved permissions handling that can adaptively take input from the kernel, the kernel part of MacFUSE, and user-space file systems.
  * Improved extended attributes handling that can adaptively take input from the kernel, the kernel part of MacFUSE, and user-space file systems.
  * Improved handling of resource forks--can be handled entirely through Apple Double files, entirely through extended attributes, or a mix thereof.
  * Support for "large" resource forks (and large extended attributes in general). Default sane upper limit (compile-time) is 4MB.
  * Mounting behavior is now always synchronous. That is, mount processing in the kernel now waits (with a timeout) for user space to respond before returning success. This means calls such as `statfs`/`statvfs` don't have to cook up any fake data in the window in which programs (particularly the Finder) want to query the volume before user space has responded.
  * Rewritten, finer grained device layer locking.
  * Improved vnode revocation and triggers for such revocation.
  * Improved dead file system (deadfs) shim built into MacFUSE.
  * Added generation number propagation.
  * Added support for message queueing at either the head or the tail of the kernel-user pipe.
  * Improved `mmap` handling, with fault tolerant file handle fetching.
  * Improved I/O handling in the case where vnop_strategy has to retrieve a file handle at the "last moment" (`execve`, asynchronous I/O, and possibly `mmap` paths).
  * Randomly generated "secrets" shared between the `/dev/fuseN` device opener and the file system mounter (the two can be separate processes or the same process).
  * Root vnode now cached in the private mount data.
  * Optional preflight authorization for the case where we fetch a file handle without a preceding open call.
  * Optional negative name caching.
  * Optional munging of the file system type name in the kernel (allows user-space file systems to use their own file system bundles).
  * Improved authorization of sensitive mount-time options such as `allow_other` and `allow_root`.
  * New mechanism for per-file buffer cache purging; can be used by user-space file systems.
  * Support for custom killing of IPC tickets (`FT_KILL`).
  * Support for "canfail" (non-panic'ing) versions of memory allocation and IPC parameter packing calls.

=== Improvements and Feature Additions (User Space) ===

  * Custom volume icon support is now provided through a _stack module_ in the user-space library.
  * User-space library now based on FUSE library version 2.7.1, with several improvements and new features such as _module stacking_.
  * Improved termination behavior in the user-space library--things should clean up better and several unmount/exit-time issues should no longer occur.
  * The user-space library now uses a custom (POSIX-like) implementation of semaphores that's better suited to MacFUSE.
  * Improved Darwin-specific abstraction in the user-space library. Code factored out to `fuse_darwin.c`, `fuse_darwin.h`, and `mount_darwin.c`. Darwin-specific features available to third parties accessible through `fuse_darwin.h`.
  * The pass-through file system (xmp) has been overhauled for MacFUSE to be a reference file system. In particular, it has more extensive support for resource forks and extended attributes in general.
  * `mount_fusefs` now dynamically looks up file system personalities in the on-disk `Info.plist` file; has fuzzy match support for heuristic matching of a file system type to the exec path of a file system daemon.

=== Performance and Resource Consumption ===

  * Greatly reduced kernel memory consumption. Proactive memory freeing triggered when giant buffers are detected.
  * Logic overhauling and redundancy analysis used to reduce the number of certain calls (such as `vnop_access`) in highly trafficked paths.

=== Bugfixes (Kernel) ===

  * Fixed `mmap` descriptor-type mismatch issue.
  * Fixed an erroneous delete/rename-time kauth check.
  * Fixed a leak in vnode destruction code.
  * Fixed a termination-time race in the kernel.
  * Fixed an issue where the size of a newly created directory wasn't immediately available in the vnode's attributes.
  * Fixed a file handle race that occurred in user space but due to a non-blocking operation by the kernel.
  * Fixed `vnode_iterate` deadlock at unmount time.
  * Fixed a `realloc` panic.
  * Fixed parent ID issue for the root vnode.
  * Fixed issue when file handle tracking would be out of whack (non-fatal) if a file system died abruptly.
  * Fixed locking issue with vnode printing.
  * Fixed `fsync` behavior to be synchronous when appropriate.
  * Fixed deadlock because of a bug in the deadfs shim.
  * Fixed a bug in the handling of per-vnode noncached I/O.

=== Bugfixes (User Space) ===

  * Fixed an issue with the user-space daemon not exiting upon certain failed mount attempts.
  * Fixed thread cancelation issues in the user-space library.
  * Fixed an issue with the unmount code in the user-space library depending on the mount path alone.
  * Fixed issue with Python bindings not loading with the bleeding edge version of MacFUSE.

=== Introspection and Debugging Support ===

  * Added debugging control for printing all vnodes for a given mount.
  * Added debugging control for "hard killing" a MacFUSE volume.
  * More detailed log messages (with vnode names in some cases).
  * Several counters, resource usage statistics, and tunable variables accessible through the sysctl interface. (Try `sysctl macfuse`)

=== New/Updated Documentation ===

  * Mount-Time Options (http://code.google.com/p/macfuse/wiki/OPTIONS)
  * FAQ (http://code.google.com/p/macfuse/wiki/FAQ)
  * HOWTO (http://code.google.com/p/macfuse/wiki/HOWTO)

=== Build and Packaging Improvements ===

  * Much simplified compilation and package building: a single command can build all components into a ready-to-install package. Unified and simplified configuration scripts now available for both core MacFUSE components as well as file systems such as sshfs.
  * Improved packaging. Note that the MacFUSE disk image name now includes the OS version.
  * Cleaner project structure as visible in Xcode. Leopard version done in Xcode 3.x.

=== Specific File Systems ===

  * Several improvements and bugfixes for sshfs.
  * procfs overhauled; now Leopard-only.

== MacFUSE 0.4.0 (June 5, 2007) ==

  * Support for custom volume icons in the user-space library (see [CUSTOM_VOLUME_ICON] for details). You can specify a volume icon through the new `volicon` option.

  * The installation or upgrading of MacFUSE will no longer prompt for a system restart. Note that a restart was never _required_--it was only _recommended_ (you could, if you wanted to, close the Installer window instead of clicking on the `Restart` button). The MacFUSE kernel extension can be unloaded/loaded dynamically, so a restart doesn't have to be a requirement. However, if a MacFUSE volume is mounted when you upgrade MacFUSE, a subsequent mount will not work with the older kernel extension that's in kernel memory and can't be unloaded because it's busy. The new behavior is for `load_fusefs` to try to dynamically unload the old kernel extension if possible. If such unloading succeeds (or if it wasn't needed because nothing old was loaded), then everything is good. If the unloading fails, you will now see a warning dialog that tells you to either eject all currently mounted MacFUSE volumes or to restart the system.

  * New option `defer_auth` that causes MacFUSE to use a permissions handling model in which neither MacFUSE nor the local kernel will attempt to handle permissions. Regardless of ownership and as-seen permissions, operations will initially go through to the file system daemon, and it's up to the daemon to do what it pleases. For example, in the case of sshfs, no matter what uid, gid, or permissions you see, what happens eventually upon a file operation will depend on what the SFTP server does.

  * The `allow_root` option, whose handling was disabled until now, can now be used. Only a user who is a member of the MacFUSE Admin Group can use this option. The superuser can designate any single group id as the MacFUSE Admin Group--through the `sysctl` command (the specific sysctl variable to set is `macfuse.tunables.admin_group`). Note that by default, this variable contains the group ID of `admin` group on Mac OS X. The use of `allow_root` is *strongly discouraged* as it can make the system considerably more vulnerable to security threats.

  * The timeout alert panel now also covers the pre-init case, that is, the case of the in-kernel wait for the asynchronous user-kernel FUSE_INIT handshake timing out. This requires a thread callout in the kernel.

  * Fix for a rare (but possible) unmount-time hang. The same fix also fixes a rare (but possible) NULL-pointer dereference in the kernel.

  * The locations of where things are installed have changed. The kernel extension (`fusefs.kext`) is no longer installed under `/Library/Extensions/`. Instead, the file system bundle (`/System/Library/Filesystems/fusefs.fs/`) now contains everything "under one roof" (except the user-space library). Moreover, `fusefs.fs` now contains a `Support/` subdirectory that in turn contains `fusefs.kext`, `load_fusefs`, `mount_fusefs`, and the uninstall script (`uninstall-macfuse-core.sh`).

== MacFUSE 0.3.0 (May 7, 2007) ==

  * User-space FUSE library updated to version 2.6.5 of FUSE.

  * Minor fix to the user-space FUSE library to deal better with a missing mount-point argument.

  * "Not responding" alert panel default timeout changed to 20 seconds (up from 10 seconds). Some reorganization of the alert panel.

  * The `noauthopaque` and `noauthopaqueaccess` options are now deprecated. MacFUSE will now use an adaptive approach to determining whether a given file system daemon implements the `access()` method, and based on the outcome, MacFUSE will use the appropriate permissions handling.

  * Fix for dealing with an issue regarding "remote" (unbeknownst to MacFUSE) deletion of a file.

  * Fix for one condition that can lead to the "vnode reclaimed with valid fufh" kernel panic.

  * Miscellaneous tweakings.

  * Although not part of MacFUSE Core, there is an updated version of the sshfs file system available with several critical changes. For details, see [MACFUSE_FS_SSHFS].

== MacFUSE 0.2.5 (April 19, 2007) ==

  * Alert panel for displaying file system daemon timeouts

  Details: A common complaint of MacFUSE users (especially those using sshfs) is that the Finder, and sometimes other parts of the Mac OS X user interface, do not handle disruption in network connectivity well. Since version 0.1.9, MacFUSE has had the `daemon_timeout` option, which can be used to specify a timeout for the user-space file system to respond. If the kernel doesn't hear back from the daemon within that time, it will mark the file system as "dead". This will stop the Finder from "beachballing", but will also eject the volume instantly. To be more precise, it will arrange for the volume to be ejected. If you didn't specify the `daemon_timeout` option, the kernel would wait forever, although you can still kill the daemon or forcibly unmount the volume. MacFUSE 0.2.5 makes the situation more flexible. Now, there is a `daemon_timeout` (10 seconds) to begin with. If the daemon hasn't responded for that time, the kernel will show an alert dialog giving the user two choices: "Continue to Wait" or "Eject". Choosing the former will make the dialog disappear and the kernel will wait until either the daemon resumes responding or there's another timeout, at which point it will show the dialog again. Choosing "Eject" will arrange for the volume to be ejected instantly. The alert dialog itself has a timeout. If the user doesn't choose within some time (20 seconds), the dialog will disappear and the kernel will assume "Continue to Wait".

  * Killing the file system daemon after unmount

  Details: After a successful unmount, sometimes (or often, depending on the circumstances) the user-space file system daemon doesn't exit, but continues to "hang around". The hang is benign in that you can easily get rid of the daemon (send it a `SIGABRT` or `SIGKILL`), but it's annoying nevertheless. The reason for this hang is the less than stellar behavior of Pthread cancellation on Mac OS X (and the FUSE library's dependence on `pthread_cancel()` and such). This is nontrivial to fix. MacFUSE 0.2.5 introduces a new option `kill_on_unmount`. If this option is specified, the kernel would send a `SIGKILL` to the daemon as the very last step of unmounting. This isn't so bad because before this, the kernel sends a synchronous `FUSE_DESTROY` message to the daemon, so the latter will still have an opportunity to shut things down gracefully.

  * Ping Disk Arbitration by default

  Details: MacFUSE 0.2.5 pings Disk Arbitration by default (that is, it acts as if the `ping_diskarb` option was specified on the command line). For backward compatibility, you can still specify `ping_diskarb`. Conversely, if you do NOT want Disk Arbitration to be pinged, you now have to explicitly specify a new option: `noping_diskarb`.

  * Default format string for file systems with unspecified subtype
 
  Details: If a user-space file system daemon does not specify its subtype, and if the type cannot be inferred by the MacFUSE mount utility, MacFUSE will now use the string "Generic MacFUSE File System (MacFUSE)" instead of letting the Finder show the volume as of an unknown format.

  * `__asm__` no longer redefined in the FUSE library

  Details: As a hack to get things working cheaply on Mac OS X, I had originally redefined `__asm__(x)` to nothing because the FUSE user library uses `__asm__` with the ".symver" directive, which isn't available on Mac OS X. This is fine if the user file system daemon doesn't need to use `__asm__` itself (unlikely). The daemon could include other headers that have `__asm__` in there somewhere. In any case, redefining `__asm__` is ugly, so the code no longer does that and uses other changes.

== MacFUSE 0.2.4 (April 9, 2007) ==

  * direct_io now supports both reads and writes. The "direct" write code path has not been tested in this release.

  * In the previous release, with direct_io, a read would return no data if the advertized file size was 0 bytes. This release removes file size check for direct_io, which means that a synthetic file system can simply return 0 as the file size.

  * O_CREAT was incorrectly stripped out as an open() call went up to user space--it no longer.

  * Since the FUSE API does not provide for renaming a volume, MacFUSE no longer lets a volume's name be edited (in the Finder, for example). The previous behavior usually led to confusion as a successful rename was in-memory only. 

  * Improved vnode revocation behavior when files disappear behind the scenes.

  * MacFUSE will now send a synchronous FUSE_FLUSH message at close time to the user file system daemon.

  * Miscellaneous code cleanup.

== MacFUSE 0.2.3 ==

  * There was no 0.2.3 release.

== MacFUSE 0.2.2 (February 25, 2007) ==

  * Fixed a bug which, depending upon the size of a file being read, and the user/kernel buffer sizes involved, could lead to the tail of the read data being zeroed.

  * Fixed a bug that could trigger the "vnode reclaimed with valid fufh" panic.

  * Added a workaround allowing better Finder support for copying files and folders to an ACL-enabled MacFUSE volume. Note that even with this workaround, there are some remaining Finder issues on ACL-enabled volumes.

  * New option: 'noapplespecial'. When enabled, Apple Double files ("._") and .DS_Store files will become inaccessible/invisible/un-creatable within a MacFUSE mount. You won't even see them in a directory listing. You will also not be able to create a file or directory that begins with "._" (except for the 2-character literal name "._" itself). I personally am not too excited about this option, but here it is in case somebody wants to experiment. I haven't tested this, especially in how it might affect the Finder and other applications. Use at your own peril.

  * New option: 'nosynconclose'. Requires 'nosyncwrites'. Unless you understand exactly what it does, please don't use it. If you have to ask what it does, please don't use it.

== MacFUSE 0.2.1 (February 15, 2007) ==

  * In MacFUSE 0.2.0, the 'volname' option erroneously got "merged" with the 'extended_security' option (if you set one, you incorrectly get the other). Since 'extended_security' is more experimental in nature currently, it shouldn't be enabled every time you use 'volname'. This is a minor release to fix this issue.

== MacFUSE 0.2.0 (February 11, 2007) ==

  * New option: 'novncache'.

  Details: The new mount option 'novncache' can be used to turn off VFS name caching (name -> vnode lookups) in the kernel. This is useful when you want lookup operations to go to the file system daemon every time. This is useful in conjunction with the existing 'noubc' and 'noreadahead' options. So, if you use the combination '-onovncache,noubc,noreadahead', you should have a mount that will bypass most of the fcaching and go to the daemon every time. Of course, this would be slower. NOTE that if you're dealing with 32-bit executables, the situation is a bit more complex because of the "Task Working Set" caching mechanism in Mac OS X.

  * New option: 'nolocalcaches'.

  Details: 'nolocalcaches' is a meta option that is equivalent to 'noreadahead,noubc,novncache'. In particular, you can use '-onolocalcaches' along with the sshfs option '-ocache=no' to get file system behavior wherein most calls go to the server every time, resulting in a more up-to-date view of the remote file system, albeit with some overhead.

  * New option: 'direct_io'.

  Details: The 'direct_io' mount option from Linux FUSE is now supported. This option can be used both at a file level or for the entire mount. To use it at a file level, your file system daemon should set the direct_io field of the fuse_file_info structure to 1 in the open() method. To use it for the entire mount, specify it as a mount-time option. 'direct_io' implies 'novncache', 'noubc', 'noreadahead' for the file (vnode) in question. Additionally, it forces the file system to be written synchronously ('nosyncwrites' is disabled for the /entire mount/, not just the file in question). But what does this option do (besides altering these above options)? Well, on Mac OS X, it introduces another read path from the kernel to the MacFUSE file system daemon. The new path does not go through the buffer cache (or the cluster layer). This allows you to specify one file size in the getattr() method and supply /less/ data in the read() method. Without the 'direct_io' option, MacFUSE will pad the missing data with zeros and return success. With the 'direct_io' option, MacFUSE will simply return the 'short' data and the read() call will not fail. This is useful when you don't know the size of the data for one reason or another (it's expensive to compute the size; it's not really possible to compute the size because you're streaming the data; etc.) Please NOTE: if an application insists on wanting the exact amount of data that you advertised in getattr(), 'direct_io' can't do anything about that, of course. The Finder is one such application.

  * Improved MacFUSE version tracking.

  Details: The MacFUSE kernel extension now logs a version message when you load it. The message is of the form:

  MacFUSE: starting (version 0.2.0, Feb 10 2007, 10:34:26)

  The date/time shown is a build timestamp. You can also view the version of a loaded MacFUSE kernel extension by using the sysctl command from the Terminal (just type 'sysctl macfuse' on the command line). This will allow a better approximation of which build you are running. Additionally, the mount_fusefs command now checks the version of the loaded fusefs.kext and bails out (by default) if there's a version mismatch between itself and the kext. If you really must, you can override this behavior by setting the MOUNT_FUSEFS_IGNORE_VERSION_MISMATCH environment variable.

  * Advanced 'reverse' (user->kernel) interface for file system daemons.

  Details: There's a preliminary advanced interface that file systems can use (don't use it just yet, unless you know exactly what you're doing and why) to do some weird things like: mark an existing vnode as "gone" (a variant of the revoke() system call), purge a node's in-kernel attribute cache, VFS name cache, or UBC. This interface will certainly change and evolve in future, so please don't create any dependencies on it yet.

  * Paremetrized the upper limit on the size of an extended attribute that you can set on files in a MacFUSE file system.

   Details: The limit (FUSE_MAXATTRIBUTESIZE) is defined in fusefs/common/fuse_param.h, and is 128KB by default. This matters because if you want to support _writing_ larger extended attributes, you will need to tweak this parameter and recompile fusefs.kext. The 128KB value is not ad-hoc. The FUSE user-space library has an upper limit (approximately 128KB) on the size of the kernel channel" buffer--you will _also_ have to increase this limit and recompile the user-space library (see MIN_BUFSIZE in fuse_kern_chan.c). Besides, the following points apply to extended attribute sizes in Mac OS X:
  - HFS+ supports a maximum inline attribute size of 3802 bytes.
  - However, HFS+ does support arbitrary sizes for resource forks, even though a resource fork is advertised as an extended attribute ("com.apple.resourceFork"). It's not a "real" extended attribute though--HFS+ intercepts this one and handles it itself.
  - The extended attribute handling code in the xnu kernel has an upper limit of 128KB on extended attribute data.

  * Better support for extended attributes in general.

  Details: MacFUSE now tries to be rather clever when dealing with extended attributes. If a user-space file system implements xattr functions, MacFUSE will pass on { get, list, remove, set }xattr() calls to user space. There are 2 exceptions to this: if the extended attributes happen to be those corresponding to Finder Info or Resource Forks. The reason for this: well, since regular extended attributes are subject to an upper limit (128KB by default), if we want arbitrary size resource forks, we have to treat them differently (like HFS+ does). MacFUSE treats them differently by telling the kernel to store them as Apple Double ("._") files. MacFUSE will also cause other attributes to be stored in Apple Double files if the file system daemon doesn't implement setxattr(). In fact, MacFUSE "learns" on the very first setxattr() call if the daemon implements this method or not--based on the return value. If the daemon doesn't implement the call, future setxattr() calls will not even go to user space: they will be short-circuited in the kernel, which will use Apple Double files. One noteworthy point here is that the kernel's generic xattr handling code (specifically the part that deals with Apple Double files) requires file locking (the O_EXLOCK flag to open) to work. This brings us to the next changelog item.

  * Support for advisory locking.

  Details: Actually, MacFUSE always "had" advisory locking support. A file system in Mac OS X can get such locking for free by simply setting a flag. Unfortunately, Apple "forgot" to export this flag (rather, the function that sets this flag). Therefore, kernel extensions currently cannot set this flag without some sort of a kludge. Since advisory locking is rather critical now because extended attributes support requires it, I've decided to turn this flag on through cheap kludgy means (hardcoding the offset of a field in an Apple-private data structure). On the bright side, this means extended attributes will work nicely and you have locking available. On the flip side, if the aforementioned offset ever changes suddenly in a Mac OS X release, you might have a kernel panic :-) Apple really needs to export this function.

  * Support for Mac OS X Extended Security (Access Control Lists), new option: 'extended_security'.

  Details: You can now pass the 'extended_security' option at mount-time to enable support for ACLs on a MacFUSE file system. The ACLs that you get are identical to those in HFS+, except that they are stored in Apple Double ("._") files instead of being stored in the HFS+ attributes B-Tree. Of course, you can use the same commands ("chmod +a 'singh deny read'", "ls -le", etc.) to work with these ACLs. See the man page of chmod for details. IMPORTANT: If you want the kernel to *honor* these ACLs while accessing the file system, you also need to pass the 'noauthopaque' option at mount time. Without this option, the kernel will try to talk to the user-space daemon for authorizations. CAVEAT: The Apple Double files used to store ACLs have the default owner, group, permissions as a normal file would.

  * Support for the kqueue/kevent notification mechanism.

  Details: MacFUSE now implements the necessary kernel functions for supporting the kqueue/kevent kernel event notification mechanism. See kqueue(2) on how you can use kqueue() and kevent() to use this mechanism on a MacFUSE file system. NOTE that implementing this mechanism in the kernel requires using unsupported Apple programming interfaces, which means that in future, it is possible that some revision of Mac OS X will not let this work. Therefore, the entire kqueue/kevent support in MacFUSE is a compile-time option that's conrolled by the MACFUSE_ENABLE_UNSUPPORTED macro in fusefs/common/fuse_param.h.

  * Improved support for asynchronous writes (the 'nosyncwrites' option).

  Details: Heh, I "improved" support for the 'nosyncwrites' option in at least two earlier releases, but I keep forgetting some detail. I'll need to explain the MacFUSE architecture to clarify why this is a bit tricky, but suffice it to say that asynchronous writes are never as easy on a "distributed"/"remote" file system as they are on a "local" file system. Unlike NFS on Mac OS X, MacFUSE doesn't have a special-purpose buffer cache either. That said, 'nosyncwrites' now follows sync-on-close semantics. As long as you have a file open, writes are asynchronous, but when you close the file, MacFUSE will sync it.

  * Statistics available through the sysctl interface: values of some in-kernel counters and constants can be seen through the sysctl interface (try "sysctl macfuse" on the command line).

  * Fixed a rather bad accounting bug that caused a certain type of MacFUSE-allocated memory to be not freed until the time you unmounted the MacFUSE volume.

  * User-Space library updated to FUSE 2.6.3.

  * Miscellaneous Improvements: many parts of the kernel extension have been tweaked and improved.

== MacFUSE 0.1.9 (January 28, 2007) ==

  * The installer package does a better job of cleaning up previously installed MacFUSE files.

  * There is now a check that we are installing on at least a 10.4 system.

  * There is an uninstall program (/System/Library/Filesystems/fusefs.fs/uninstall-macfuse-core.sh).

  * Fixed a potential kernel panic while unmounting forcibly.

  * Fixed a kernel panic that could be triggered at vnode-reclaim time if MacFUSE didn't validate the type of the vnode at vnode-creation time.

  * The user-space library has better termination behavior.

    Details: It handles SIGTERM/SIGINT hopefully properly now, and will try to automatically unmount the file system under most circumstances. Even when a file system daemon misbehaves and refuses to cooperate during termination, you should be able to force-quit the daemon and unmounting should proceed. Overall, this should result in much better experience, especially during file system development (when your daemons might be dying and misbehaving all the time).

  * There is improved support for operation without buffer caching (the 'noubc' option).

  * There is improved support for asynchronous writes (the 'nosyncwrites' option).

  * The 'nosyncwrites' option is now mutually exclusive with the 'noubc' and 'noreadahead' options.

  * mount_fusefs now sends notifications to OS X's distributed notification center as a file system is being mounted.

    Details: There is one notification sent right after a successful mount, one after the file system has initialized (the daemon has acknowledged FUSE_INIT), and another if there has been a timeout waiting for the file system to initialize. All these notifications are sent for an object called "com.google.filesystems.fusefs.unotifications". There is also a user-data dictionary in each notification. The dictionary at least contains the mount-path in question. See fusefs/common/fuse_mount.h for the names of these notification, etc. To learn how to receive these notifications, see the documentation for CFNotificationCenterAddObserver().

  * There is a new option ('init_timeout') that can be used to specify how long mount_fusefs to wait for the file system to initialize/stabilize (basically, for the daemon to send a response to FUSE_INIT).

    Details: By default, init_timeout is 10 seconds. If the file system does initialize within this time, mount_fusefs will ping Disk Arbitration (if the 'ping_diskarb' option was specified) *and* send the "inited" notification to the distributed notification center. If there is a timeout, mount_fusefs will *not* ping Disk Arbitrarion (even if the 'ping_diskarb' option was specified) *and* will send the "inittimedout" notification. Helper programs can use this mechanism to decide if they need to do any cleanup etc.

  * There is a new option ('daemon_timeout') that lets you specify a timeout in seconds for the kernel to wait for the user file system daemon to respond (for any message).

    Details: If the daemon fails to respond within this time, the kernel marks the file system as "dead". By default, there is no timeout -- the kernel will wait indefinitely (unless you kill the file system daemon yourself). This should stop the Finder from "beachballing" -- BUT AT THE COST OF EJECTING YOUR VOLUME REGARDLESS OF WHETHER YOU HAVE FILES OPEN IN THAT VOLUME. There will be a VFS-level kernel notification sent out that causes the Finder to eject the volume (remember to use the 'ping_diskarb' option). This ejection is /forced/ -- if you have files open when the file system became "dead", they will be unceremoniously ignored. The alternative (you can modify the source to do so) is to not eject forcibly if files were open. Since the file system is dead, it's not like you would be able to "save" them -- it's just that you will have to eject it later manually after you've "closed" those files. An even better alternative would be to have support from going back-and-forth between "dead" and "alive" states (based on a network connection coming and going, for example) but that's for later. In any case, the goal is that "killing" the file system daemon ("kill <daemon's process ID>") should always work. PLEASE READ THIS CAREFULLY AND USE THIS OPTION WISELY. YOU CAN KILL THE FILE SYSTEM DAEMON WITHOUT HAVING TO RESORT TO THIS OPTION. ONCE YOU KILL THE DAEMON, THE Finder WILL STOP BEACHBALLING TOO.

  * The personality named "NTFS" in the fusefs.fs bundle is now called "NTFS-3g".

    Details: This fixes the problem where Disk Utility and Startup Disk preference pane get confused because the description they are looking for is not found in fusefs.fs's plist.

  * The sshfs.app GUI wrapper has been open sourced.

== MacFUSE 0.1.8 ==

  * There was no 0.1.8 release.

== MacFUSE 0.1.7 (January 22, 2007) ==

  * The file `/usr/local/bin/mount_fusefs` is removed. The `mount_fusefs` in the `fusefs.fs` bundle is the actual binary used by the user-space FUSE library. This obviates the need to have `/usr/local/bin` in your path, making it a bit easier to write fuse file system apps.

  * The MacFUSE kernel extension (kext) has been moved from `/System/Library/Extensions` to `/Library/Extensions`. Dynamically loading the kext on first mount seems to be working well enough, so we don't anticipate a need to load at boot-time. This move will also free us from having to worry about the kext cache.

  * Fix for timestamp issues (See issue #33).

  * Fixed a problem with 64-bit file offsets that was causing issues with files greater than 4GB.

  * `mount_fusefs` will no longer automatically append a `"@%d"` (`%d` being the MacFUSE device number) to the fsname. This is for the benefit of those running ntfs-3g with disk utility.

  * Improved support for the `ping_diskarb` mount option (See issue #10). The `mount_fusefs` program with the `ping_diskarb` option now waits for the file system to initialize before notifying Disk Arbitration that the mount occurred. Currently it will wait for up to 6 seconds at most and then cancel the "ping" if the file system does not initialize within that time.

  * The `mount_fusefs` program will wait for the file system to initialize (similar to the `ping_diskarb` case above).  It will then send the notification `"com.google.filesystems.fusefs.unotifications.mounted"` with a string containing the mount path as the object to the distributed notification center.  This is so that projects like MacFUSE ntfs-3g can create their own mount wrapper that waits until the file system is initialized before exiting.

  * Support for operation with buffer cache and readahead turned off for the cases where the "remote" file size is changing without the local file system's knowledge.

  * From now on, no more tarballs. We'll only have package installers.

  * The versioning scheme has changed to the simpler form `x.y.z`.

== MacFUSE 0.1.0b006 (January 14, 2007) ==

  * First installer DMG.

== MacFUSE 0.1.0b005 (January 11, 2007) ==

  * Minor bugfix revision.

== MacFUSE 0.1.0b004 (January 9, 2007) ==

  * Initial binary release.
