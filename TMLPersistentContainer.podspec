Pod::Spec.new do |s|
  s.name         = "TMLPersistentContainer"
  s.version      = "0.1"
  s.summary      = ""
  s.description  = <<-DESC
    Your description here.
  DESC
  s.homepage     = "https://github.com/johnfairh/TMLPersistentContainer"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "John Fairhurst" => "johnfairh@gmail.com" }
  s.social_media_url   = ""
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.12"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "10.0"
  s.source       = { :git => "https://github.com/johnfairh/TMLPersistentContainer.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
end
