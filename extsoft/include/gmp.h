#ifndef gmp_wrapper_h
#define gmp_wrapper_h

#if defined(__i386__)
#include "gmp-i386.h"
#elif defined(__x86_64__)
#include "gmp-x64.h"
#else
#error "Unknown architecture."
#endif

#endif
