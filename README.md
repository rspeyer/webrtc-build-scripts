##WebRTC Build Scripts
A set of build scripts useful for building WebRTC libraries for Android and iOS.

##Android
**NOTE**: Android builds must be done on Linux. This script is tested with Ubuntu 14.04 LTS.

#### Initial Setup
```bash
cd $HOME/dev
git clone git@github.com:talko/webrtc-build-scripts
cd webrtc-build-scripts/android

# Default branch is talko_master
# Default build is Release
./tk.sh --init [--branch BRANCH --build [Release|Debug|all]]
```

#### Building
```bash
cd $HOME/dev/webrtc-build-scripts/android

# Default branch is talko_master
# Default build is Release
./tk.sh [--branch BRANCH --build [Release|Debug|all]]
```

##iOS
#### Initial Setup
```bash
cd $HOME/dev
git clone git@github.com:talko/webrtc-build-scripts
cd webrtc-build-scripts/ios

# Default branch is talko_master
# Default build is Release
./tk.sh --init [--branch BRANCH --build [Release|Debug|all]]
```

#### Building
```bash
cd $HOME/dev/webrtc-build-scripts/ios

# Default branch is talko_master
# Default build is Release
./tk.sh [--branch BRANCH --build [Release|Debug|all]]
```
