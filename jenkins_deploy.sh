#!/bin/bash

source config.sh

function pre_show_title() {
  clear
}

# 展示title
function show_title() {
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo
    echo "#=================================================================#"
    echo "#                    AOSP源码辅助系统(`get_version`)                     #"
    echo "#                                                                 #"
    echo "#                 ** 本机部署jenkins **                  #"
    echo "#                      $DATE                        #"
    echo "#=================================================================#"
    echo
}

function getparams() {
    read -p "请选择部署方式[支持 测试环境部署 1 / 正式环境部署 2] (默认为: $(get_config GERRIT_DEPLOY_TYPE)):" GERRIT_DEPLOY_TYPE
    GERRIT_DEPLOY_TYPE="${GERRIT_DEPLOY_TYPE:-$(get_config GERRIT_DEPLOY_TYPE)}"
    set_config GERRIT_DEPLOY_TYPE "$GERRIT_DEPLOY_TYPE"

    read -p "请输入gerrit镜像版本 (默认为: $(get_config GERRIT_DEPLOY_VERSION)):" GERRIT_DEPLOY_VERSION
    GERRIT_DEPLOY_VERSION="${GERRIT_DEPLOY_VERSION:-$(get_config GERRIT_DEPLOY_VERSION)}"
    set_config GERRIT_DEPLOY_VERSION "$GERRIT_DEPLOY_VERSION"

    while true; do
        read -p "请输入gerrit WEB端口号(默认为: $(get_config GERRIT_DEPLOY_PORT)):" GERRIT_DEPLOY_PORT
        GERRIT_DEPLOY_PORT="${GERRIT_DEPLOY_PORT:-$(get_config GERRIT_DEPLOY_PORT)}"
        if [[ $GERRIT_DEPLOY_PORT =~ ^[0-9]+$ ]] && [[ $GERRIT_DEPLOY_PORT -ge 1 ]] && [[ $GERRIT_DEPLOY_PORT -le 65535 ]]; then
            break
        else
            echo "端口号输入不正确,请重新输入(1-65535)"
        fi
    done
    set_config GERRIT_DEPLOY_PORT "$GERRIT_DEPLOY_PORT"

    while true; do
        read -p "请输入gerrit ssh端口号(默认为: $(get_config GERRIT_SERVER_PORT)):" GERRIT_SERVER_PORT
        GERRIT_SERVER_PORT="${GERRIT_SERVER_PORT:-$(get_config GERRIT_SERVER_PORT)}"
        if [[ $GERRIT_SERVER_PORT =~ ^[0-9]+$ ]] && [[ $GERRIT_SERVER_PORT -ge 1 ]] && [[ $GERRIT_SERVER_PORT -le 65535 ]]; then
            break
        else
            echo "端口号输入不正确,请重新输入(1-65535)"
        fi
    done
    set_config GERRIT_SERVER_PORT "$GERRIT_SERVER_PORT"

    if [ $(get_config GERRIT_DEPLOY_TYPE) -eq 2 ]; then
        # 正式环境拓展信息
        echo "TODO"
    fi

    # read -p "请输入gerrit 用户名(默认为: $(get_config GERRIT_SERVER_USERNAME)):" GERRIT_SERVER_USERNAME
    # GERRIT_SERVER_USERNAME="${GERRIT_SERVER_USERNAME:-$(get_config GERRIT_SERVER_USERNAME)}"
    # set_config GERRIT_SERVER_USERNAME "$GERRIT_SERVER_USERNAME"

    # read -p "请输入指定的xml文件(默认为: $(get_config GERRIT_MANIFEST_XML_FILE)):" GERRIT_MANIFEST_XML_FILE
    # GERRIT_MANIFEST_XML_FILE="${GERRIT_MANIFEST_XML_FILE:-$(get_config GERRIT_MANIFEST_XML_FILE)}"
    # MANIFEST_XML_FILE=$MANIFEST/$GERRIT_MANIFEST_XML_FILE
    # set_config GERRIT_MANIFEST_XML_FILE "$GERRIT_MANIFEST_XML_FILE"
}

# 环境检查
function check_env() {
  echo ">>> 检查是否已安装 docker..."
  if command -v docker >/dev/null 2>&1; then
    echo "Docker 已安装!"
  else
    echo "Docker 未安装，正在尝试安装..."
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      if command -v brew >/dev/null 2>&1; then
        brew install docker
      else
        echo "未找到 Homebrew 包管理器，请手动安装。"
        exit 1
      fi
    elif [[ "$(uname)" =~ ^Linux$ ]]; then
      # Linux
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y docker.io
      elif command -v yum >/dev/null 2>&1; then
        sudo yum update
        sudo yum install -y https://github.com/budtmo/docker-android.gitdocker
      else
        echo "未找到包管理器，请手动安装。"
        exit 1
      fi
    else
      echo "不支持的操作系统。"
      exit 1
    fi
    echo "Docker 已安装!"
  fi

  echo ">>> 检查是否已安装 Docker Compose..."
  if command -v docker-compose >/dev/null 2>&1; then
    echo "Docker Compose 已安装!"
  else
    echo "Docker Compose 未安装，尝试安装..."
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    elif [[ "$(uname)" =~ ^Linux$ ]]; then
      # Linux
      sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    else
      echo "不支持的操作系统。"
      exit 1
    fi
    echo "Docker Compose 已安装!"
  fi
}

