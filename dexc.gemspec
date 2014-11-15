$:.push File.expand_path('../lib', __FILE__)
require 'dexc/version'

Gem::Specification.new do |s|
  s.name        = 'dexc'
  s.version     = Dexc::VERSION
  s.authors     = ['Kazuki Tsujimoto']
  s.email       = ['kazuki@callcc.net']
  s.homepage    = 'https://github.com/k-tsj/dexc'
  s.summary     = %q{A library that helps you to debug an exception}
  s.description = %q{Automatically start the REPL and show trace on an exception to debug.}

  s.files            = `git ls-files`.split("\n")
  s.test_files       = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f) }
  s.require_paths    = ['lib']
  s.add_development_dependency 'rake'
  s.add_development_dependency 'test-unit'
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options     = ['--main', 'README.rdoc']
end
