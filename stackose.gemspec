lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'stackose'
  spec.version       = '0.3'
  spec.authors       = ["Marino Bonetti"]
  spec.email         = ["marinobonetti@gmail.com"]
  spec.description   = %q{Docker-Stack support for Capistrano 3.x}
  spec.summary       = %q{Docker-Stack support for Capistrano 3.x}
  spec.homepage      = 'https://github.com/oniram88/stackose'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'capistrano', '~> 3.7'
  spec.add_development_dependency 'bundler', '~> 1.4'
end
