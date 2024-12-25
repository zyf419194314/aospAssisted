#!/bin/bash

# 进度条 (total, progress, prefix, suffix, decimals, length, fill)
# param total 总进度
# param progress 当前进度
# param level 进度条后缀等级
# param prefix 进度条前缀
# param suffix 进度条后缀
# param decimals 进度条后缀小数位数
# param length 进度条长度
# param fill 进度条填充字符
progress_bar() {
    local total=$1
    local progress=$2
    local level=${3:-"debug"}    # 默认值为 "debug"
    local prefix=${4:-"进度:"}   # 默认值为 "进度:"
    local suffix=${5:-"完成:"}    # 默认后缀为 "完成"
    local decimals=${6:-1}       # 默认值为 1
    local length=${7:-50}        # 默认值为 50
    local fill=${8:-"█"}         # 默认值为 "█"

    percent=$(awk "BEGIN { pc=100*${progress}/${total}; i=int(pc); print (pc-i<0.5)?i:i+1 }")
    filled_length=$(awk "BEGIN { fl=${length}*${progress}/${total}; print int(fl < 1 ? 1 : fl) }")
    bar=$(printf "%0.s${fill}" $(seq 1 ${filled_length}))
    empty=$(printf "%0.s-" $(seq 1 $(( ${length} - ${filled_length} )) ))

    case ${level} in
        "warn")
            suffix="🔶警告: ${suffix}"
            ;;
        "err")
            suffix="❌错误: ${suffix} \n"
            ;;
        "success")
            suffix="✅ ${suffix}"
            ;;
    esac

    if [[ ${progress} -eq ${total} ]]; then
        printf "\r%${COLUMNS}s\r%s |%s%s| %s%% %s\\n" "" "${prefix}" "${bar}" "${empty}" "${percent}" "${suffix}"
    else
        printf "\r%${COLUMNS}s\r%s |%s%s| %s%% %s" "" "${prefix}" "${bar}" "${empty}" "${percent}" "${suffix}"
    fi
}

# 环境检查
function check_env() {
  echo ">>> 检查是否已安装 jq..."
  if command -v jq >/dev/null 2>&1; then
    echo "jq 已安装！"
  else
    echo "jq 未安装，正在尝试安装..."

    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      if command -v brew >/dev/null 2>&1; then
        brew install jq
      else
        echo "未找到 Homebrew 包管理器，请手动安装。"
        exit 1
      fi
    elif [[ "$(uname)" =~ ^Linux$ ]]; then
      # Linux
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y jq
      elif command -v yum >/dev/null 2>&1; then
        sudo yum update
        sudo yum install -y jq
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y jq
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu jq
      elif command -v zypper >/dev/null 2>&1; then
        sudo zypper refresh
        sudo zypper install -y jq
      else
        echo "未找到包管理器，请手动安装。"
        exit 1
      fi
    else
      echo "不支持的操作系统。"
      exit 1
    fi

    echo "jq 已安装！"
  fi
}

# url编码
url_encode() {
    local string="$1"
    local encoded_string=""

    check_env

    # 判断字符串是否为URL编码
    if [ "$(printf "%s" "$string" | grep -E '[^%a-zA-Z0-9_-]')" ]; then
        # 字符串不是URL编码，进行URL编码处理
        encoded_string=$(printf "%s" "$string" | jq -sRr @uri)
    else
        # 字符串已经是URL编码，直接返回原字符串
        encoded_string="$string"
    fi

    echo "$encoded_string"
}