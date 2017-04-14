/*
 * Copyright (c) 2006-2008 Amit Singh/Google Inc.
 * Copyright (c) 2010 Tuxera Inc.
 * Copyright (c) 2011-2016 Benjamin Fleischer
 * All rights reserved.
 */

#ifndef _FUSE_VERSION_H_
#define _FUSE_VERSION_H_

#include <fuse_preprocessor.h>

/* File system name */

#define OSXFUSE_NAME_LITERAL                osxfuse
#define OSXFUSE_DISPLAY_NAME_LITERAL        OSXFUSE

#define OSXFUSE_NAME                        FUSE_PP_STRINGIFY(OSXFUSE_NAME_LITERAL)
#define OSXFUSE_DISPLAY_NAME                FUSE_PP_STRINGIFY(OSXFUSE_DISPLAY_NAME_LITERAL)

/* Identifier */

#define OSXFUSE_IDENTIFIER_LITERAL          com.github.osxfuse
#define OSXFUSE_BUNDLE_IDENTIFIER_LITERAL   OSXFUSE_IDENTIFIER_LITERAL.filesystems.OSXFUSE_NAME_LITERAL

#define OSXFUSE_IDENTIFIER                  FUSE_PP_STRINGIFY(OSXFUSE_IDENTIFIER_LITERAL)
#define OSXFUSE_BUNDLE_IDENTIFIER           FUSE_PP_STRINGIFY(OSXFUSE_BUNDLE_IDENTIFIER_LITERAL)

/* Version */

#define OSXFUSE_VERSION_LITERAL             3.5.7
#define OSXFUSE_TIMESTAMP                   __DATE__ ", " __TIME__

#define OSXFUSE_VERSION                     FUSE_PP_STRINGIFY(OSXFUSE_VERSION_LITERAL)

/* File system type */

#define OSXFUSE_TYPE_NAME_PREFIX            OSXFUSE_NAME "_"

/* Volume name */

#define OSXFUSE_VOLNAME_FORMAT              OSXFUSE_DISPLAY_NAME " Volume %d"
#define OSXFUSE_VOLNAME_DAEMON_FORMAT       OSXFUSE_DISPLAY_NAME " Volume %d (%s)"

#endif /* _FUSE_VERSION_H_ */
