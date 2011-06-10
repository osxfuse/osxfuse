#!/bin/sh
#
# Copyright (C) 2006 Google. All Rights Reserved.
#
# Uninstalls the "MacFUSE Core.pkg".

INSTALL_VOLUME="/"

LOG_SYSLOG=1
LOG_STDOUT=1
function log() {
  local msg="$1"
  if [ $LOG_SYSLOG -eq 1 ]
  then
    syslog -l Notice -s "MacFUSE Uninstaller: $msg"
  fi
  if [ $LOG_STDOUT -eq 1 ]
  then
    echo "MacFUSE Uninstaller: $msg"
  fi
}

# Check to make sure that operations (such as rm, rmdir) are relatively
# safe. This should only allow operations throught that would operate on
# stuff installed by MacFUSE.
#
# Ret: 1 (true) if the prefix is ok to use, otherwise 0 (false).
function is_safe_prefix() {
  local path="$1"
  case "$path" in
    "$INSTALL_VOLUME"/./usr/local/lib/pkgconfig)
      # We don't try to remove the pkgconfig directory.
      return 0;
      ;; 
    "$INSTALL_VOLUME"/./usr/local/bin/*                        |  \
    "$INSTALL_VOLUME"/./usr/local/lib/*                        |  \
    "$INSTALL_VOLUME"/./usr/local/include/*                    |  \
    "$INSTALL_VOLUME"/./Library/Extensions/fusefs.kext         |  \
    "$INSTALL_VOLUME"/./Library/Extensions/fusefs.kext/*       |  \
    "$INSTALL_VOLUME"/./Library/Filesystems/fusefs.fs          |  \
    "$INSTALL_VOLUME"/./Library/Filesystems/fusefs.fs/*        |  \
    "$INSTALL_VOLUME"/./Library/Frameworks/MacFUSE.framework   |  \
    "$INSTALL_VOLUME"/./Library/Frameworks/MacFUSE.framework/* |  \
    "$INSTALL_VOLUME"/./Library/Application\ Support/Developer/Shared/Xcode/Project\ Templates/* |  \
    "$INSTALL_VOLUME"/Library/Receipts/MacFUSE.pkg             |  \
    "$INSTALL_VOLUME"/Library/Receipts/MacFUSE.pkg/*           |  \
    "$INSTALL_VOLUME"/Library/Receipts/MacFUSE\ Core.pkg       |  \
    "$INSTALL_VOLUME"/Library/Receipts/MacFUSE\ Core.pkg/*)
      # These are all ok to process.
      return 1;
      ;;  
  esac

  return 0;  # Not allowed!
}

# Remove the given file if it seems "safe" to do so.
function remove_file() {
  local path="$1"
  is_safe_prefix "$path"
  local allow=$?
  if [ $allow -ne 1 ]
  then
    # We ignore this file, which is fine.
    log "Ignoring file '$path'"
    return 0;
  fi

  if [ \( ! -e "$path" \) -a \( ! -L "$path" \) ]
  then
    # No longer exists
    log "Skipping file: '$path' since it no longer exists."
    return 0;
  fi

  if [ \( ! -f "$path" \) -a \( ! -L "$path" \) ]
  then
    # This is no longer a file?
    log "Skipping file: '$path' since it is no longer a file or symlink?"
    return 1;
  fi

  log "Removing file: '$path'"
  rm -f "$path"
}

# Remove the given directory if it seems "safe" to do so. This will only remove
# empty directories.
function remove_dir() {
  local path="$1"
  is_safe_prefix "$path"
  local allow=$?
  if [ $allow -ne 1 ]
  then
    # We ignore this directory.
    log "Ignoring dir: '$path'"
    return 0;
  fi

  if [ ! -e "$path" ]
  then
    # No longer exists
    log "Skipping dir: '$path' since it no longer exists."
    return 0;
  fi

  if [ ! -d "$path" ]
  then
    # Not a directory?
    log "Skipping dir: '$path' since it is either gone or no longer a dir."
    return 1;
  fi

  log "Removing dir: '$path'"
  rmdir "$path"
}

# Forcefully remove the given directory tree. This is "rm -rf", so use this routine with caution!
function remove_tree() {
  local path="$1"
  is_safe_prefix "$path"
  local allow=$?
  if [ $allow -ne 1 ]
  then
    # We ignore this tree.
    log "Ignoring tree: '$path'"
    return 0;
  fi

  if [ ! -e "$path" ]
  then
    # No longer exists
    log "Skipping tree: '$path' since it no longer exists."
    return 0;
  fi

  if [ ! -d "$path" ]
  then
    # Not a directory?
    log "Skipping tree: '$path' since it is not a directory."
    return 1;
  fi

  log "Removing tree: '$path'"
  rm -rf "$path"
}

### MAIN

# Set to 1 if at any point it looks like the uninstall did not proceed
# smoothly. If IS_BOTCHED_UNINSTALL then we don't remove the Receipt. 
IS_BOTCHED_UNINSTALL=0

# Do they want quiet mode?
if [ "$1" = "-q" ]
then
  LOG_STDOUT=0
fi

# Make sure this script runs as root
if [ "$EUID" -ne 0 ]
then
  log "Sudoing..."
  sudo $0 "$@"
  exit $?
fi

OS_RELEASE=`/usr/bin/uname -r`
case "$OS_RELEASE" in 
  8*)
    log "Incorrect uninstall. Use the Tiger version please."
    exit 1
    ;;
  9*)
    PACKAGE_RECEIPT="$INSTALL_VOLUME/Library/Receipts/MacFUSE Core.pkg"
    OUTER_PACKAGE_RECEIPT="$INSTALL_VOLUME/Library/Receipts/MacFUSE.pkg"
    BOMFILE="$PACKAGE_RECEIPT/Contents/Archive.bom"
    ;;
  10*)
     PACKAGE_RECEIPT=""
     BOMFILE="$INSTALL_VOLUME/var/db/receipts/com.google.macfuse.core.bom"
     ;;
esac

# Make sure the INSTALL_VOLUME is ok.
if [ ! -d "$INSTALL_VOLUME" ]; then
  log "Install volume '$INSTALL_VOLUME' is not a directory."
  exit 2
fi

# Make sure that MacFUSE Core is installed and the Archive.bom is present.
if [ ! -z "$PACKAGE_RECEIPT" ]
then 
  if [ ! -d "$PACKAGE_RECEIPT" ]
  then
    log "It appears that MacFUSE Core is not installed."
    exit 3
  fi
else
  /usr/sbin/pkgutil --pkg-info com.google.macfuse.core > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    log "It appears that MacFUSE Core is not installed."
    exit 3    
  fi
fi
if [ ! -f "$BOMFILE" ]
then
  log "Can not find the Archive.bom for MacFUSE Core package."
  exit 4
fi

# 1. Try to unload the kext if possible. Best effort, so ignore errors.
kextunload -b com.google.filesystems.fusefs > /dev/null 2>&1

# 2. Remove files and symlinks
OLD_IFS="$IFS"
IFS=$'\n'
for x in `/usr/bin/lsbom -slf "$BOMFILE"` 
do
  remove_file "$INSTALL_VOLUME/$x"
  if [ $? -ne 0 ]
  then
    IS_BOTCHED_UNINSTALL=1
  fi
done
IFS="$OLD_IFS"

# 3. Remove autoinstaller
remove_file "$INSTALL_VOLUME/./Library/Filesystems/fusefs.fs/Support/autoinstall-macfuse-core"

# 4. Remove the directories
OLD_IFS="$IFS"
IFS=$'\n'
for x in `/usr/bin/lsbom -sd "$BOMFILE" | /usr/bin/sort -r`
do
  remove_dir "$INSTALL_VOLUME/$x"
  if [ $? -ne 0 ]
  then
    IS_BOTCHED_UNINSTALL=1
  fi
done
IFS="$OLD_IFS"

# 5. Remove the Receipt.
if [ $IS_BOTCHED_UNINSTALL -eq 0 ]
then
  if [ ! -z "$PACKAGE_RECEIPT" ]
  then
    remove_tree "$PACKAGE_RECEIPT"
    if [ $? -ne 0 ]
    then
      IS_BOTCHED_UNINSTALL=1
    fi
    # Best effort remove of MacFUSE.pkg
    if [ ! -z "$OUTER_PACKAGE_RECEIPT" ]
    then
      remove_tree "$OUTER_PACKAGE_RECEIPT"
    fi
  else 
    /usr/sbin/pkgutil --forget com.google.macfuse.core
    if [ $? -ne 0 ]
    then
      IS_BOTCHED_UNINSTALL=1
    fi
    # Best effort remove of MacFUSE.pkg.
    /usr/sbin/pkgutil --forget com.google.macfuse
  fi
fi

exit $IS_BOTCHED_UNINSTALL
