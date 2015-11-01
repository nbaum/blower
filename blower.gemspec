lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "blower/version"

Gem::Specification.new do |s|
  s.name        = "blower"
  s.version     = Blower::VERSION
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = "Really simple server orchestration"
  s.description = "Really simple server orchestration"
  s.authors     = ["Nathan Baum"]
  s.email       = "n@p12a.org.uk"
  s.executables = ["blow"]
  s.files       = Dir["lib/**/*.rb"]
  s.homepage    = "http://www.github.org/nbaum/blower"
  s.license     = "MIT"
  s.add_runtime_dependency "net-ssh", ["~> 3.0"]
  s.add_runtime_dependency "colorize", ["~> 0.7"]
end
