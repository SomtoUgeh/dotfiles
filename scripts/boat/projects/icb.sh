# shellcheck shell=bash
# icb extras: Java 25, the Android SDK and the two emulators the reader app is tested on.
# Sourced by vm-setup; project_setup runs in the "project" stage. Idempotent.
JDK_URL=https://api.adoptium.net/v3/binary/version/jdk-25.0.5.1%2B2/linux/x64/jdk/hotspot/normal/eclipse
CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
SDK_PACKAGES=("platform-tools" "emulator" "build-tools;36.0.0" "platforms;android-37.0"
  "system-images;android-33;default;x86_64" "system-images;android-37.0;default;x86_64")

project_setup() {
  local sdk=$HOME/Android/Sdk sm
  if [ ! -x /opt/jdk25/bin/java ]; then
    say "Java 25 (Temurin) into /opt/jdk25"
    curl -fsSL "$JDK_URL" -o /tmp/jdk25.tgz
    sudo mkdir -p /opt/jdk25 && sudo tar -xzf /tmp/jdk25.tgz -C /opt/jdk25 --strip-components=1 && rm -f /tmp/jdk25.tgz
  fi
  export JAVA_HOME=/opt/jdk25 ANDROID_HOME=$sdk PATH=/opt/jdk25/bin:$PATH
  if [ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
    say "Android command-line tools"
    mkdir -p "$sdk/cmdline-tools" && curl -fsSL "$CMDLINE_TOOLS_URL" -o /tmp/clt.zip
    rm -rf /tmp/clt && unzip -q /tmp/clt.zip -d /tmp/clt && mv /tmp/clt/cmdline-tools "$sdk/cmdline-tools/latest" && rm -rf /tmp/clt /tmp/clt.zip
  fi
  sm=$sdk/cmdline-tools/latest/bin/sdkmanager
  local missing=() p
  for p in "${SDK_PACKAGES[@]}"; do [ -d "$sdk/${p//;//}" ] || missing+=("$p"); done
  if [ ${#missing[@]} -gt 0 ]; then
    say "Android SDK packages: ${missing[*]}"
    yes | "$sm" --licenses >/dev/null 2>&1 || true
    "$sm" "${missing[@]}" >/dev/null
  fi
  id -nG | grep -qw kvm || sudo usermod -aG kvm "$USER"
  make_avd icb_e60q "system-images;android-33;default;x86_64" "" 1024 600 160 6442450944
  make_avd icb_api37 "system-images;android-37.0;default;x86_64" pixel_7 1080 2400 420 2G
}

# make_avd <name> <image> <device or ""> <width> <height> <density> <data partition size>
make_avd() {
  local cfg=$HOME/.android/avd/$1.avd/config.ini
  [ -f "$cfg" ] && return
  say "emulator $1"
  echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" -s create avd -n "$1" -k "$2" ${3:+-d "$3"} >/dev/null
  sed -i -E '/^hw\.lcd\.(width|height|density)|^hw\.ramSize|^disk\.dataPartition\.size/d' "$cfg"
  printf 'hw.lcd.width=%s\nhw.lcd.height=%s\nhw.lcd.density=%s\nhw.ramSize=2048\ndisk.dataPartition.size=%s\n' "$4" "$5" "$6" "$7" >>"$cfg"
}
