Gem::Specification.new do |s|
  s.name        = 'rhizome'
  s.version     = '0.1'
  s.summary     = 'A JIT for Ruby'
  s.description = 'A JIT for Ruby, implemented in pure Ruby'
  s.author      = 'Chris Seaton'
  s.email       = 'chris@chrisseaton.com'
  s.files       = `git ls-files`.split($/)
  
  s.add_development_dependency('rspec', '~> 3')
end
