#!/bin/sh

echo `date` >> /tmp/uhost.log &&

sed -i "" "/# GitHub520 Host Start/,/# Github520 Host End/d" /etc/hosts && curl https://raw.hellogithub.com/hosts >> /etc/hosts

killall -HUP mDNSResponder

echo 'finish' >> /tmp/uhost.log