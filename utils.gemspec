#$:.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "utils"
  s.version     = "1.2.8"
  s.authors     = ["wangfuhai"]
  s.email       = ["wangfuhai@gmail.com"]
  s.homepage    = "https://github.com/wangfuhai2013/utils-rails"
  s.summary     = "utils with rails"
  s.description = "utils with rails"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE","Rakefile", "README.rdoc"]
# s.test_files = Dir["test/**/*"]

#  s.add_dependency "rails", "~> 4.0.0"

   s.add_dependency "mini_magick"
   s.add_dependency "faraday"
   s.add_dependency "xml-simple"

#  s.add_development_dependency "sqlite3"
end
