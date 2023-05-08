#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hls_downloader.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hls_downloader'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter project.'
  s.description      = <<-DESC
A new Flutter project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'
  
  s.subspec "LocalServer" do |ss|
    ss.source_files = "Classes/LocalServer/**/*.swift"
    ss.dependency "GCDWebServer/WebDAV"
  end

  s.subspec "AriaM3U8Downloader" do |sss|
    sss.source_files = "Classes/Downloader/**/*.swift"
    sss.dependency "RxSwift"
    sss.dependency "NSObject+Rx"
    sss.dependency "RxDataSources"
    sss.dependency "Alamofire"
    sss.dependency "RxAlamofire"
  end
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
