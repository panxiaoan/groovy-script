#!/usr/bin/expect

set timeout 30

# 从环境变量中获取：跳板机信息
set jump_args [split $env(JUMP) |]
set jump_port [lindex $jump_args 0]
set jump_user [lindex $jump_args 1]
set jump_host [lindex $jump_args 2]
set jump_passwd [lindex $jump_args 3]

# 从环境变量中获取：内网目标服务器信息
set dest_args [split $env(DEST) |]
set dest_port [lindex $dest_args 0]
set dest_user [lindex $dest_args 1]
set dest_host [lindex $dest_args 2]
set dest_passwd [lindex $dest_args 3]

# 连接到跳板机
spawn ssh -p $jump_port $jump_user@$jump_host
expect {
    timeout { puts "连接跳板机超时"; exit 1 }
    eof { puts "连接跳板机失败"; exit 1 }
    "(yes/no)?" {
        send "yes\n"
        exp_continue
    }
    "password:" {
        stty -echo
        send "$jump_passwd\r"
        stty echo
        # 等待跳板机提示符
        expect "$jump_user@"
    }
    default {
        puts "未知响应: $expect_out(buffer)"
        exit 1
    }
}

# 通过跳板机上连接到内网服务器
send "ssh -p $dest_port $dest_user@$dest_host\r"
expect {
    timeout { puts "连接内网服务器超时"; exit 1 }
    eof { puts "连接内网服务器失败"; exit 1 }
    "(yes/no)?" {
        send "yes\n"
        exp_continue
    }
    "password:" {
        stty -echo
        send "$dest_passwd\r"
        stty echo
    }
}

interact