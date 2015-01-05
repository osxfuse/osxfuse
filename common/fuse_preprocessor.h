/*
 * Copyright (c) 2015 Benjamin Fleischer
 * All rights reserved.
 */

#ifndef _FUSE_PREPROCESSOR_H_
#define _FUSE_PREPROCESSOR_H_

/*
 * Stringification
 */

#define FUSE_PP_STRINGIFY_I(s) #s

/* Expands to the stringified argument. */
#define FUSE_PP_STRINGIFY(s) FUSE_PP_STRINGIFY_I(s)

/*
 * Count variadic arguments
 */

#define FUSE_PP_VARIADIC_COUNT_I(e00, e01, e02, e03, e04, e05, e06, e07, e08, e09, e10, e11, e12, e13, e14, e15, \
                                 e16, e17, e18, e19, e20, e21, e22, e23, e24, e25, e26, e27, e28, e29, e30, e31, \
                                 e32, e33, e34, e35, e36, e37, e38, e39, e40, e41, e42, e43, e44, e45, e46, e47, \
                                 e48, e49, e50, e51, e52, e53, e54, e55, e56, e57, e58, e59, e60, e61, e62, e63, \
                                 size, ...) size

/*
 * Expands to the number of the variadic arguments passed to it. Supports up to
 * 64 arguments.
 */
#define FUSE_PP_VARIADIC_COUNT(...)                                                              \
        FUSE_PP_VARIADIC_COUNT_I(__VA_ARGS__,                                                    \
                                 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, \
                                 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, \
                                 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, \
                                 16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1)

/*
 * Overload function-like variadic macros
 */

#define FUSE_PP_OVERLOAD_COUNT_I(prefix, count) prefix ## count
#define FUSE_PP_OVERLOAD_COUNT(prefix, count) FUSE_PP_OVERLOAD_COUNT_I(prefix, count)

/*
 * Expands to a the name of a function-like macro with the specified prefix
 * that accepts the given number of arguments.
 */
#define FUSE_PP_OVERLOAD(prefix, ...) FUSE_PP_OVERLOAD_COUNT(prefix, FUSE_PP_VARIADIC_COUNT(__VA_ARGS__))

/*
 * Concatenate expanded arguments
 */

#define FUSE_PP_CAT_I(e0, e1) e0 ## e1

