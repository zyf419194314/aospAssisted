#!/bin/bash

function usage() {
  echo "Usage: $0 [-j THREADS] [-e REGISTRY] [-u USERNAME] [-p PASSWORD] [LUNCH_TARGET]"
  echo ""
  echo "Build Android Open Source Project (AOSP) using ccache."
  echo ""
  echo "Positional arguments:"
  echo "  LUNCH_TARGET             The target to build. Default is 'aosp_xxx-userdebug'."
  echo ""
  echo "Optional arguments:"
  echo "  -j THREADS               The number of threads to spawn during compilation. Default is the number of CPU cores."
  echo "  -e REGISTRY              The Docker registry to authenticate with using -u and -p. Default is no registry."
  echo "  -u USERNAME              The username to authenticate with the Docker registry. Required when -e is specified."
  echo "  -p PASSWORD              The password to authenticate with the Docker registry. Required when -e is specified."
  echo "  -h                       Show usage message."
  echo ""
}

function configure_docker_registry() {
  if [[ -n "$1" ]] && [[ -n "$2" ]] && [[ -n "$3" ]]; then
    echo "Authenticating with $1 Docker registry..."
    echo "$3" | docker login $1 -u $2 --password-stdin
    if [[ $? -ne 0 ]]; then
      echo "Failed to authenticate with $1 Docker registry." >&2
      exit 1
    fi
  fi
}

function configure_build() {
  # Set up ccache
  export USE_CCACHE=1
  export CCACHE_EXEC=/usr/bin/ccache
  export CCACHE_DIR=./ccache

  # Set up AOSP environment
  source build/envsetup.sh

  # Configure build
  lunch $1
}

function build_aosp() {
  # Set default number of threads
  threads=$(nproc)

  # Parse command line arguments
  while getopts "j:e:u:p:h" opt; do
    case $opt in
      j) threads="$OPTARG";;
      e) registry="$OPTARG";;
      u) username="$OPTARG";;
      p) password="$OPTARG";;
      h) usage; exit 0;;
      \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
    esac
  done
  shift $((OPTIND-1))

  # Authenticate with Docker registry if specified
  configure_docker_registry $registry $username $password

  # Configure build
  configure_build ${1:-aosp_cf_x86_64_phone-userdebug}

  # Build AOSP
  make -j${threads}
}

# Call the build function with the lunch command argument and thread count
build_aosp "$@"
