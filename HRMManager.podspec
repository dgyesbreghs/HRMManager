Pod::Spec.new do |s|
  s.name                  = 'HRMManager'
  s.version               = '1.0.0'
  s.homepage              = 'https://github.com/dylangyesbreghs/HRMManager'
  s.license               = { :type => 'MIT', :file => 'LICENSE' }
  s.author                = 'Dylan Gyesbreghs'
  s.ios.deployment_target = '8.0'
  s.source                = { :git => 'https://github.com/dylangyesbreghs/HRMManager.git', :tag => 'v1.0.0' }
  s.source_files          = 'HRMManager/'
  s.requires_arc          = true
  s.summary               = 'The perfect Heart Rate Monitor Manager for iOS.'
  s.framework             = 'CoreBluetooth'
end