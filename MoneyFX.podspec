Pod::Spec.new do |s|
  s.name              = "MoneyFX"
  s.version           = "1.0.0"
  s.summary           = "Swift types for working with Foreign Exchange."
  s.description       = <<-DESC
  
  FX is a Swift cross platform framework for iOS, watchOS, tvOS and OS X. 
  
  It provides functionality to represent foreign exchange transactions.

                       DESC
  s.homepage          = "https://github.com/danthorpe/FX"
  s.license           = 'MIT'
  s.author            = { "Daniel Thorpe" => "@danthorpe" }
  s.source            = { :git => "https://github.com/danthorpe/FX.git", :tag => s.version.to_s }
  s.module_name       = 'MoneyFX'
  s.documentation_url = 'http://docs.danthorpe.me/fx/1.0.0/index.html'
  s.social_media_url  = 'https://twitter.com/danthorpe'
  s.requires_arc      = true
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = [
    'Sources/Shared/*.swift', 
  ]
    
  s.dependency 'Money'
  s.dependency 'Result'
  s.dependency 'SwiftyJSON'
end

