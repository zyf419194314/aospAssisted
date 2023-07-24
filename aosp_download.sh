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
  echo "#                       ** 下载AOSP 源码 **                       #"
  echo "#                      $DATE                        #"
  echo "#=================================================================#"
  echo
}

function getparams() {
  echo "当前路径: $(pwd)"
  read -p "请输入aosp目录存放地址[支持 相对路径/绝对路径] (默认为: $(get_config DIR)):" DIR
  DIR="${DIR:-$(get_config DIR)}"
  DIR="${DIR%/}"
  set_config DIR "$DIR"
  MANIFEST=$DIR/.repo/manifests/

  read -p "请输入aosp源码拉取分支 (默认为: $(get_config REPO_BRANCH)):" REPO_BRANCH
  REPO_BRANCH="${REPO_BRANCH:-$(get_config REPO_BRANCH)}"
  set_config REPO_BRANCH "$REPO_BRANCH"
}

function check_params() {
  if [ -d "$DIR" ]; then
    echo "当前路径: $DIR 目录已经存在，是否删除并重新创建？(y/n)"
    read CHOICE
    if [[ "$CHOICE" == "y" || "$CHOICE" == "Y" ]]; then
      rm -rf "$DIR"
      mkdir -p "$DIR"
      echo "目录已经重新创建"
    else
      echo "继续在当前路径下载源码"
    fi
  else
    mkdir -p "$DIR"
    echo "目录 $DIR 已经创建"
  fi
}

function check_env() {
  echo ">>> 检查是否已安装 curl..."

  if command -v curl >/dev/null 2>&1; then
    echo "curl 已安装！"
  else
    echo "curl 未安装，正在尝试安装..."

    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      if command -v brew >/dev/null 2>&1; then
        brew install curl
      else
        echo "未找到 Homebrew 包管理器，请手动安装。"
        exit 1
      fi
    elif [[ "$(uname)" =~ ^Linux$ ]]; then
      # Linux
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y curl
      elif command -v yum >/dev/null 2>&1; then
        sudo yum update
        sudo yum install -y curl
      else
        echo "未找到包管理器，请手动安装。"
        exit 1
      fi
    else
      echo "不支持的操作系统。"
      exit 1
    fi

    echo "curl 已安装！"
  fi

  echo ">>> 检查是否已安装 repo..."
  if command -v repo >/dev/null 2>&1; then
    echo "repo 已安装！"
  else
    echo "repo 未安装，正在尝试安装..."

    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      if command -v brew >/dev/null 2>&1; then
        brew install repo
      else
        echo "未找到 Homebrew 包管理器，请手动安装。"
        exit 1
      fi
    elif [[ "$(uname)" =~ ^Linux$ ]]; then
      # Linux
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y repo
      elif command -v yum >/dev/null 2>&1; then
        sudo yum update
        sudo yum install -y repo
      else
        echo "未找到包管理器，请手动安装。"
        exit 1
      fi
    else
      echo "不支持的操作系统。"
      exit 1
    fi

    echo "repo 已安装！"
  fi
}

function download_aosp_source() {
  aosp_source_path="http://mirrors.ustc.edu.cn/aosp-monthly/aosp-latest.tar"
  echo ">>>step 0 开始下载aosp源码, aosp源地址: $aosp_source_path"
  if curl -C - -o $DIR/aosp-latest.tar -O $aosp_source_path; then
    echo ">>>step 1 aosp源码下载成功"
  else
    echo ">>>step 1 aosp源码下载失败"
    exit 1
  fi

  if tar -xvf $DIR/aosp-latest.tar -C $DIR --strip 1; then
    echo ">>>step 2 aosp源码解压成功"
  else
    echo ">>>step 2 aosp源码解压失败"
    exit 1
  fi

  if rm -rf $DIR/aosp-latest.tar; then
    echo ">>>step 3 删除源码包成功"
  else
    echo ">>>step 3 删除源码包失败"
    exit 1
  fi

  if cd $MANIFEST && git checkout $REPO_BRANCH; then
    echo ">>>step 4 manifests同步成功"
    cd -
  else
    echo ">>>step 4 manifests同步失败, 您可以访问 https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/ 获取帮助"
    exit 1
  fi

  if cd $DIR && repo sync && repo start $REPO_BRANCH --all; then
    echo ">>>step 5 源码同步成功"
    cd -
  else
    echo ">>>step 5 源码同步失败, 您可以访问 https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/ 获取帮助, 或者访问 https://juejin.cn/post/7043063280704684063#heading-15 获取帮助"
    exit 1
  fi
  echo ”aosp源码下载完成,源码存储路径: $DIR“
}

function main() {
  pre_show_title
  show_title
  getparams
  check_params
  check_env
  download_aosp_source
}

main
