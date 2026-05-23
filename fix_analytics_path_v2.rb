#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'agentClaw.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主 target
target = project.targets.find { |t| t.name == 'agentClaw' }

# 获取 agentClaw 主组
agentclaw_group = project.main_group.children.find { |g| g.display_name == 'agentClaw' }

puts "步骤 1: 删除所有的 UMengAnalytics.swift 引用..."

# 查找并删除所有的 UMengAnalytics.swift 引用
files_to_remove = []
agentclaw_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXFileReference) && child.display_name == 'UMengAnalytics.swift'
    puts "  找到文件引用: #{child.path}"
    files_to_remove << child
  end
end

# 从编译阶段移除
files_to_remove.each do |file_ref|
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == file_ref
      target.source_build_phase.files.delete(build_file)
    end
  end
  file_ref.remove_from_project
  puts "  已删除"
end

puts "\n步骤 2: 创建正确的文件夹组结构..."

# 创建 Core 组（相对于 agentClaw 组）
core_group = agentclaw_group.children.find { |g| g.display_name == 'Core' }
if core_group.nil?
  core_group = agentclaw_group.new_group('Core', 'Core')
  puts "  创建 Core 组"
end

# 创建 Analytics 组（相对于 Core 组）
analytics_group = core_group.children.find { |g| g.display_name == 'Analytics' }
if analytics_group.nil?
  analytics_group = core_group.new_group('Analytics', 'Analytics')
  puts "  创建 Analytics 组"
end

puts "\n步骤 3: 添加文件（使用正确的相对路径）..."

# 文件相对于 Analytics 组的路径
file_ref = analytics_group.new_reference('UMengAnalytics.swift')

# 添加到编译阶段
target.source_build_phase.add_file_reference(file_ref)

puts "  ✅ 文件已添加"

# 验证
puts "\n验证路径:"
puts "  显示路径: #{file_ref.path}"
puts "  真实路径: #{file_ref.real_path}"
puts "  文件存在: #{File.exist?(file_ref.real_path)}"

# 保存项目
project.save

puts "\n✅ 修复完成！项目已保存。"
