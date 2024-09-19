Pod::Spec.new do |s|
  s.name         = "TMLPersistentContainer"
  s.version      = "6.0.0"
  s.authors      = { "John Fairhurst" => "johnfairh@gmail.com" }
  s.license      = { :type => "ISC", :file => "LICENSE" }
  s.homepage     = "https://github.com/johnfairh/TMLPersistentContainer"
  s.source       = { :git => "https://github.com/johnfairh/TMLPersistentContainer.git", :tag => s.version.to_s }
  s.summary      = "Automatic shortest-path multi-step Core Data migrations in Swift."
  s.description = <<-EDESC
                    A set of Swift extensions to Core Data's
                    NSPersistentContainer and NSPersistentCloudKitContainer
                    that automatically detect and perform multi-step store
                    migration using the shortested valid sequence.  Supports
                    light-weight and heavy-weight migrations, multiple stores,
                    progress reporting and configurable logging.
                  EDESC
  s.documentation_url = "https://johnfairh.github.io/TMLPersistentContainer/"
  s.ios.deployment_target = "12.0"
  s.osx.deployment_target = "14.0.0"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "12.0"
  s.source_files  = "Sources/*swift"
  s.frameworks  = "Foundation", "CoreData"
  s.swift_version = '6.0'
end
