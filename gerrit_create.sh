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
    echo "#                    AOSP源码辅助系统(`get_version`)                     #"
    echo "#                                                                 #"
    echo "#                 ** 创建aosp仓库到私有gerrit **                  #"
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
    OUTPUT_PROJECT_LIST_FILE_NAME=$DIR/project_list_name
    OUTPUT_PROJECT_LIST_FILE_PATH=$DIR/project_list_path

    read -p "请输入gerrit服务器地址[支持域名&IP] (默认为: $(get_config GERRIT_SERVER_IP)):" GERRIT_SERVER_IP
    GERRIT_SERVER_IP="${GERRIT_SERVER_IP:-$(get_config GERRIT_SERVER_IP)}"
    set_config GERRIT_SERVER_IP "$GERRIT_SERVER_IP"

    read -p "请输入gerrit 用户名(默认为: $(get_config GERRIT_SERVER_USERNAME)):" GERRIT_SERVER_USERNAME
    GERRIT_SERVER_USERNAME="${GERRIT_SERVER_USERNAME:-$(get_config GERRIT_SERVER_USERNAME)}"
    set_config GERRIT_SERVER_USERNAME "$GERRIT_SERVER_USERNAME"

    while true; do
        read -p "请输入gerrit ssh或http端口号(默认为: $(get_config GERRIT_SERVER_PORT)):" GERRIT_SERVER_PORT
        GERRIT_SERVER_PORT="${GERRIT_SERVER_PORT:-$(get_config GERRIT_SERVER_PORT)}"
        if [[ $GERRIT_SERVER_PORT =~ ^[0-9]+$ ]] && [[ $GERRIT_SERVER_PORT -ge 1 ]] && [[ $GERRIT_SERVER_PORT -le 65535 ]]; then
            break
        else
            echo "端口号输入不正确,请重新输入(1-65535)"
        fi
    done
    set_config GERRIT_SERVER_PORT "$GERRIT_SERVER_PORT"

    read -p "请输入指定的xml文件(例如default.xml,本脚本默认在.repo/manifests/文件夹下查找该文件,默认为: $(get_config GERRIT_MANIFEST_XML_FILE)):" GERRIT_MANIFEST_XML_FILE
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

 
function getNameAndPath()
{
    echo > $OUTPUT_PROJECT_LIST_FILE_NAME
    echo > $OUTPUT_PROJECT_LIST_FILE_PATH
 
    while read LINE
    do
        command_line=`echo $LINE | grep "<project"`
        if [ "$command_line" ]
        then
            #echo $LINE
 
            reposity_name_sec=${LINE#*name=\"}
            reposity_path_sec=${LINE#*path=\"}
 
            if [ "$reposity_name_sec" ] && [ "$reposity_path_sec" ]
            then
                reposity_name=${reposity_name_sec%%\"*}
                reposity_path=${reposity_path_sec%%\"*}
                echo "$reposity_name" >> $OUTPUT_PROJECT_LIST_FILE_NAME
                echo "$reposity_path" >> $OUTPUT_PROJECT_LIST_FILE_PATH
            fi
        fi
    done  < $MANIFEST_XML_FILE
}
 
function creatEmptyGerritProject()
{
    # >>> 建立父仓库 AOSP，方便gerrita权限管理
    progress_bar 1 0 'debug' 'step 1' 'aosp源码父仓库 AOSP 创建中...'
    output=$(ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project --permissions-only AOSP 2>&1)
    ret=$?

    if [ $ret -eq 0 ]; then
      # 命令执行成功
      progress_bar 1 1 'success' 'step 1' 'aosp源码父仓库 AOSP 创建成功'
    elif [[ "$output" == *"fatal: Project already exists"* ]]; then
      # 错误信息为 "fatal: Project already exists"，跳过
      progress_bar 1 0 'warn' 'step 1' 'Project already exists'
      progress_bar 1 1 'success' 'step 1' 'aosp源码父仓库 AOSP 创建成功'
    else
      # 其他错误信息，退出
      progress_bar 1 0 'step 1' 'aosp源码父仓库 AOSP 创建失败'
      exit 1
    fi
    # <<< 建立父仓库 AOSP，方便gerrita权限管理

    # >>> 建立单独的 manifests 仓库,风格与AOSP保持一致
    progress_bar 2 0 'debug' 'step 2' 'aosp源码 manifests 仓库创建中...'
    progress_bar 2 0 'debug' 'step 2' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project platform/manifests"
    output=$(ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project platform/manifests 2>&1)
    ret=$?
    if [ $ret -eq 0 ]; then
      # 命令执行成功
      progress_bar 2 1 'debug' 'step 2' 'aosp源码 manifests 仓库创建成功'
    elif [[ "$output" == *"fatal: Project already exists"* ]]; then
      # 错误信息为 "fatal: Project already exists"，跳过
      progress_bar 2 0 'warn' 'step 2' 'Project already exists'
      progress_bar 2 1 'debug' 'step 2' 'aosp源码 manifests 仓库创建成功'
    else
      # 其他错误信息，退出
      progress_bar 2 0 'step 2' 'aosp源码 manifests 仓库创建失败'
      exit 1
    fi

    progress_bar 2 1 'debug' 'step 2' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP platform/manifests"
    output=$(ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP platform/manifests 2>&1)
    ret=$?
    if [ $ret -eq 0 ]; then
      progress_bar 2 2 'success' 'step 2' '成功设置 platform/manifests 仓库的父仓库为 AOSP'
    else
      progress_bar 2 1 'success' 'step 2' '设置 platform/manifests 仓库的父仓库为 AOSP 失败'
      exit 1
    fi
    # <<< 建立单独的 manifests 仓库,风格与AOSP保持一致

    # >>> 根据配置文件创建仓库
    total=$(wc -l < $OUTPUT_PROJECT_LIST_FILE_NAME)
    current=0
    progress_bar $total $current 'debug' 'step 3' 'aosp源码仓库创建中...'
    for i in `cat $OUTPUT_PROJECT_LIST_FILE_NAME`;
    do
        current=$(($current+1))
        progress_bar $total $current 'debug' 'step 3' $i
        progress_bar $total $current 'debug' 'step 3' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project $i"
        output=$(ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project $i 2>&1)
        ret=$?
        if [ $ret -eq 0 ]; then
          progress_bar $total $current 'debug' 'step 3' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i"
        elif [[ "$output" == *"fatal: Project already exists"* ]]; then
          # 错误信息为 "fatal: Project already exists"，跳过
          progress_bar $total $current 'debug' 'step 3' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i"
        else
          progress_bar $total $current 'err' 'step 3' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i"
          echo $output
          exit 1
        fi

        progress_bar $total $current 'debug' 'step 3' "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i"
        ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i
    done
    progress_bar $total $current 'success' 'step 3' 'aosp源码仓库创建成功'
    # <<< 根据配置文件创建仓库
}
 
function removeFiles()
{
    rm -rf $OUTPUT_PROJECT_LIST_FILE_NAME
    rm -rf $OUTPUT_PROJECT_LIST_FILE_PATH
}
 
pre_show_title
show_title
getparams
check_env
getNameAndPath
creatEmptyGerritProject
removeFiles
