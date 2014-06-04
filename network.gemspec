Gem::Specification.new do |s|
  s.name        = 'network'
  s.version     = '0.1.0'
  s.date        = '2014-06-03'
  s.summary     = "Network-internet access"
  s.description = "Internet access through different modems and access"
  s.authors     = ["Linus Gasser"]
  s.email       = 'ineiti@linusetviviane.ch'
  s.files       = ["lib/network.rb",
 	"lib/network/",
 	"lib/network/modem.rb",
 	"lib/network/modems/huawei_hilink.rb"
]
  s.add_runtime_dependency 'hilink', '~> 0.1'
  s.add_runtime_dependency 'helperclasses', '~> 0.1'
  s.homepage    =
    'https://github.com/ineiti/Network'
  s.license       = 'GPLv3'
end
