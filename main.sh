#!/bin/bash

source config.sh

function pre_show_title() {
  clear
}

# 展示title
function show_menu() {
  DATE=$(date '+%Y-%m-%d %H:%M:%S')
  echo
  echo "#=================================================================#"
  echo "#                    AOSP源码辅助系统(`get_version`)                     #"
  echo "#                                                                 #"
  echo "#                      $DATE                        #"
  echo "#=================================================================#"
  echo
  echo "1. 下载aosp源码"
  echo "2. 编译aosp源码(未测试)"
  echo "3. 创建aosp仓库到私有gerrit"
  echo "4. 汇入aosp源码到私有gerrit"
  echo "5. 从私有gerrit删除aosp源码"
  echo "请在下方选择您的操作(1-5):"
}

function select_option() {
  read option

  case $option in
  1)
    bash aosp_download.sh
    ;;
  2)
    bash aosp_build.sh
    ;;
  3)
    bash gerrit_create.sh
    ;;
  4)
    bash gerrit_push.sh
    ;;
  5)
    bash gerrit_delete.sh
    ;;
  *)
    echo "无效选项"
    ;;
  esac
}

pre_show_title
show_menu
select_option
