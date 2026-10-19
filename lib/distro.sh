# Shared by the installers. Sets DISTRO to arch, fedora, debian, suse or unknown,
# and gives pkg_install and dkms_deps for that family. Tested on Arch only.
#   . "$(dirname "$0")/../lib/distro.sh"

DISTRO=unknown
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case " ${ID:-} ${ID_LIKE:-} " in
    *" arch "*) DISTRO=arch ;;
    *" fedora "*|*" rhel "*) DISTRO=fedora ;;
    *" debian "*|*" ubuntu "*) DISTRO=debian ;;
    *" suse "*|*" opensuse "*) DISTRO=suse ;;
  esac
fi

# pkg_install PKG...: install packages with the native package manager.
pkg_install() {
  case "$DISTRO" in
    arch)   pacman -S --needed --noconfirm "$@" ;;
    fedora) dnf install -y "$@" ;;
    debian) apt-get install -y "$@" ;;
    suse)   zypper --non-interactive install "$@" ;;
    *)      echo "Unknown distribution. Install these yourself: $*" >&2; return 1 ;;
  esac
}

# dkms_deps: print DKMS, a compiler and the headers package for the running kernel.
dkms_deps() {
  local k; k=$(uname -r)
  case "$DISTRO" in
    arch)
      # linux-zen needs linux-zen-headers, linux-lts needs linux-lts-headers.
      local base
      base=$(cat "/usr/lib/modules/$k/pkgbase" 2>/dev/null || echo linux)
      echo "dkms gcc make ${base}-headers" ;;
    fedora) echo "dkms gcc make kernel-devel-$k" ;;
    debian) echo "dkms gcc make linux-headers-$k" ;;
    suse)   echo "dkms gcc make kernel-${k##*-}-devel" ;;
  esac
}

# have_headers: true when the running kernel's build tree exists.
have_headers() { [ -d "/lib/modules/$(uname -r)/build" ]; }
