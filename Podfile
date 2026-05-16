platform :osx, '15.7'

target 'notchEye' do
  use_frameworks!
  pod 'lottie-ios'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['CODE_SIGN_IDENTITY'] = '-'
    end
  end
end