#define FUSE_PP_CAT_1(e0) e0
#define FUSE_PP_CAT_2(e0, e1) FUSE_PP_CAT_I(e0, e1)
#define FUSE_PP_CAT_3(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_2(__VA_ARGS__))
#define FUSE_PP_CAT_4(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_3(__VA_ARGS__))
#define FUSE_PP_CAT_5(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_4(__VA_ARGS__))
#define FUSE_PP_CAT_6(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_5(__VA_ARGS__))
#define FUSE_PP_CAT_7(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_6(__VA_ARGS__))
#define FUSE_PP_CAT_8(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_7(__VA_ARGS__))
#define FUSE_PP_CAT_9(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_8(__VA_ARGS__))
#define FUSE_PP_CAT_10(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_9(__VA_ARGS__))
#define FUSE_PP_CAT_11(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_10(__VA_ARGS__))
#define FUSE_PP_CAT_12(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_11(__VA_ARGS__))
#define FUSE_PP_CAT_13(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_12(__VA_ARGS__))
#define FUSE_PP_CAT_14(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_13(__VA_ARGS__))
#define FUSE_PP_CAT_15(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_14(__VA_ARGS__))
#define FUSE_PP_CAT_16(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_15(__VA_ARGS__))
#define FUSE_PP_CAT_17(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_16(__VA_ARGS__))
#define FUSE_PP_CAT_18(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_17(__VA_ARGS__))
#define FUSE_PP_CAT_19(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_18(__VA_ARGS__))
#define FUSE_PP_CAT_20(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_19(__VA_ARGS__))
#define FUSE_PP_CAT_21(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_20(__VA_ARGS__))
#define FUSE_PP_CAT_22(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_21(__VA_ARGS__))
#define FUSE_PP_CAT_23(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_22(__VA_ARGS__))
#define FUSE_PP_CAT_24(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_23(__VA_ARGS__))
#define FUSE_PP_CAT_25(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_24(__VA_ARGS__))
#define FUSE_PP_CAT_26(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_25(__VA_ARGS__))
#define FUSE_PP_CAT_27(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_26(__VA_ARGS__))
#define FUSE_PP_CAT_28(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_27(__VA_ARGS__))
#define FUSE_PP_CAT_29(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_28(__VA_ARGS__))
#define FUSE_PP_CAT_30(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_29(__VA_ARGS__))
#define FUSE_PP_CAT_31(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_30(__VA_ARGS__))
#define FUSE_PP_CAT_32(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_31(__VA_ARGS__))
#define FUSE_PP_CAT_33(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_32(__VA_ARGS__))
#define FUSE_PP_CAT_34(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_33(__VA_ARGS__))
#define FUSE_PP_CAT_35(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_34(__VA_ARGS__))
#define FUSE_PP_CAT_36(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_35(__VA_ARGS__))
#define FUSE_PP_CAT_37(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_36(__VA_ARGS__))
#define FUSE_PP_CAT_38(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_37(__VA_ARGS__))
#define FUSE_PP_CAT_39(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_38(__VA_ARGS__))
#define FUSE_PP_CAT_40(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_39(__VA_ARGS__))
#define FUSE_PP_CAT_41(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_40(__VA_ARGS__))
#define FUSE_PP_CAT_42(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_41(__VA_ARGS__))
#define FUSE_PP_CAT_43(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_42(__VA_ARGS__))
#define FUSE_PP_CAT_44(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_43(__VA_ARGS__))
#define FUSE_PP_CAT_45(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_44(__VA_ARGS__))
#define FUSE_PP_CAT_46(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_45(__VA_ARGS__))
#define FUSE_PP_CAT_47(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_46(__VA_ARGS__))
#define FUSE_PP_CAT_48(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_47(__VA_ARGS__))
#define FUSE_PP_CAT_49(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_48(__VA_ARGS__))
#define FUSE_PP_CAT_50(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_49(__VA_ARGS__))
#define FUSE_PP_CAT_51(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_50(__VA_ARGS__))
#define FUSE_PP_CAT_52(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_51(__VA_ARGS__))
#define FUSE_PP_CAT_53(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_52(__VA_ARGS__))
#define FUSE_PP_CAT_54(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_53(__VA_ARGS__))
#define FUSE_PP_CAT_55(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_54(__VA_ARGS__))
#define FUSE_PP_CAT_56(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_55(__VA_ARGS__))
#define FUSE_PP_CAT_57(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_56(__VA_ARGS__))
#define FUSE_PP_CAT_58(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_57(__VA_ARGS__))
#define FUSE_PP_CAT_59(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_58(__VA_ARGS__))
#define FUSE_PP_CAT_60(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_59(__VA_ARGS__))
#define FUSE_PP_CAT_61(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_60(__VA_ARGS__))
#define FUSE_PP_CAT_62(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_61(__VA_ARGS__))
#define FUSE_PP_CAT_63(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_62(__VA_ARGS__))
#define FUSE_PP_CAT_64(e0, ...) FUSE_PP_CAT_2(e0, FUSE_PP_CAT_63(__VA_ARGS__))

/*
 * Expands to the concatenation of the given arguments. The arguments are
 * expanded before performing the concatenation. Supports up to 64 arguments.
 */
#define FUSE_PP_CAT(...) FUSE_PP_OVERLOAD(FUSE_PP_CAT_, __VA_ARGS__)(__VA_ARGS__)

#endif /* _FUSE_PREPROCESSOR_H_ */
