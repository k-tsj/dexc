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

  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  s.bindir        = "exe"
  s.executables   = s.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_runtime_dependency 'irb'
  s.add_runtime_dependency 'binding_of_caller'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'test-unit'
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options     = ['--main', 'README.rdoc']
  s.licenses         = ['BSD-2-Clause', 'Ruby']
end
