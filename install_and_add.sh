#!/bin/bash

echo "正在安装 xcodeproj gem..."
sudo gem install xcodeproj

echo "正在将 UMengAnalytics.swift 添加到项目..."
cd ~/Desktop/agentClaw
ruby add_analytics_to_project.rb

echo "完成！请在 Xcode 中重新编译项目。"
