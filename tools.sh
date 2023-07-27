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
        printf "\r%${COLUMNS}s\r%s |%s%s| %s%% %s\n" "" "${prefix}" "${bar}" "${empty}" "${percent}" "${suffix}"
    else
        printf "\r%${COLUMNS}s\r%s |%s%s| %s%% %s" "" "${prefix}" "${bar}" "${empty}" "${percent}" "${suffix}"
    fi
}