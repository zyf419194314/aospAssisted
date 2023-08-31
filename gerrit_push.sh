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
  echo "#                 ** 汇入aosp源码到私有gerrit **                  #"
  echo "#                      $DATE                        #"
  echo "#=================================================================#"
  echo
}

function getparams() {
  read -p "请输入aosp目录存放地址[支持 相对路径/绝对路径] (默认为: $(get_config DIR)):" DIR
  DIR="${DIR:-$(get_config DIR)}"
  DIR="${DIR%/}"
  set_config DIR "$DIR"

  MANIFEST=$DIR/.repo/manifests

  read -p "请输入gerrit服务器地址[支持域名&IP] (默认为: $(get_config GERRIT_SERVER_IP)):" GERRIT_SERVER_IP
  GERRIT_SERVER_IP="${GERRIT_SERVER_IP:-$(get_config GERRIT_SERVER_IP)}"
  set_config GERRIT_SERVER_IP "$GERRIT_SERVER_IP"

  read -p "请输入gerrit 用户名(默认为: $(get_config GERRIT_SERVER_USERNAME)):" GERRIT_SERVER_USERNAME
  GERRIT_SERVER_USERNAME="${GERRIT_SERVER_USERNAME:-$(get_config GERRIT_SERVER_USERNAME)}"
  set_config GERRIT_SERVER_USERNAME "$GERRIT_SERVER_USERNAME"

  read -p "请输入gerrit 推送使用协议[支持 http / ssh] (默认为: $(get_config GERRIT_SERVER_PROTOCOL)):" GERRIT_SERVER_PROTOCOL
  GERRIT_SERVER_PROTOCOL="${GERRIT_SERVER_PROTOCOL:-$(get_config GERRIT_SERVER_PROTOCOL)}"
  set_config GERRIT_SERVER_PROTOCOL "$GERRIT_SERVER_PROTOCOL"

  # 走http协议免密，需要获取http密码
  if [ "$GERRIT_SERVER_PROTOCOL" = "http" ]; then
    read -p "请输入gerrit http密码 (默认为: $(get_config GERRIT_SERVER_HTTP_PWD)):" GERRIT_SERVER_HTTP_PWD
    GERRIT_SERVER_HTTP_PWD="${GERRIT_SERVER_HTTP_PWD:-$(get_config GERRIT_SERVER_HTTP_PWD)}"
    GERRIT_SERVER_HTTP_PWD=$(url_encode "$GERRIT_SERVER_HTTP_PWD")
    set_config GERRIT_SERVER_HTTP_PWD "$GERRIT_SERVER_HTTP_PWD"
  fi

  while true; do
    read -p "请输入gerrit 端口号(默认为: $(get_config GERRIT_SERVER_PORT)):" GERRIT_SERVER_PORT
    GERRIT_SERVER_PORT="${GERRIT_SERVER_PORT:-$(get_config GERRIT_SERVER_PORT)}"
    if [[ $GERRIT_SERVER_PORT =~ ^[0-9]+$ ]] && [[ $GERRIT_SERVER_PORT -ge 1 ]] && [[ $GERRIT_SERVER_PORT -le 65535 ]]; then
      break
    else
      echo "端口号输入不正确,请重新输入(1-65535)"
    fi
  done
  set_config GERRIT_SERVER_PORT "$GERRIT_SERVER_PORT"

  read -p "请输入指定的xml文件(默认为: $(get_config GERRIT_MANIFEST_XML_FILE)):" GERRIT_MANIFEST_XML_FILE
  GERRIT_MANIFEST_XML_FILE="${GERRIT_MANIFEST_XML_FILE:-$(get_config GERRIT_MANIFEST_XML_FILE)}"
  MANIFEST_XML_FILE=$MANIFEST/$GERRIT_MANIFEST_XML_FILE
  set_config GERRIT_MANIFEST_XML_FILE "$GERRIT_MANIFEST_XML_FILE"
}

