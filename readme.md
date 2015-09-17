## Rtools 3.3

Last updated by Jeroen on September 17 2015.

### Introduction

Rtools <= 3.2 was put together by Brian Ripley. It was configured with:

 - gcc 4.6.3 pre-release
 - mingw-w64 V2
 - sjlj exceptions
 - win32 host with multilib
 - static-gcc

Updating the tool chain in a way that is compatible with the old one has
proven to be challenging. Two major problems:

 - __exceptions__: Rcpp mixes c++ exceptions with R's `setjmp-longjmp` system,
   potentially between multiple Rcpp-module dll files. Unfortunately this 
   does not work well anymore with `sjlj` in recent versions of gcc. Therefore
   we have to switch to another exception model.

 - __math__: the mingw-w64 math implementations have a some peculiarities 
   for e.g. numeric precision or NaN handling. Currently the `V3` runtime 
   gives more consistent results than the `V4` runtime (the latter is only
   needed for gcc 5). The only remaining problem is `pow()` on win64. 

Over the past year, several people have been building, testing and debugging
many different variations of the tool chain. As of August 2015 there is a 
special `r-sig-windows` mailing list for dicusssing these things.

Some people that have been contributing to the process include:

 - Duncan Murdoch
 - Uwe Ligges
 - Qiang Kou (KK)
 - Kevin Ushey
 - JJ Allaire
 - Avraham Adler 
 - Jeroen Ooms

### The tool chain

The new rtools were compiled using the [*mingw-builds* scripts][1]. These
scripts are thorougly tested and used by the mingw-w64 project itself to 
publish builds on their [sourceforge page][3]. In contrast to the old tool
chain, the new tool chain does not support multilib. Therefore we actually
have two toolchains: one for compiling win32 and one for compiling win64. 
The full conventional names of these toolchains are:

 - `i686-493-posix-dwarf-rt_v3-s` for win32
 - `x86_64-493-posix-seh-rt_v3-s` for win64

A full copy of these tool chains can be downloaded from [4]. A breakdown of 
these names:

 - Target: `i686` or `x86_64`
 - GCC version: 4.9.3
 - Threading implementation: posix
 - Exception model: `dwarf` on win32 and `seh` on win64
 - Mingw-w64 runtime version: `rt_v3`
 - The `-s` postfix means `--static-gcc`: software compiled with the tool 
   chain does not depend on external DLL files such as `libgfortran-3.dll`,
   `libstdc++-6.dll`, `libwinpthread-1.dll`, etc. 

To reproduce the tool chain, download the [mingw-builds scripts][1] 
(currently the branch is named 'develop') and run the following command 
inside msys2:

```sh
./build --mode=gcc-4.9.3 --rt-version=v3 --arch=i686 --exceptions=dwarf --static-gcc --threads=posix --enable-languages=c,c++,fortran 

./build --mode=gcc-4.9.3 --rt-version=v3 --arch=x86_64 --exceptions=seh --static-gcc --threads=posix --enable-languages=c,c++,fortran
```   

Because the new tool chain is more standard, updating it should be less 
painful in the future.

The new chain is larger in size than the old one. This is mostly because
we are shipping two seperate tool chains instead of one multilib. But
another reason is that recent versions of GDB now depend on python, which
again depends on a lot of other libraries. There is little we can do about
this, but with the price of disk space and network these days I don't think
this should be a problem.

[1]: https://github.com/niXman/mingw-builds/tree/develop
[2]: http://bit.ly/mingw32
[3]: http://bit.ly/mingw64
[4]: http://www.stat.ucla.edu/~jeroen/mingw-w64/archive/gcc-4.9.3/

### Exception model

The new tool chain uses a different c++ exception model than the previous
tool chain. The old gcc 4.6.3 tool chain used `sjlj` exceptions which are 
available on both win32 and win64 and therefore allowed for a multilib
tool chain. Unfortunately `sjlj` does not work well with recent features 
in gcc. The mingw-w64 authors recommend to switch to `dwarf` on win32 and 
`seh` on win64. These exception models are the default in mingw-w64 since 
gcc 4.8 because they are more reliable and performant. This also means that
they are much better tested and less buggy. We found all of our exception
related problems disappeared after we switched.

