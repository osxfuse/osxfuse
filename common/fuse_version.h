/*
 * Copyright (c) 2006-2008 Amit Singh/Google Inc.
 * Copyright (c) 2010 Tuxera Inc.
 * Copyright (c) 2011-2013 Benjamin Fleischer
 * All rights reserved.
 */

#ifndef _FUSE_VERSION_H_
#define _FUSE_VERSION_H_


/* Count macro arguments */

#define _N_ARGS_REVERSE_SEQUENCE 8, 7, 6, 5, 4, 3, 2, 1, 0
#define _N_ARGS_N(_1, _2, _3, _4, _5, _6, _7, _8, N, ...) N

#define _N_ARGS(...) _N_ARGS_N(__VA_ARGS__)
#define N_ARGS(...) _N_ARGS(__VA_ARGS__, _N_ARGS_REVERSE_SEQUENCE)


/* Macro indirection */

/* Expands arguments before invoking macro */
#define CALL(macro, ...) macro(__VA_ARGS__)


/* Concatenate macros */

#define CONCAT_1(_1) \
    _1
#define CONCAT_2(_1, _2) \
    _1##_2
#define CONCAT_3(_1, _2, _3) \
    _1##_2##_3
#define CONCAT_4(_1, _2, _3, _4) \
    _1##_2##_3##_4
#define CONCAT_5(_1, _2, _3, _4, _5) \
    _1##_2##_3##_4##_5
#define CONCAT_6(_1, _2, _3, _4, _5, _6) \
    _1##_2##_3##_4##_5##_6
#define CONCAT_7(_1, _2, _3, _4, _5, _6, _7) \
    _1##_2##_3##_4##_5##_6##_7
#define CONCAT_8(_1, _2, _3, _4, _5, _6, _7, _8) \
    _1##_2##_3##_4##_5##_6##_7##_8

#define CONCAT_N(n) CONCAT_##n

/* Concatenates up to eight arguments */
#define CONCAT(...) CALL(CALL(CONCAT_N, N_ARGS(__VA_ARGS__)), __VA_ARGS__)


/* Stringify */

#define OSXFUSE_STRINGIFY(s)         OSXFUSE_STRINGIFY_BACKEND(s)
#define OSXFUSE_STRINGIFY_BACKEND(s) #s


/* Add things here. */

#define OSXFUSE_NAME_LITERAL osxfuse
#define OSXFUSE_NAME         OSXFUSE_STRINGIFY(OSXFUSE_NAME_LITERAL)

#define OSXFUSE_DISPLAY_NAME_LITERAL OSXFUSE
#define OSXFUSE_DISPLAY_NAME         OSXFUSE_STRINGIFY(OSXFUSE_DISPLAY_NAME_LITERAL)

#define OSXFUSE_FS_TYPE_LITERAL OSXFUSE_NAME_LITERAL
#define OSXFUSE_FS_TYPE         OSXFUSE_STRINGIFY(OSXFUSE_FS_TYPE_LITERAL)

#define OSXFUSE_FSTYPENAME_PREFIX OSXFUSE_FS_TYPE "_"

#define OSXFUSE_IDENTIFIER_LITERAL com.github.osxfuse
#define OSXFUSE_IDENTIFIER OSXFUSE_STRINGIFY(OSXFUSE_IDENTIFIER_LITERAL)

#define OSXFUSE_BUNDLE_IDENTIFIER_LITERAL \
        OSXFUSE_IDENTIFIER_LITERAL.filesystems.OSXFUSE_NAME_LITERAL
#define OSXFUSE_BUNDLE_IDENTIFIER \
        OSXFUSE_STRINGIFY(OSXFUSE_BUNDLE_IDENTIFIER_LITERAL)

#define OSXFUSE_TIMESTAMP __DATE__ ", " __TIME__

#define OSXFUSE_VERSION_LITERAL 2.9.7
#define OSXFUSE_VERSION         OSXFUSE_STRINGIFY(OSXFUSE_VERSION_LITERAL)

#define FUSE_KPI_GEQ(M, m) \
    (FUSE_KERNEL_VERSION > (M) || \
    (FUSE_KERNEL_VERSION == (M) && FUSE_KERNEL_MINOR_VERSION >= (m)))

#endif /* _FUSE_VERSION_H_ */
