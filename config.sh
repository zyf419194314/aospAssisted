#!/bin/sh

CONFIG_FILE=config.txt
VERSION=0.1.0

# 函数：set_config
# 功能：设置配置文件
# 参数：$1 配置项的名称，$2 配置项的值
# 返回值：无
set_config() {
  key=$1
  value=$2

  # 如果配置文件不存在，创建一个空文件
  if [ ! -f $CONFIG_FILE ]; then
    touch $CONFIG_FILE
  fi

  # 判断key是否存在
  if grep "^$key=" $CONFIG_FILE >/dev/null; then
    # 如果存在，使用sed替换原有的值
    sed -i "s/^$key=.*/$key=$value/" $CONFIG_FILE
  else
    # 如果不存在，直接在末尾添加配置项
    echo "$key=$value" >>$CONFIG_FILE
  fi
}

# 函数：get_config
# 功能：获取配置文件
# 参数：$1 配置项的名称
# 返回值：配置项的值，如果不存在则返回空字符串
get_config() {
  key=$1
  value=$(grep "^$key=" $CONFIG_FILE | cut -d= -f2)

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo ""
  fi
}


get_version() {
  echo v"$VERSION"
}