The only disadvantage of switching is that it is impossible to link existing
static c++ libraries that were built using `sjlj` with a the new `dwarf` and
`seh` tool chains. Therefore most C++ libraries that have been deployed on 
CRAN and elsewhere will need a rebuild.

However because our new tool chain is more standard, building these libraries
has become much easier. Many libraries are available in the form of source
packages from [msys2][5]. In fact for most libraries we might be able to 
download prebuilt binaries directly from their [repositories][6].

[5]: https://github.com/Alexpux/MINGW-packages/
[6]: http://repo.msys2.org/


### Building R on Windows

The current repository contains the required scripts and libraries to build
the R-devel multi-arch installer on Windows.

Note that we use icu-55.1 from [3] to build R with this new tool chain because
the ICU version from Brian Ripley was built for SJLJ. Because ICU is the only 
c++ library required to build R, all of the other libraries (multi320.zip, Tcl,
Cairo, libcurl) can still be taken from cran/rtools.

 1. Install the latest Rtools into `C:/Rtools`. Verify that `C:/Rtools/mingw32/`
    and `C:/Rtools/mingw64` are present. 
 2. Clone the current repository into c:/Rbuild
 3. Download the souce file R-devel.tar.gz from the R website.
 4. Run the `buildall.bat` script.

These scripts are subject to change. A recent build of r-devel using the new
tool is availble from [6]. The build has been renamed to `r-experimental` to
distinguish it from the `r-devel` builds on CRAN that still use the old tool 
chain.

[6]: http://www.stat.ucla.edu/~jeroen/mingw-w64/

### Migration steps

First we need to update the official Rtools installer. The new tool chain can 
co-exist with the old one, so that we can support R 3.2 and R 3.3 on one 
machine. The mingw-w64 convention is to name the directory with the compiler
`mingw32` and `mingw64` respectively. So the new tool chain would contain:

```sh
./bin
./gcc-4.9.3
./mingw32
./mingw64
./texinfo5
```

Note that the `./bin` directory contains binary utilities required for building
packages such as `sh` and `make`. These are just win32 executables that can be
used with any tool chain on both architectures.

Then to build R on CRAN the `MkRules.local` file needs to be modified to use
the non-multilib compiler: 

```make
### For multilib compiler ###
# TOOL_PATH = C:/Rtools/gcc-4.6.3/bin/
# MULTI = @win@
###

### For non-multilib compilers ###
WIN = @win@
BINPREF = C:/Rtools/mingw32/bin/
BINPREF64 = C:/Rtools/mingw64/bin/
###
```

In addition the new tool chain requires a the following changes in
`src/gnuwin32/fixed/etc/Makeconf`:

```make
CXX1XSTD = -std=c++11
FLIBS = -lgfortran -lm -lquadmath
```

Then we need a separate directory with static libraries to make sure we do not
mix up the `sjlj` builds for the old tool chain with the new `drarf`/`seh` 
builds for the new one. I think we need:

```
d:/RCompile/r-compiling/local/local330/include
d:/RCompile/r-compiling/local/local330/lib/x64
d:/RCompile/r-compiling/local/local330/lib/i386
```

We can copy over the C libraries from `3.2` but the C++ libraries need a 
rebuild. Here is a copy of [`libicu-55`][6] needed to build R itself.

### Future work

Once the new tool chain is in place we can update the `./bin` utilities 
as well because some of them are quite old. This should hopefully be
quite easy.

### Resources

 - [mingw-builds readme](https://github.com/niXman/mingw-builds/tree/develop#readme)
 - Rubenvb description of [posix vs win32](http://stackoverflow.com/a/30390278/318752) threading
 - Mingw-w64 [bug report](https://sourceforge.net/p/mingw-w64/bugs/466/) by Duncan about the `pow()` problem
 - Some [notes](https://github.com/kevinushey/RToolsToolchainUpdate/blob/master/mingwnotes.Rmd) by Duncan and Kevin earlier this year.
 - [Wiki page](http://mingw-w64.org/doku.php/contribute) from mingw-w64 about SEH, LTO, C++11, etc 
