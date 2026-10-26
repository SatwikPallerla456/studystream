Pod::Spec.new do |s|
  s.name = 'tangerine_vlc'
  s.version = '1.0.0'
  s.summary = 'Owned VideoLAN libVLC playback sessions for Tangerine.'
  s.description = s.summary
  s.homepage = 'https://www.videolan.org/vlc/libvlc.html'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = { 'Tangerine' => 'development@localhost' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'MobileVLCKit', '3.6.0'
  s.platform = :ios, '15.0'
  s.frameworks = 'AVFoundation', 'UIKit', 'AVKit'
end
