Kernel.load 'lib/LOLastfm/version.rb'

Gem::Specification.new {|s|
	s.name         = 'LOLastfm'
	s.version      = LOLastfm.version
	s.author       = 'meh.'
	s.email        = 'meh@paranoici.org'
	s.homepage     = 'http://github.com/meh/LOLastfm'
	s.platform     = Gem::Platform::RUBY
	s.summary      = 'LOL a scrobbler.'

	s.files         = `git ls-files`.split("\n")
	s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
	s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
	s.require_paths = ['lib']

	s.add_dependency 'lastfm'
	s.add_dependency 'taglib-ruby'
}
