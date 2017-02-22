lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'capose'
  spec.version       = '0.1.0'
  spec.authors       = ["Jacek Jakubik"]
  spec.email         = ["jacek.jakubik@netguru.pl"]
  spec.description   = %q{Docker-Compose support for Capistrano 3.x}
  spec.summary       = %q{Docker-Compose support for Capistrano 3.x}
  spec.homepage      = 'https://github.com/netguru/capose'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'capistrano', '~> 3.7'
  spec.add_development_dependency 'bundler', '~> 1.4'
end
