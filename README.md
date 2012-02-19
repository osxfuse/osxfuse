FUSE for OS X
=============

FUSE for OS X allows you to extend Mac OS X via third party file systems. 

About OSXFUSE
-------------

The OSXFUSE software package provides multiple APIs for developing file systems for Mac OS X 10.5, 10.6 and 10.7  (Intel and PowerPC architecture). It is a backward compatible successor to [MacFUSE](http://code.google.com/p/macfuse/), which has been the basis of many products, but is no longer being maintained.

You can use the provided APIs to develop numerous types of file systems, whose content can come from a local disk, from across the network, from memory, or any other source. One of these APIs is a superset of the [FUSE API](http://fuse.sourceforge.net/), that originated on Linux.

Due to the fact that OSXFUSE file systems are regular applications (as opposed to kernel extensions), you have just as much flexibility and choice in programming tools, debuggers, and libraries as you have if you were developing standard Mac OS X applications.

For more information visit the [website of the OSXFUSE project](http://osxfuse.github.com/).

Build Instructions
------------------

To clone the source repository into a newly created subdirectory named `osxfuse` of the current working directory, run the following commands in Terminal:

    git clone git://github.com/osxfuse/osxfuse.git osxfuse
    cd osxfuse
    git submodule update --init

The build script locates automatically all supported installations of Xcode in the top level of the Mac OS X startup volume and builds a distribution package compatible with as many versions of Mac OS X as possible (depending on the versions of Xcode that are installed).

* Building OSXFUSE on Mac OS X 10.6:
  - Building OSXFUSE for Mac OS X 10.5 requires Xcode 3.2
  - Building OSXFUSE for Mac OS X 10.6 requires either Xcode 3.2 or Xcode 4.0
  - Building OSXFUSE for Mac OS X 10.7 is not supported
* Building OSXFUSE on Mac OS X 10.7:
  - Building OSXFUSE for Mac OS X 10.5 requires Xcode 3.2
  - Building OSXFUSE for Mac OS X 10.6 requires either Xcode 3.2, Xcode 4.1 or Xcode 4.2
  - Building OSXFUSE for Mac OS X 10.7 requires either Xcode 4.1 or Xcode 4.2

Run the following command in the cloned repository to build OSXFUSE from source:

    OSXFUSE_PRIVATE_KEY=prefpane/autoinstaller/TestKeys/private_key.der ./build.sh -t dist

Note: The specified test key is used to sign the file `CurrentRelease.plist` or `DeveloperRelease.plist` (in case of a beta release). These files represent the server-side of the update mechanism. Using a different private key has no impact on the resulting binaries or the ability to update OSXFUSE.
