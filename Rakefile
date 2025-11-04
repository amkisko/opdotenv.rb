require "rake"

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # RSpec not installed yet
end

begin
  require "standard/rake"
rescue LoadError
  # Standard not installed yet
end

begin
  require "appraisal"
  Appraisal::Task.new
rescue LoadError
  # Appraisal not installed yet
end

desc "Validate RBS type signatures"
task :rbs do
  sh "bundle exec rbs validate"
end

desc "Build the gem"
task :build do
  sh "gem build opdotenv.gemspec"
end

desc "Install the gem"
task install: :build do
  gem_file = Dir["opdotenv-*.gem"].max
  sh "gem install ./#{gem_file}"
end

task default: :spec
