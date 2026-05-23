#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'agentClaw.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主 target
target = project.targets.find { |t| t.name == 'agentClaw' }

# 获取 agentClaw 主组
agentclaw_group = project.main_group.children.find { |g| g.display_name == 'agentClaw' }

puts "步骤 1: 删除错误的文件引用..."

# 查找并删除所有的 UMengAnalytics.swift 引用
files_to_remove = []
agentclaw_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXFileReference) && child.display_name == 'UMengAnalytics.swift'
    puts "  找到错误的文件引用: #{child.path}"
    files_to_remove << child
  end
end

# 从编译阶段移除
files_to_remove.each do |file_ref|
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == file_ref
      target.source_build_phase.files.delete(build_file)
      puts "  从编译阶段移除"
    end
  end
  file_ref.remove_from_project
  puts "  从项目中移除"
end

# 同时删除可能创建错误的 Core 和 Analytics 组
puts "\n步骤 2: 清理错误的文件夹组..."
core_group = agentclaw_group.children.find { |g| g.display_name == 'Core' }
if core_group
  core_group.clear
  core_group.remove_from_project
  puts "  已删除 Core 组"
end

puts "\n步骤 3: 直接添加文件到 agentClaw 主组..."

# 确认文件实际存在的位置
actual_file_path = 'agentClaw/Core/Analytics/UMengAnalytics.swift'
full_path = File.join(Dir.pwd, actual_file_path)

if File.exist?(full_path)
  puts "  文件存在: #{full_path}"

  # 直接在 agentClaw 主组中添加文件，使用相对路径
  file_ref = agentclaw_group.new_reference(actual_file_path)
  file_ref.source_tree = '<group>'

  # 添加到编译阶段
  target.source_build_phase.add_file_reference(file_ref)

  puts "  ✅ 文件已正确添加"
else
  puts "  ❌ 文件不存在: #{full_path}"
  exit 1
end

# 保存项目
project.save

puts "\n✅ 修复完成！项目已保存。"
puts "请在 Xcode 中重新打开项目并编译。"
