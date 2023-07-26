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

    while read LINE
    do
        branch=`echo $LINE | grep "<superproject"`
        if [ "$branch" ]
        then
            branch_sec=${LINE#*revision=\"}
            DEFAULT_BRANCH=${branch_sec%%\"*}
            echo "当前repo主分支被设置为: $DEFAULT_BRANCH"
            break
        fi
    done  < $MANIFEST_XML_FILE
}

function push_source_to_gerrit() {
    # 首先向platform/manifests仓库推送文件
    cd $MANIFEST
    git push --no-thin ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/platform/manifests.git HEAD:$DEFAULT_BRANCH
    cd -

    # 按照xml文件汇入
    while read LINE; do
        # cd $DIR
        command_line=$(echo $LINE | grep "<project")
        if [ "$command_line" ]; then
            # echo $LINE
            reposity_name_sec=${LINE#*name=\"}
            reposity_path_sec=${LINE#*path=\"}

            if [ "$reposity_name_sec" ] && [ "$reposity_path_sec" ]; then
                reposity_name=${reposity_name_sec%%\"*}
                reposity_path=${reposity_path_sec%%\"*}

                src_path=$DIR/$reposity_path

                if [ -d "$src_path" ]; then
                    cd $src_path
                    pwd
                    
                    # git push ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/*
                    # git push ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* +refs/tags/*
                    
                    git push ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name +refs/heads/* 2>&1 | while IFS= read -r line; do
                      echo "$line"

                      # 判断输出中是否包含"error"关键字
                      if [[ $line == *"Unpack error"* ]]; then
                        echo "发现Unpack error错误,尝试重建git仓库"
                        find . -name ".git" | xargs rm -rf
                        git init --initial-branch $DEFAULT_BRANCH
                        git remote add origin ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name.git
                        git add -f .
                        git commit -am "init commit"
                        git push --set-upstream ssh://$GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP:$GERRIT_SERVER_PORT/$reposity_name $DEFAULT_BRANCH
                      elif [[ $line == *"unexpected disconnect"* ]]; then
                        echo "发现unexpected disconnect错误,该错误有可能是ssh的TCP连接错误,请尝试将下方字段写入 /etc/ssh/ssh_config , 并重新运行本脚本"
                        # echo 'sudo sh -c '\''echo "TCPKeepAlive yes" >> /etc/ssh/ssh_config'\'
                        # echo 'sudo sh -c '\''echo "ServerAliveInterval 60" >> /etc/ssh/ssh_config'\'
                        # echo 'sudo sh -c '\''echo "ServerAliveCountMax 60" >> /etc/ssh/ssh_config'\'
                        # echo '您可以访问  https://gerrit-review.googlesource.com/Documentation/config-ssh.html 了解更多信息, 或者尝试使用VPN'
                        exit 1
                      fi
                    done

                    cd -
                fi
            fi
        fi
    done <$MANIFEST_XML_FILE
}

pre_show_title
show_title
getparams
check_env
pre_push
push_source_to_gerrit