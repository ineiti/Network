Gem::Specification.new do |s|
  s.name        = 'network'
  s.version     = '0.3.3'
  s.date        = '2015-05-26'
  s.summary     = 'Network-internet access'
  s.description = 'Internet access through different modems and access'
  s.authors     = ['Linus Gasser']
  s.email       = 'ineiti@linusetviviane.ch'

  s.files         = `if [ -d '.git' ]; then git ls-files -z; fi`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_runtime_dependency 'hilink_modem', '0.3.2'
  s.add_runtime_dependency 'serial_modem', '0.3.2'
  s.add_runtime_dependency 'helper_classes', '0.3.2'
  s.add_runtime_dependency 'chunky_png', '1.3.4'
  s.add_runtime_dependency 'i18n', '0.6.0'
  s.add_runtime_dependency 'multi_json', '1.0.3'


  s.homepage    = 'https://github.com/ineiti/Network'
  s.license       = 'GPLv3'
end
