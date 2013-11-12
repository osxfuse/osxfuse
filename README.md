FUSE for OS X
=============

FUSE for OS X allows you to extend Mac OS X via third party file systems. 

About FUSE for OS X
-------------------

The FUSE for OS X software package provides multiple APIs for developing file systems for Mac OS X 10.5 to 10.9 (Intel and PowerPC architecture). It is a backward compatible successor to [MacFUSE](http://code.google.com/p/macfuse/), which has been the basis of many products, but is no longer being maintained.

You can use the provided APIs to develop numerous types of file systems, whose content can come from a local disk, from across the network, from memory, or any other source. One of these APIs is a superset of the [FUSE API](http://fuse.sourceforge.net/), that originated on Linux.

Due to the fact that FUSE file systems are regular applications (as opposed to kernel extensions), you have just as much flexibility and choice in programming tools, debuggers, and libraries as you have if you were developing standard Mac OS X applications.

For more information visit the website of the [FUSE for OS X Project](http://osxfuse.github.io/).

Build Instructions
------------------

The build script locates automatically all supported installations of Xcode in the top level of the Mac OS X startup volume and the Applications folder. It builds a distribution package compatible with as many versions of OS X as possible (depending on the versions of Xcode that are installed).

* Xcode 3.2: FUSE for OS X can be built for Mac OS X 10.5 to 10.8.

* Xcode 4.0, 4.1, 4.2, 4.3: FUSE for OS X can be built for Mac OS X 10.6 to 10.8.

* Xcode 4.4, 4.5, 4.6: FUSE for OS X can be built for OS X 10.7 and 10.8.

* Xcode 5.0: FUSE for OS X can be built for OS X 10.8

* Xcode 5.0.1: FUSE for OS X can be built for OS X 10.8 and 10.9

---

**Note:**

* Xcode 4.3 and newer versions do not include autotools and libtool, that are needed to build `libosxfuse`. Install MacPorts and run the following command in Terminal to install the required tools:

        sudo port install autoconf automake libtool

* The "Command Line Tools" package is needed to generate BridgeSupport metadata for `OSXFUSE.framework` because of a bug in `gen_bridge_metadata` (hard coded path to `cpp`).

The Xcode tools packages can be obtained from https://developer.apple.com/downloads/ (free Apple Developer ID required).

---

To clone the source repository into a newly created subdirectory named `osxfuse` in the current working directory, run the following command in Terminal:

    git clone --recursive -b osxfuse-2 git://github.com/osxfuse/osxfuse.git osxfuse

Run the following command in the cloned repository to build FUSE for OS X from source:

    ./build.sh -t dist
