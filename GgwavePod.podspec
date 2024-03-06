Pod::Spec.new do |spec|

  spec.name         = "GgwavePod"
  spec.version      = "0.0.1"
  spec.summary      = "A CocoaPods library written in Swift"

  spec.description  = <<-DESC
This CocoaPods library helps you perform calculation.
                   DESC

  spec.homepage     = "https://github.com/fahidattique55"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Fahid Attique" => "fahidattique55@gmail.com" }

  spec.ios.deployment_target = "14.0"
  spec.swift_version = "5.0"

  spec.source        = { :git => "https://github.com/fahidattique55", :tag => "#{spec.version}" }
  spec.source_files  = "GgwavePod/**/*.{swift,h,m,c,cc,mm,cpp,hpp}"

end