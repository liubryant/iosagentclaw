#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'agentClaw.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主 target
target = project.targets.find { |t| t.name == 'agentClaw' }

# 获取 agentClaw 主组
agentclaw_group = project.main_group.children.find { |g| g.display_name == 'agentClaw' }

if agentclaw_group.nil?
  puts "❌ 找不到 agentClaw 组"
  exit 1
end

# 查找或创建 Core 组
core_group = agentclaw_group.children.find { |g| g.display_name == 'Core' }

if core_group.nil?
  puts "创建 Core 文件夹组..."
  core_group = agentclaw_group.new_group('Core', 'agentClaw/Core')
end

# 查找或创建 Analytics 组
analytics_group = core_group.children.find { |g| g.display_name == 'Analytics' }

if analytics_group.nil?
  puts "创建 Analytics 文件夹组..."
  analytics_group = core_group.new_group('Analytics', 'agentClaw/Core/Analytics')
end

# 添加 UMengAnalytics.swift 文件
file_path = 'agentClaw/Core/Analytics/UMengAnalytics.swift'

# 检查文件是否已经存在于项目中（在任何位置）
all_files = []
agentclaw_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    all_files << child.display_name
  end
end

if all_files.include?('UMengAnalytics.swift')
  puts "⚠️  UMengAnalytics.swift 已经在项目中"
else
  puts "添加 UMengAnalytics.swift 到项目..."
  file_ref = analytics_group.new_reference(file_path)

  # 将文件添加到编译阶段
  target.source_build_phase.add_file_reference(file_ref)

  puts "✅ UMengAnalytics.swift 已成功添加到 Xcode 项目中！"
end

# 保存项目
project.save

puts "✅ 项目已保存！请在 Xcode 中重新打开项目并编译。"
