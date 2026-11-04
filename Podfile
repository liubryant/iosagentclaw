# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'agentClaw' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # 友盟统计 SDK
  pod 'UMCommon'           # 友盟基础库

  # 穿山甲广告 SDK
  pod 'Ads-CN-Beta', '7.6.0.3', :subspecs => ['CSJMediation-Only']

  target 'agentClawTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'agentClawUITests' do
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
