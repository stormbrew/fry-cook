$:.unshift(File.dirname(__FILE__) + '/lib')
require 'fry_cook/version'

Gem::Specification.new do |s|
  s.name = "fry-cook"
  s.version = FryCook::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = "Not quite a chef yet, the fry cook knows only one menu."
  s.description = s.summary

  s.author = "Megan Batty"
  s.email = "megan@stormbrew.ca"
  s.homepage = "https://www.github.com/stormbrew/fry-cook"

  s.add_dependency "chef", "~> 11"
  s.add_dependency "chef-zero", "~> 1.7"
  s.add_dependency "berkshelf", "~> 2"

  %w(rspec-core rspec-expectations rspec-mocks).each { |gem| s.add_development_dependency gem, "~> 2.13.0" }

  s.bindir = "bin"
  s.executables = %w{ fry-cook }

  s.require_path = "lib"
  s.files = Dir.glob("{bin,spec,lib}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) } + %w{
    LICENSE
    README.md
  } 
end
