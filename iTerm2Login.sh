#!/usr/bin/expect

set timeout 30

# 安全地获取参数（防止特殊字符被提前解析）
set args [split $env(ARGS) |]

set port [lindex $args 0]
set user [lindex $args 1]
set host [lindex $args 2]
set password [lindex $args 3]

spawn ssh -p $port $user@$host

expect {
    "(yes/no)?" {
        send "yes\n"
        exp_continue
    }
    "password:" {
        stty -echo
        send "$password\r"
        stty echo
    }
}

interact