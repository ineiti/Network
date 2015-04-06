Gem::Specification.new do |s|
  s.name        = 'Network'
  s.version     = '0.2.0'
  s.date        = '2015-04-06'
  s.summary     = "Network-internet access"
  s.description = "Internet access through different modems and access"
  s.authors     = ["Linus Gasser"]
  s.email       = 'ineiti@linusetviviane.ch'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_runtime_dependency 'hilinkmodem', '~> 0.2'
  s.add_runtime_dependency 'serialmodem', '~> 0.2'
  s.add_runtime_dependency 'helperclasses', '~> 0.2'
  s.homepage    = 'https://github.com/ineiti/Network'
  s.license       = 'GPLv3'
end
