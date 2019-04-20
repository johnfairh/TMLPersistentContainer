Pod::Spec.new do |s|
  s.name         = "TMLPersistentContainer"
  s.version      = "4.0.0"
  s.authors      = { "John Fairhurst" => "johnfairh@gmail.com" }
#  s.social_media_url   = "https://twitter.com/johnfairh"
  s.license      = { :type => "ISC", :file => "LICENSE" }
  s.homepage     = "https://github.com/johnfairh/TMLPersistentContainer"
  s.source       = { :git => "https://github.com/johnfairh/TMLPersistentContainer.git", :tag => s.version.to_s }
  s.summary      = "Automatic shortest-path multi-step Core Data migrations in Swift."
  s.description = <<-EDESC
                    A Swift extension to Core Data's NSPersistentContainer
                    that automatically detects and performs multi-step store
                    migration using the shortested valid sequence.  Supports
                    light-weight and heavy-weight migrations, multiple stores,
                    progress reporting and configurable logging.
                  EDESC
  s.documentation_url = "https://johnfairh.github.io/TMLPersistentContainer/"
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.12"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "10.0"
  s.source_files  = "Sources/*swift"
  s.frameworks  = "Foundation", "CoreData"
  s.swift_version = '5.0'
end
