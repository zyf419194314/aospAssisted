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
    MANIFEST_XML_FILE=$MANIFEST/default.xml
    OUTPUT_PROJECT_LIST_FILE_NAME=$DIR/project_list_name
    OUTPUT_PROJECT_LIST_FILE_PATH=$DIR/project_list_path

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
    # 建立父仓库 AOSP，方便gerrita权限管理
    echo "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project --permissions-only AOSP"
    if ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project --permissions-only AOSP; then
        echo ">>>step 1 aosp源码父仓库 AOSP 创建成功"
    else
        echo ">>>step 1 aosp源码父仓库 AOSP 创建失败"
        exit 1
    fi
    

    # 建立单独的 manifests 仓库,风格与AOSP保持一致
    echo "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project platform/manifests"
    if ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project platform/manifests; then
        echo ">>>step 2 aosp源码 manifests 仓库创建成功"
    else
        echo ">>>step 2 aosp源码 manifests 仓库创建失败"
        exit 1
    fi

    echo "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP platform/manifests"
    ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP platform/manifests

    for i in `cat $OUTPUT_PROJECT_LIST_FILE_NAME`;
    do
        echo $i
        echo "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project $i"
        ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit create-project $i
        echo "ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i"
        ssh -p $GERRIT_SERVER_PORT $GERRIT_SERVER_USERNAME@$GERRIT_SERVER_IP gerrit set-project-parent --parent AOSP $i
    done
    echo ">>>step 3 aosp源码仓库创建成功"
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
