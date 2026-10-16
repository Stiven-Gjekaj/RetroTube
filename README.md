# RetroTube

RetroTube is a YouTube client for an iPhone 4S on iOS 6.1.3 (jailbroken).
It installs as a .deb package through Cydia.
It operates with no outside server.

The iOS 6 system TLS connects to YouTube.
The InnerTube /player API with the IOS client identity gives direct stream
URLs and an HLS manifest.
The test in `probe/main.m` shows these 3 steps on the real phone.

## Get the SDK

1. Download `iPhoneOS9.3.sdk.tar.xz` from the releases of
   https://github.com/theos/sdks.
2. Unpack it into `sdks/`. The result is `sdks/iPhoneOS9.3.sdk`.
3. Run `./fix-sdk.sh` one time.
   This script changes the SDK stubs for the new Apple linker and for iOS 6.

Git does not track `sdks/`. The SDK is 3rd-party code.

## Build

    ./build.sh OUT SRC.m -framework Foundation

The script makes an armv7 binary in ARM mode (`-marm`).
It compiles each source with ARC and links without ARC.

Example:

    ./build.sh probe/probe probe/main.m -framework Foundation

## Run on the phone

The phone is at `ssh iphone4s` through a USB iproxy tunnel on port 2222.

    scp X iphone4s:/tmp/
    ssh iphone4s 'ldid -S /tmp/X && /tmp/X'

`ldid -S` signs the binary. iOS 6 does not start a binary that has no
signature.