function check_env() {
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

function pre_push() {
  git config --global http.postBuffer 2000000000
  git config --global https.postBuffer 2000000000
  git config --global ssh.postBuffer 2000000000

  echo $MANIFEST_XML_FILE

  while read LINE; do
    branch=$(echo $LINE | grep "<default")
    if [ "$branch" ]; then
      branch_sec=${LINE#*revision=\"}
      DEFAULT_BRANCH=${branch_sec%%\"*}
      echo "当前repo主分支被设置为: $DEFAULT_BRANCH"
      break
    fi
  done <$MANIFEST_XML_FILE
}

function push_source_to_gerrit() {
  # 首先向platform/manifests仓库推送文件
  progress_bar 1 0 'debug' 'step 1' '向platform/manifests仓库推送文件中...'
  cd $MANIFEST
  if [ "$GERRIT_SERVER_PROTOCOL" = "http" ]; then
    output=$(git push $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME:$GERRIT_SERVER_HTTP_PWD@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/platform/manifests HEAD:$DEFAULT_BRANCH 2>&1)
  else
    output=$(git push $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/platform/manifests HEAD:$DEFAULT_BRANCH 2>&1)
  fi
  if [ $? -ne 0 ]; then
    progress_bar 1 0 'err' 'step 1' $output
    exit 1
  fi
  progress_bar 1 1 'success' 'step 1' '向platform/manifests仓库推送文件完成'
  cd -

  # 按照xml文件汇入
  total=$(wc -l <$MANIFEST_XML_FILE)
  current=0
  progress_bar $total $current 'debug' 'step 2' 'aosp源码仓库推送中...'
  while read LINE; do
    command_line=$(echo $LINE | grep "<project")
    if [ "$command_line" ]; then
      #     # echo $LINE
      reposity_name_sec=${LINE#*name=\"}
      reposity_path_sec=${LINE#*path=\"}

      if [ "$reposity_name_sec" ] && [ "$reposity_path_sec" ]; then
        reposity_name=${reposity_name_sec%%\"*}
        reposity_path=${reposity_path_sec%%\"*}

        src_path=$DIR/$reposity_path

        if [ -d "$src_path" ]; then
          cd $src_path

          # git push $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME:$GERRIT_SERVER_HTTP_PWD@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/*

          # git push ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/*

          current=$((current + 1))
          progress_bar $total $current 'debug' 'step 2' "git push $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/*"

          # output=$(git push ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* 2>&1)
          if [ "$GERRIT_SERVER_PROTOCOL" = "http" ]; then
            output=$(git push $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME:$GERRIT_SERVER_HTTP_PWD@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* 2>&1)
          else
            output=$(git push ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* 2>&1)
          fi

          if [ $? -ne 0 ]; then
            if [[ $output == *"error Missing commit"* ]]; then
              progress_bar $total $current 'warn' 'step 2' '发现error Missing commit错误,请尝试修改 gerrit.config 文件中的 receive.maxBatchCommits 字段为更大值, 并重启gerrit, 当前尝试重建git仓库 \n'
              find . -name ".git" | xargs rm -rf
              # git init -b $DEFAULT_BRANCH
              git init

              git checkout -b $DEFAULT_BRANCH
              git remote add origin $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name
              git add -f .
              git commit -am "init commit"

              if [ "$GERRIT_SERVER_PROTOCOL" = "http" ]; then
                git push -f $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME:$GERRIT_SERVER_HTTP_PWD@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* 2>&1
              else
                git push -f $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* 2>&1
              fi
            elif [[ $output == *"unexpected disconnect"* ]]; then
              progress_bar $total $current 'err' 'step 2' '发现unexpected disconnect错误,请尝试修改 gerrit.config 文件中的 sshd.TCPKeepAlive = yes, 并重启gerrit, 或者使用http 协议重新push'
              echo "错误详情如下:"
              echo $output
              exit 1
            else
              progress_bar $total $current 'err' 'step 2' $output
              echo "错误详情如下:"
              echo $output
              exit 1
            fi
          fi

          cd - >/dev/null
        fi
      fi
    fi
  done <$MANIFEST_XML_FILE

  progress_bar $current $current 'success' 'step 2' 'aosp源码仓库推送完成'

  echo "推送完成，您可以在gerrit上查看提交状态"
  echo "init commit: "
  echo "repo init -u $GERRIT_SERVER_PROTOCOL://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/platform/manifests/ -b $DEFAULT_BRANCH"
}

pre_show_title
show_title
getparams
check_env
pre_push
push_source_to_gerrit
