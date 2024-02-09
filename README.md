# static-libgit2

This repository makes it easier to include the C library [Libgit2](https://libgit2.org) into an iOS or Mac application. It does *not* try to provide any sort of nice, Swifty wrapper over the `libgit2` APIs.

This repository is heavily indebted to https://github.com/light-tech/LibGit2-On-iOS. However, the `LibGit2-On-iOS` project doesn't expose the C Language bindings as its own Swift Package, choosing instead to use their framework as a binary target in their Swift Language binding project [MiniGit](https://github.com/light-tech/MiniGit). If you want Swift bindings, you should probably use that project! However, if you want to work directly with the C API, _this_ is the project for you want to start with.

## Usage in an Application

Important Notes:  

1. OpenSSL currently doesn't support VisionOS (no maintainer). Until this does, we inject our own config file - 20-apple.conf (based on https://github.com/passepartoutvpn/openssl-apple) which adds support for VisionOS.

2. To build, currently there is a slight issue with CMake in that it builds xros binaries instead of xrsimulator binaries.  
This is currently (Feb 2024) under investigation but a temporary workaround is to comment out the following lines in Apple-Clang.cmake (e.g. /opt/homebrew/Cellar/cmake/3.28.1/share/cmake/Modules/Platform/Apple-Clang.cmake):
```
  elseif(_CMAKE_OSX_SYSROOT_PATH MATCHES "/XRSimulator")  
    set(CMAKE_${lang}_OSX_DEPLOYMENT_TARGET_FLAG "-mtargetos=xros")
```

If you are writing an iOS or Mac app that needs access to `libgit2`, you can simply add this package to your project via Swift Package Manager. The `libgit2` C Language APIs are provided through the `Clibgit2` module, so you can access them with `import Clibgit2`. For example, the following SwiftUI view will show the `libgit2` version:

```swift
import Clibgit2
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(LIBGIT2_VERSION)
            .padding()
    }
}
```

## Usage in another package

If you want to use `static-libgit2` in another package (say, to expose some cool Swift bindings to the C API), include the following in your `Package.swift`:

```swift
    dependencies: [
      .package(url: "https://github.com/bdewey/static-libgit2", from: "0.1.0"),
    ],
```

# What's Included

`static-libgit2` includes the following libraries:

| Library | Version |
| ------- | ------- |
| libgit2 | 1.3.0   |
| openssl | 3.0.0   |
| libssh2 | 1.10.0  |

This build recipe and the original version of the build script comes from the insightful project https://github.com/light-tech/LibGit2-On-iOS. 

# Build it yourself

You don't need to depend on this package's pre-built libraries. You can build your own version of the framework.

```
# You need the tool `wget`
brew install wget
git clone https://github.com/bdewey/static-libgit2
cd static-libgit2
./build-libgit2-framework.sh
```
