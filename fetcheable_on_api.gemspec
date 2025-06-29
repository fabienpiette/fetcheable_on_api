lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fetcheable_on_api/version'

Gem::Specification.new do |spec|
  spec.name          = 'fetcheable_on_api'
  spec.version       = FetcheableOnApi::VERSION
  spec.authors       = ['Fabien']
  spec.email         = ['fab.piette@gmail.com']

  spec.summary       = 'A controller filters engine gem'\
                       ' based on jsonapi spec.'
  spec.description   = 'A controller filters engine gem'\
                       ' based on jsonapi spec.'
  spec.homepage      = 'https://github.com/FabienPiette/fetcheable_on_api.git'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org.
  # To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete
  # this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to
  # the gem when it is released.
  # The `git ls-files -z` loads the files in
  # the RubyGem that have been added into git.
  #
  # spec.files = Dir.chdir(File.expand_path(__dir__)) do
  #   `git ls-files -z`.split("\x0")
  #                    .reject { |f| f.match(%r{^(test|spec|features)/}) }
  # end
  #
  spec.files         = Dir['{lib/**/*,[A-Z]*}']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 4.1'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.59.2'
end
