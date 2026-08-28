#!/bin/bash
# 配置区域
RETRY_COUNT=2          # 网络失败重试次数
REBASE_RETRY_COUNT=1   # divergent branches 错误重试次数

# 解析参数
USE_FULL_HISTORY=false
if [[ "$1" == "--full" ]]; then
    USE_FULL_HISTORY=true
fi
# 使用当前目录，不再硬编码路径
TARGET_DIR="."

# 颜色打印函数
printfColor() {
    local color_code="\e[0m"
    case "$1" in
        "red") color_code="\e[31m" ;;
        "green") color_code="\e[32m" ;;
        "yellow") color_code="\e[33m" ;;
        "blue") color_code="\e[34m" ;;
        "purple") color_code="\e[35m" ;;
        "cyan") color_code="\e[36m" ;;
        "grey") color_code="\e[37m" ;;
        *) color_code="\e[0m" ;;
    esac
    shift
    printf "$color_code%s\e[0m\n" "$*"
}

# 检查工作区是否有未提交的更改
is_working_dir_dirty() {
    ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet HEAD 2>/dev/null
}

# 核心更新函数
gitpull() {
    local root_dir
    root_dir="$(cd "$TARGET_DIR" && pwd)"

    # 检查目录是否存在
    if [ ! -d "$root_dir" ]; then
        printfColor "red" "错误：目录不存在 -> $root_dir"
        return 1
    fi

    printfColor "blue" ">>> 开始扫描目录：$root_dir"
    if [ "$USE_FULL_HISTORY" = true ]; then
        printfColor "cyan" ">>> 模式：完整历史记录 (Full History)"
    else
        printfColor "cyan" ">>> 模式：浅拉取 (Depth=1)"
    fi

    # 构建 git pull 的基础参数
    local pull_args="--recurse-submodules"
    if [ "$USE_FULL_HISTORY" = false ]; then
        pull_args="$pull_args --depth=1"
    fi

    # 遍历子目录
    for subdir in "$root_dir"/*/; do
        # 检查是否为目录
        if [ -d "$subdir" ]; then
            # 进入目录
            cd "$subdir" || continue

            # 获取目录名
            local dirname
            dirname=$(basename "$subdir")

            # 检查是否为 git 仓库
            if [ -d ".git" ]; then
                printfColor "cyan" "--------------------------------------------------"
                printfColor "grey" "正在更新: $dirname"

                # 执行 pull，带重试逻辑
                local success=false
                local attempt=0
                local output=""

                while [ "$success" = false ] && [ "$attempt" -lt $((RETRY_COUNT + REBASE_RETRY_COUNT + 1)) ]; do
                    attempt=$((attempt + 1))

                    # 第一阶段：普通 pull 重试
                    if [ "$attempt" -le "$RETRY_COUNT" ]; then
                        output=$(git pull $pull_args 2>&1)
                        local exit_code=$?

                        if [ $exit_code -eq 0 ]; then
                            success=true
                            break
                        fi

                        # 检查是否是 "divergent branches" 错误
                        if echo "$output" | grep -q "Need to specify how to reconcile divergent branches"; then
                            printfColor "yellow" "检测到分叉分支(divergent branches)，使用 --rebase 重试..."
                            # 不 break，继续循环，下一次会走 rebase 路径
                        else
                            # 其他错误，走重试逻辑
                            if [ "$attempt" -lt "$RETRY_COUNT" ]; then
                                printfColor "red" "尝试 $attempt 失败，正在重试... (exit code: $exit_code)"
                                sleep 2
                            fi
                        fi
                    else
                        # 超过普通重试次数，使用 --rebase 重试
                        local rebase_attempt=$((attempt - RETRY_COUNT))
                        printfColor "yellow" "普通拉取失败，使用 rebase 重试 (尝试 $rebase_attempt)... "

                        # 检查是否有未暂存的更改，如果有则自动 stash
                        local stashed=false
                        if is_working_dir_dirty; then
                            printfColor "yellow" "检测到未提交的更改，自动 stashing..."
                            if git stash push -m "tmp_autostash_before_pull" 2>&1; then
                                stashed=true
                            else
                                printfColor "red" "自动 stashing 失败，无法使用 rebase 模式"
                            fi
                        fi

                        # 执行 rebase pull
                        output=$(git pull $pull_args --rebase 2>&1)
                        local exit_code=$?

                        if [ $exit_code -eq 0 ]; then
                            # 成功，恢复之前暂存的文件
                            if [ "$stashed" = true ]; then
                                printfColor "yellow" "恢复之前暂存的文件..."
                                if ! git stash pop 2>&1; then
                                    printfColor "yellow" "注意：stash pop 可能产生冲突，请手动处理未合并的文件"
                                fi
                            fi
                            success=true
                            break
                        fi

                        # rebase 也失败了，尝试恢复 stash
                        if [ "$stashed" = true ]; then
                            printfColor "yellow" "Rebase 失败，尝试恢复暂存的文件..."
                            git stash pop --index 2>&1 || git stash pop 2>&1
                        fi

                        # rebase 失败
                        printfColor "red" "Rebase 模式也失败: $output"
                        if [ "$rebase_attempt" -lt "$REBASE_RETRY_COUNT" ]; then
                            sleep 2
                        fi
                    fi
                done

                if [ "$success" = true ]; then
                    printfColor "green" "成功: $dirname 更新完成"
                else
                    printfColor "red" "失败: $dirname 更新失败 (可能已归档或网络不通)，已跳过。"
                fi
            else
                printfColor "grey" "忽略 (非Git仓库): $dirname"
            fi
            
            # 回到上级目录，确保下一轮循环路径正确
            cd "$root_dir" || break
        fi
    done

    printfColor "green" ">>> 所有任务处理完毕"
}

# 执行入口
gitpull
