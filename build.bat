::set R_VERSION=R-3.2.2
::set R_VERSION=R-devel
set R_VERSION=%1

::set WIN=32
::set WIN=64
set WIN=%2

::set BUILDDIR=%CD%
set BUILDDIR=c:/Rbuild
cd %BUILDDIR%

:: Set name of target
set R_NAME=%R_VERSION%-win%WIN%
set R_HOME=%BUILDDIR%/%R_NAME%
set TMPDIR=%TEMP%

:: For the multi-arch installer
set HOME32=%BUILDDIR%/%R_VERSION%-win32

:: Add rtools executables in path
set PATH=C:/rtools/bin;%PATH%

:: Clean up
rm -f %R_HOME%/*.log
rm -Rf %R_HOME%

:: Copy sources
tar -xf %R_VERSION%.tar.gz
mv %R_VERSION% %R_NAME%
sed -e "s|@win@|%WIN%|" -e "s|@home@|%R_HOME%|" -e "s|@home32@|%HOME32%|" -e "s|@build@|%BUILDDIR%|" MkRules.local.in > %R_HOME%/src/gnuwin32/MkRules.local

:: Copy libraries
cp -R Tcl%WIN% %R_HOME%/Tcl
cp -R extsoft %R_HOME%/extsoft
cp curl-ca-bundle.crt %R_HOME%/etc/curl-ca-bundle.crt

:: Temporary patch for mingw-w64 bugs
:: sed -i "s/__GNUC__ <= 4/__GNUC__ <= 5/g" %R_HOME%/src/main/eval.c
:: sed -i "s/ISNAN(x) ? x : sqrt(x)/__isnan(x) ? x : sqrt(x)/g" %R_HOME%/src/main/eval.c

:: Enable C++11
:: sed -i "s/CXX1XSTD = -std=c++0x/CXX1XSTD = -std=c++11/g" %R_HOME%/src/gnuwin32/fixed/etc/Makeconf

:: Mark output as experimental
sed -i "s/Under development (unstable)/EXPERIMENTAL/" %R_HOME%/VERSION
echo built with gcc 4.9.3 > %R_HOME%/VERSION-NICK
echo cat('R-experimental') > %R_HOME%/src/gnuwin32/fixed/rwver.R

:: Switch dir
cd %R_HOME%/src/gnuwin32

:: Download 'extsoft' directory
:: make rsync-extsoft

:: Build R
make all recommended vignettes > %R_HOME%/build.log 2>&1
make cairodevices

:: Run some checks
make check > %R_HOME%/check.log 2>&1
make check-recommended > %R_HOME%/check-recommended.log 2>&1

:: Requires pdflatex (e.g. miktex)
make manuals > %R_HOME%/manuals.log 2>&1

:: Add compiler to the PATH
cat %BUILDDIR%/profile.txt >> %R_HOME%/etc/Rprofile.site

:: Build the installer
IF "%WIN%"=="64" (
make distribution > %R_HOME%/distribution.log 2>&1
cp %R_HOME%/src/gnuwin32/installer/*.exe %BUILDDIR%/
)

:: Done
cd %BUILDDIR%
