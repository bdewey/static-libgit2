# This build file was copied & modified from https://github.com/light-tech/LibGit2-On-iOS

export REPO_ROOT=`pwd`
export DEPENDENCIES_ROOT="$REPO_ROOT/dependencies"
export LOGS_ROOT=$REPO_ROOT/logs

set -e

rm -rf $DEPENDENCIES_ROOT
mkdir $DEPENDENCIES_ROOT
rm -rf $LOGS_ROOT
mkdir $LOGS_ROOT
rm -rf $REPO_ROOT/*.xcframework
rm -rf $REPO_ROOT/install*
mkdir $REPO_ROOT/install

AVAILABLE_PLATFORMS=(visionos visionossimulator iphoneos iphonesimulator maccatalyst maccatalyst-arm64 macosx-arm64 macosx)

### Setup common environment variables to run CMake for a given platform
### Usage:      setup_variables PLATFORM INSTALLDIR
### where PLATFORM is the platform to build for and should be one of
###    iphoneos            (implicitly arm64)
###    iphonesimulator     (implicitly x86_64)
###    visionos            (implicitly arm64)
###    visionossimulator   (implicitly arm64)
###    maccatalyst, maccatalyst-arm64
###    macosx, macosx-arm64
###
### After this function is executed, the variables
###    $PLATFORM
###    $ARCH
###    $SYSROOT
###    $CMAKE_ARGS
### providing basic/common CMake options will be set.
function setup_variables() {
    cd $DEPENDENCIES_ROOT
    PLATFORM=$1

    CMAKE_ARGS=(-DBUILD_SHARED_LIBS=NO \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER_WORKS=ON \
        -DCMAKE_CXX_COMPILER_WORKS=ON \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.4 \
        -DCMAKE_INSTALL_PREFIX=$REPO_ROOT/$2/$PLATFORM)

    case $PLATFORM in
        "iphoneos")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk iphoneos Path  2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH \
                -DCMAKE_OSX_SYSROOT=$SYSROOT);;

        "iphonesimulator")
            ARCH=$(arch)
            SYSROOT=`xcodebuild -version -sdk iphonesimulator Path  2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_OSX_SYSROOT=$SYSROOT);;

        "visionos")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk xros Path  2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH \
                -DCMAKE_OSX_SYSROOT=$SYSROOT);;

        "visionossimulator")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk xrsimulator Path  2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_C_FLAGS=-target\ arm64-apple-xros1.0-simulator -DCMAKE_OSX_SYSROOT=$SYSROOT);;

        "maccatalyst")
            ARCH=x86_64
            SYSROOT=`xcodebuild -version -sdk macosx Path  2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi -DCMAKE_OSX_ARCHITECTURES=$ARCH);;

        "maccatalyst-arm64")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk macosx Path  2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi -DCMAKE_OSX_ARCHITECTURES=$ARCH);;

        "macosx")
            ARCH=x86_64
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH)
            SYSROOT=`xcodebuild -version -sdk macosx Path 2>/dev/null`;;

        "macosx-arm64")
            ARCH=arm64
            SYSROOT=`xcodebuild -version -sdk macosx Path 2>/dev/null`
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH);;

        *)
            echo "Unsupported or missing platform! Must be one of" ${AVAILABLE_PLATFORMS[@]}
            exit 1;;
    esac
}

### Build libpcre for a given platform
function build_libpcre() {
    setup_variables $1 install

    rm -rf pcre-8.45
    git clone https://github.com/light-tech/PCRE.git pcre-8.45
    cd pcre-8.45

    rm -rf build && mkdir build && cd build
    CMAKE_ARGS+=(-DPCRE_BUILD_PCRECPP=NO \
        -DPCRE_BUILD_PCREGREP=NO \
        -DPCRE_BUILD_TESTS=NO \
        -DPCRE_SUPPORT_LIBBZ2=NO)

    cmake "${CMAKE_ARGS[@]}" ..  > $LOGS_ROOT/libpcre_${PLATFORM}.log 2>&1

    cmake --build . --target install >> $LOGS_ROOT/libpcre_${PLATFORM}.log 2>&1
}

### Build openssl for a given platform
function build_openssl() {
    setup_variables $1 install-openssl

    echo "BUILDING openssl for $PLATFORM - $ARCH"
    # It is better to remove and redownload the source since building make the source code directory dirty!
    rm -rf openssl-3.0.0
    test -f openssl-3.0.0.tar.gz || wget -q https://www.openssl.org/source/openssl-3.0.0.tar.gz
    tar xzf openssl-3.0.0.tar.gz
    cd openssl-3.0.0
    cp ../../20-apple.conf ./Configurations

    case $PLATFORM in
        "iphoneos")
            TARGET_OS=ios64-cross
            export CFLAGS="-isysroot $SYSROOT -arch $ARCH -mios-version-min=13.0";;

        "iphonesimulator")
            TARGET_OS=iossimulator-xcrun
            export CFLAGS="-isysroot $SYSROOT -miphonesimulator-version-min=13.0";;

        "visionos")
            TARGET_OS=xros-cross-arm64
            export CFLAGS="-isysroot $SYSROOT -arch $ARCH -mtargetos=xros1.0";;

        "visionossimulator")
            TARGET_OS=xros-sim-cross-arm64
            export CFLAGS="-isysroot $SYSROOT";;

        "maccatalyst"|"maccatalyst-arm64")
            TARGET_OS=darwin64-$ARCH-cc
            export CFLAGS="-isysroot $SYSROOT -target $ARCH-apple-ios14.1-macabi";;

        "macosx"|"macosx-arm64")
            TARGET_OS=darwin64-$ARCH-cc
            export CFLAGS="-isysroot $SYSROOT";;
        *)
            echo "Unsupported or missing platform ($PLATFORM)!";;
    esac

    echo "$PLATFORM $ARCH $TARGET_OS"

    # See https://wiki.openssl.org/index.php/Compilation_and_Installation
    ./Configure --prefix=$REPO_ROOT/install-openssl/$PLATFORM \
        --openssldir=$REPO_ROOT/install-openssl/$PLATFORM \
        $TARGET_OS no-shared no-dso no-hw no-engine > $LOGS_ROOT/openssl_${PLATFORM}.log 2>&1

    make >> $LOGS_ROOT/openssl_${PLATFORM}.log 2>&1
    make install_sw install_ssldirs >> $LOGS_ROOT/openssl_${PLATFORM}.log 2>&1
    export -n CFLAGS
}

### Build libssh2 for a given platform (assume openssl was built)
function build_libssh2() {
    setup_variables $1 install-libssh2

    echo "BUILDING libssh2 for $PLATFORM"
    rm -rf libssh2-1.10.0
    test -f libssh2-1.10.0.tar.gz || wget -q https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
    tar xzf libssh2-1.10.0.tar.gz
    cd libssh2-1.10.0

    rm -rf build && mkdir build && cd build

    CMAKE_ARGS+=(-DCRYPTO_BACKEND=OpenSSL \
        -DOPENSSL_ROOT_DIR=$REPO_ROOT/install-openssl/$PLATFORM \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF)


    cmake "${CMAKE_ARGS[@]}" .. > $LOGS_ROOT/libssh_$PLATFORM.log 2>&1

    cmake --build . --target install >> $LOGS_ROOT/libssh_$PLATFORM.log 2>&1
}

### Build libgit2 for a single platform (given as the first and only argument)
### See @setup_variables for the list of available platform names
### Assume openssl and libssh2 was built
function build_libgit2() {
    setup_variables $1 install

    echo "Building libgit2 for $PLATFORM"
    rm -rf libgit2-1.3.0
    test -f v1.3.0.zip || wget -q https://github.com/libgit2/libgit2/archive/refs/tags/v1.3.0.zip
    ditto -x -k --sequesterRsrc --rsrc v1.3.0.zip ./
    cd libgit2-1.3.0

    rm -rf build && mkdir build && cd build

    # The CMake function that determines if `libssh2_userauth_publickey_frommemory` is defined doesn't
    # work when everything is statically linked. Manually override GIT_SSH_MEMORY_CREDENTIALS.
    CMAKE_ARGS+=(-DBUILD_CLAR=NO -DGIT_SSH_MEMORY_CREDENTIALS=1 -DCMAKE_PREFIX_PATH="$REPO_ROOT/install-libssh2/$PLATFORM;$REPO_ROOT/install-openssl/$PLATFORM")

    #echo cmake "${CMAKE_ARGS[@]}"
    cmake "${CMAKE_ARGS[@]}" .. > $LOGS_ROOT/libgit_$PLATFORM.log 2>&1

    cmake --build . --target install >> $LOGS_ROOT/libgit_$PLATFORM.log 2>&1
}

### Create xcframework for a given library
function build_xcframework() {
    local FWNAME=$1
    local INSTALLDIR=$2
    local XCFRAMEWORKNAME=$3
    shift 3
   local PLATFORMS=( iphoneos iphonesimulator visionos visionossimulator )
    # local PLATFORMS=( visionossimulator )
    local FRAMEWORKS_ARGS=()

    # echo "Creating fat binary for macosx"
    mkdir -p "$INSTALLDIR/macosx-fat/lib"
    lipo "$INSTALLDIR/macosx/lib/$FWNAME.a" "$INSTALLDIR/macosx-arm64/lib/$FWNAME.a" -create -output "$INSTALLDIR/macosx-fat/lib/$FWNAME.a"
    FRAMEWORKS_ARGS+=("-library" "$INSTALLDIR/macosx-fat/lib/$FWNAME.a" "-headers" "$INSTALLDIR/macosx/include")

    echo "Creating fat binary for maccatalyst"
    mkdir -p "$INSTALLDIR/maccatalyst-fat/lib"
    lipo "$INSTALLDIR/maccatalyst/lib/$FWNAME.a" "$INSTALLDIR/maccatalyst-arm64/lib/$FWNAME.a" -create -output "$INSTALLDIR/maccatalyst-fat/lib/$FWNAME.a"
    FRAMEWORKS_ARGS+=("-library" "$INSTALLDIR/maccatalyst-fat/lib/$FWNAME.a" "-headers" "$INSTALLDIR/maccatalyst/include")

    echo "Building" $FWNAME "XCFramework containing" ${PLATFORMS[@]}

    for p in ${PLATFORMS[@]}; do
        FRAMEWORKS_ARGS+=("-library" "$INSTALLDIR/$p/lib/$FWNAME.a" "-headers" "$INSTALLDIR/$p/include")
    done

    cd $REPO_ROOT
    echo xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output $XCFRAMEWORKNAME.xcframework
    xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output $XCFRAMEWORKNAME.xcframework
}

### Copy SwiftGit2's module.modulemap to libgit2.xcframework/*/Headers
### so that we can use libgit2 C API in Swift (e.g. via SwiftGit2)
function copy_modulemap() {
    local FWDIRS=$(find Clibgit2.xcframework -mindepth 1 -maxdepth 1 -type d)
    for d in ${FWDIRS[@]}; do
        echo $d
        cp Clibgit2_modulemap $d/Headers/module.modulemap
    done
}

### Build libgit2 and Clibgit2 frameworks for all available platforms

for p in ${AVAILABLE_PLATFORMS[@]}; do
   echo "Build libraries for $p"
   
   build_libpcre $p
   echo '--------------------'
   build_openssl $p
   echo '--------------------'
   build_libssh2 $p
   echo '--------------------'
   build_libgit2 $p
   echo '--------------------'

   # Put all of the generated *.a files into a single *.a file that will be in our framework
   cd $REPO_ROOT
   libtool -v -static -o libgit2_all.a install-openssl/$p/lib/*.a install/$p/lib/*.a install-libssh2/$p/lib/*.a
   cp libgit2_all.a install/$p/lib
   rm libgit2_all.a
   echo '--------------------'
   echo "Finished Platform $p"
   echo ""
done

echo "Building framework....."
build_xcframework libgit2_all install Clibgit2
cd $REPO_ROOT
copy_modulemap
