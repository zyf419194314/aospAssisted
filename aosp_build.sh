#!/bin/bash

source config.sh
source tools.sh

function pre_show_title() {
    clear
}

# 展示title
function show_title() {
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo
    echo "#=================================================================#"
    echo "#                    AOSP源码辅助系统($(get_version))                     #"
    echo "#                                                                 #"
    echo "#                 ** 编译 AOSP (基于 currentfish) **                  #"
    echo "#                      $DATE                        #"
    echo "#=================================================================#"
    echo
}

function getparams() {
    read -p "请输入aosp目录存放地址[支持 相对路径/绝对路径] (默认为: $(get_config DIR)):" DIR
    DIR="${DIR:-$(get_config DIR)}"
    DIR="${DIR%/}"
    set_config DIR "$DIR"

    read -p "请输入lunch类型 (默认为: aosp_cf_x86_64_phone-userdebug):" LUNCH_TARGET
    LUNCH_TARGET="${LUNCH_TARGET:-aosp_cf_x86_64_phone-userdebug}"
    #   set_config LUNCH_TARGET "$LUNCH_TARGET"

    read -p "请输入编译线程数 (默认为: $(nproc --all)):" THREAD
    THREAD="${THREAD:-$(nproc --all)}"
    #   set_config THREAD "$THREAD"
}

function check_env() {
    echo ">>> 检查编译环境..."

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        if command -v brew >/dev/null 2>&1; then
            brew install ccache git-core gnupg flex bison gperf build-essential zip curl zlib1g-dev libc6-dev-i386 libncurses5 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev libgl1-mesa-dev libxml2-utils xsltproc unzip
        else
            echo "未找到 Homebrew 包管理器，请手动安装。"
            exit 1
        fi
    elif [[ "$(uname)" =~ ^Linux$ ]]; then
        # Linux
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y ccache git gnupg flex bison gperf build-essential zip curl zlib1g-dev libc6-dev-i386 libncurses5 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip
        elif command -v yum >/dev/null 2>&1; then
            sudo yum update
            sudo yum install -y ccache git gnupg flex bison gperf build-essential zip curl zlib1g-dev libc6-dev-i386 libncurses5 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip
        else
            echo "未找到包管理器，请手动安装。"
            exit 1
        fi
    else
        echo "不支持的操作系统。"
        exit 1
    fi

    echo "编译环境检查完成！"
}

function pre_build() {
    # export WITH_DEXPREOPT=false
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    export CCACHE_DIR=$DIR/ccache
    ccache -M 100G
}

function build() {
    echo ">>> 开始编译..."
    cd $DIR
    source build/envsetup.sh
    lunch $LUNCH_TARGET
    make -j$THREAD
}

# function build_docker_img() {
#     echo ">>> 开始打包镜像..."
#     cd $DIR
#     source build/envsetup.sh
#     lunch $LUNCH_TARGET
#     make -j$THREAD
# }

# function usage() {
#   echo "Usage: $0 [-j THREADS] [-e REGISTRY] [-u USERNAME] [-p PASSWORD] [LUNCH_TARGET]"
#   echo ""
#   echo "Build Android Open Source Project (AOSP) using ccache."
#   echo ""
#   echo "Positional arguments:"
#   echo "  LUNCH_TARGET             The target to build. Default is 'aosp_xxx-userdebug'."
#   echo ""
#   echo "Optional arguments:"
#   echo "  -j THREADS               The number of threads to spawn during compilation. Default is the number of CPU cores."
#   echo "  -e REGISTRY              The Docker registry to authenticate with using -u and -p. Default is no registry."
#   echo "  -u USERNAME              The username to authenticate with the Docker registry. Required when -e is specified."
#   echo "  -p PASSWORD              The password to authenticate with the Docker registry. Required when -e is specified."
#   echo "  -h                       Show usage message."
#   echo ""
# }

# function configure_docker_registry() {
#   if [[ -n "$1" ]] && [[ -n "$2" ]] && [[ -n "$3" ]]; then
#     echo "Authenticating with $1 Docker registry..."
#     echo "$3" | docker login $1 -u $2 --password-stdin
#     if [[ $? -ne 0 ]]; then
#       echo "Failed to authenticate with $1 Docker registry." >&2
#       exit 1
#     fi
#   fi
# }

# function configure_build() {
#   # Set up ccache
#   export USE_CCACHE=1
#   export CCACHE_EXEC=/usr/bin/ccache
#   export CCACHE_DIR=./ccache

#   # Set up AOSP environment
#   source build/envsetup.sh

#   # Configure build
#   lunch $1
# }

# function build_aosp() {
#   # Set default number of threads
#   threads=$(nproc)

#   # Parse command line arguments
#   while getopts "j:e:u:p:h" opt; do
#     case $opt in
#       j) threads="$OPTARG";;
#       e) registry="$OPTARG";;
#       u) username="$OPTARG";;
#       p) password="$OPTARG";;
#       h) usage; exit 0;;
#       \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
#     esac
#   done
#   shift $((OPTIND-1))

#   # Authenticate with Docker registry if specified
#   configure_docker_registry $registry $username $password

#   # Configure build
#   configure_build ${1:-aosp_cf_x86_64_phone-userdebug}

#   # Build AOSP
#   make -j${threads}
# }

# # Call the build function with the lunch command argument and thread count
# build_aosp "$@"

pre_show_title
show_title
getparams
check_env
pre_build
build
