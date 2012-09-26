@prefs = {}
def prefs
  if block_given?
    yield prefs
  else
    @prefs
  end
end

@current_recipe = nil
def current_recipe(recipe=nil)
  @current_recipe = recipe unless recipe.nil?
  return @current_recipe
end

@after_blocks = []
def after_bundler(&block)
  @after_blocks << block
end

@after_everything_blocks = []
def after_everything(&block)
  @after_everything_blocks << block
end

@before_configs = {}
def before_config(&block)
  @before_configs[@current_recipe] = block
end

def say_custom(tag, text)
  say "\033[1m\033[36m" + tag.to_s.rjust(10) + "\033[0m" + "  #{text}"
end

def say_recipe(name)
  say "\033[1m\033[36m" + "recipe".rjust(10) + "\033[0m" + "  Running #{name} recipe..."
end

def say_wizard(text)
  say_custom(current_recipe || 'composer', text)
end


def copy_from(source, destination)
  begin
    remove_file destination
    get source, destination
  rescue OpenURI::HTTPError
    say_wizard "Unable to obtain #{source}"
  end
end

def copy_from_repo(filename, opts = {})
  repo = 'https://raw.github.com/danryan/template/master/files/'
  source_filename = filename
  destination_filename = filename
  unless opts[:prefs].nil?
    if filename.include? opts[:prefs]
      destination_filename = filename.gsub(/\-#{opts[:prefs]}/, '')
    end
  end
  begin
    remove_file destination_filename
    get repo + source_filename, destination_filename
  rescue OpenURI::HTTPError
    say_wizard "Unable to obtain #{source_filename} from the repo #{repo}"
  end
end

def template_from_repo(filename)
  repo = 'https://raw.github.com/danryan/template/master/templates/'

  remote = "#{repo}#{filename}.erb"
  source = "tmp/#{filename}.erb"
  destination = filename

  begin
    remove_file destination
    get remote, source
    template source, destination
    remove_file source
  rescue OpenURI::HTTPError
    say_wizard "Unable to obtain #{source_filename} from the repo #{repo}"
  end
end

# ---------- GIT ---------- #
current_recipe "git"
say_recipe "git"

say 'initialize git'

copy_from 'https://raw.github.com/danryan/template/master/files/gitignore.txt', '.gitignore'
git :init
git :add => '.'
git :commit => '-aqm "initial commit"'

# ---------- GEMS ---------- #
current_recipe "gems"
say_recipe "gems"

create_file "Gemfile", :force => true do <<-EOF
EOF
end

add_source 'https://rubygems.org'

gem 'rails', '3.2.8'

gem 'pg'
gem 'unicorn'
gem 'haml-rails'
gem 'cabin'
gem 'simple_form'
gem 'responders'
gem 'draper'
gem 'devise'
gem 'cancan'
gem 'rolify'

gem 'sass-rails'
gem 'bootstrap-sass'
gem 'jquery-rails'
gem 'select2-rails'
gem 'underscore-rails'
gem 'jquery-validation-rails'

append_file 'Gemfile', "\n"

gem_group :development do
  gem 'pry-rails'
end

gem_group :assets do
  gem 'coffee-rails'
  gem 'uglifier'
end

gem_group :test do
  gem 'foreman'
  gem 'rspec-rails'
  gem 'rspec-instafail'
  gem 'factory_girl_rails'
  gem 'shoulda-matchers'
  gem 'capybara'
  gem 'rack-test', :require => 'rack/test'
  gem 'spork'
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-rails'
  gem 'guard-spork'
  gem 'guard-bundler'
  gem 'rb-fsevent'
  gem 'growl'
  gem 'database_cleaner', '>= 0.7.2'
  gem 'tach'
  gem 'forgery'
  gem 'timecop'
end

git :add => '.'
git :commit => '-aqm "create Gemfile"'

# ---------- DATABASE ---------- #
current_recipe "database"
say_recipe "database"

after_bundler do
  copy_from_repo 'config/database-postgresql.yml', :prefs => 'postgresql'
  begin
    say "creating user named '#{app_name}' for PostgreSQL"
    run "createuser #{app_name}"
    gsub_file "config/database.yml", /username: .*/, "username: #{app_name}"
    gsub_file "config/database.yml", /database: myapp_development/, "database: #{app_name}_development"
    gsub_file "config/database.yml", /database: myapp_test/,        "database: #{app_name}_test"
    gsub_file "config/database.yml", /database: myapp_production/,  "database: #{app_name}_production"
  rescue StandardError => e
    raise "unable to create a user for PostgreSQL, reason: #{e}"
  end

  run "bundle exec rake db:create:all"
  git :add => '.'
  git :commit => "-aqm 'create database'"
end

# ---------- GENERATORS ---------- #
current_recipe "generators"
say_recipe "generators"

after_bundler do
  generate 'simple_form:install --bootstrap'
  git :add => '.'
  git :commit => "-aqm 'run generators'"
end

# ---------- FILES ---------- #

current_recipe "files"
say_recipe "files"

after_everything do
  say_wizard "recipe running after everything"

  %w[ README README.rdoc doc/README_FOR_APP ].each {|file| remove_file file }

  copy_from_repo 'LICENSE.txt'
  gsub_file 'LICENSE.txt', /YEAR_NOW/, Time.now.year.to_s

  copy_from_repo 'README.md'
  gsub_file 'README.md', /MY_APP/, app_name.titleize

  git :add => '.'
  git :commit => "-aqm 'README and LICENSE'"
end

# ---------- TESTING ---------- #

current_recipe "testing"
say_recipe "testing"

after_bundler do
  say_wizard "recipe running after 'bundle install'"

  generate 'rspec:install'
  copy_from_repo 'spec/spec_helper.rb'
  remove_dir 'test'
  inject_into_file 'config/application.rb', :after => "Rails::Application\n" do
    <<-RUBY
    # don't generate RSpec tests for views and helpers
    config.generators do |g|
      g.test_framework :rspec
      g.template_engine :haml
      g.view_specs false
      g.helper_specs false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
    end
    RUBY
  end
  create_file 'spec/support/devise.rb' do
    <<-RUBY
    RSpec.configure do |config|
      config.include Devise::TestHelpers, :type => :controller
    end
    RUBY
  end
  git :add => '.'
  git :commit => "-aqm 'testing frameworks'"
end # after_bundler

after_everything do
  say_wizard 'recipe running after everything'

  copy_from_repo 'spec/factories/users.rb'
  copy_from_repo 'spec/controllers/home_controller_spec.rb'
  copy_from_repo 'spec/controllers/users_controller_spec.rb'
  remove_file 'spec/views/home/index.html.erb_spec.rb'
  remove_file 'spec/views/home/index.html.haml_spec.rb'
  remove_file 'spec/views/users/show.html.erb_spec.rb'
  remove_file 'spec/views/users/show.html.haml_spec.rb'
  remove_file 'spec/helpers/home_helper_spec.rb'
  remove_file 'spec/helpers/users_helper_spec.rb'

  git :add => '.'
  git :commit => "-aqm 'rspec files'"
end # after_everything

# ---------- MODELS ---------- #

current_recipe 'models'
say_recipe 'models'

after_bundler do
  gsub_file 'config/application.rb', /:password/, ':password, :password_confirmation'
  generate 'devise:install'
  generate 'devise user'

  generate 'migration AddNameToUsers name:string'
  copy_from_repo 'app/models/user.rb'
  generate 'migration AddConfirmableToUsers confirmation_token:string confirmed_at:datetime confirmation_sent_at:datetime unconfirmed_email:string'

  generate 'cancan:ability'
  copy_from_repo 'app/models/ability.rb'

  generate 'rolify:role Role User'

  git :add => '.'
  git :commit => "-aqm 'add models'"
end # after_bundler

# ---------- FRONTEND ---------- #

current_recipe 'frontend'
say_recipe 'frontend'

after_bundler do
  say_wizard 'after bundle install'

  copy_from_repo 'app/views/layouts/application.html.haml'
  gsub_file 'app/views/layouts/application.html.haml', /MY_APP/, app_name.titleize
  remove_file 'app/views/layouts/application.html.erb'

  copy_from_repo 'app/views/shared/_header.html.haml'
  gsub_file 'app/views/shared/_header.html.haml', /MY_APP/, app_name.titleize

  copy_from_repo 'app/assets/stylesheets/application.css.scss'
  remove_file 'app/assets/stylesheets/application.css'

  copy_from_repo 'app/assets/javascripts/application.js.coffee'
  copy_from_repo 'app/assets/javascripts/bootstrap_ujs.js.coffee'
  copy_from_repo 'app/assets/javascripts/validations.js.coffee'
  remove_file 'app/assets/javascripts/application.js'

  git :add => '.'
  git :commit => "-aqm 'add frontend'"

end # after_bundler

# ---------- INIT ---------- #

current_recipe 'init'
say_recipe 'init'

after_everything do
  append_file 'db/seeds.rb' do 
    %q"
    puts 'ADDING DEFAULT USER'
    user = User.create! :name => 'John Doe', :email => 'jdoe@example.com', :password => 'qwerty', :password_confirmation => 'qwerty'
    user.confirm!
    puts 'Created user: #{user.name}'
    "
  end

  run 'bundle exec rake db:migrate'
  run 'bundle exec rake db:test:prepare'
  run 'bundle exec rake db:seed'

  git :add => '.'
  git :commit => "-aqm 'set up database'"
end # after_everything

# ---------- CONTROLLERS ---------- #

current_recipe 'controllers'
say_recipe 'controllers'

after_bundler do
  inject_into_file 'app/controllers/application_controller.rb', :before => "\nend" do 
    %q"
      \n
      rescue_from CanCan::AccessDenied do |exception|
        redirect_to root_path, :error => exception.message
      end
    "
  end

  copy_from_repo 'app/controllers/users_controller.rb'

  git :add => '.'
  git :commit => "-aqm 'add controllers'"
end # after_bundler

# ---------- VIEWS ---------- #

current_recipe 'controllers'
say_recipe 'controllers'

after_bundler do
  copy_from_repo 'app/views/devise/shared/_links.html.haml'
  copy_from_repo 'app/views/devise/registrations/edit.html.haml'
  copy_from_repo 'app/views/devise/registrations/new.html.haml'

  copy_from_repo 'app/views/home/index.html.haml'

  copy_from_repo 'app/views/users/index.html.haml'
  copy_from_repo 'app/views/users/show.html.haml'

  git :add => '.'
  git :commit => "-aqm 'add views'"
end # after_bundler

# ---------- PRELAUNCH ---------- #

current_recipe 'controllers'
say_recipe 'controllers'

after_everything do
  %w[ public/index.html app/assets/images/rails.png ].each {|file| remove_file file }

  gsub_file 'Gemfile', /#.*\n/, "\n"
  gsub_file 'Gemfile', /\n^\s*\n/, "\n"
  gsub_file 'config/routes.rb', /  #.*\n/, "\n"
  gsub_file 'config/routes.rb', /\n^\s*\n/, "\n"

  git :add => '.'
  git :commit => "-aqm 'clean up app'"

  generate 'migration AddOptinToUsers opt_in:boolean'
  run 'bundle exec rake db:drop'
  run 'bundle exec rake db:migrate'
  run 'bundle exec rake db:test:prepare'
  run 'bundle exec rake db:seed'

  copy_from_repo 'app/controllers/confirmations_controller.rb'
  copy_from_repo 'app/controllers/home_controller.rb'
  copy_from_repo 'app/controllers/registrations_controller.rb'
  copy_from_repo 'app/controllers/users_controller.rb'

  copy_from_repo 'app/views/devise/confirmations/show.html.haml'
  copy_from_repo 'app/views/devise/mailer/confirmation_instructions.html.erb'
  copy_from_repo 'app/views/devise/registrations/_thankyou.html.haml'
  copy_from_repo 'app/views/devise/registrations/new.html.haml'
  copy_from_repo 'app/views/devise/shared/_links.html.haml'
  copy_from_repo 'app/views/home/index.html.haml'
  copy_from_repo 'app/views/user_mailer/welcome_email.html.erb'
  copy_from_repo 'app/views/user_mailer/welcome_email.text.erb'
  copy_from_repo 'app/views/users/index.html.haml'
  copy_from_repo 'public/thankyou.html'

  copy_from_repo 'config/routes.rb'
  ### CORRECT APPLICATION NAME ###
  gsub_file 'config/routes.rb', /^.*.routes.draw do/, "#{app_const}.routes.draw do"

  git :add => '.'
  git :commit => "-aqm 'configure prelaunch'"
end

# ---------- RVM ---------- #

current_recipe 'rvm'
say_recipe 'rvm'

say_wizard "recipe creating project-specific rvm gemset and .rvmrc"

if ENV['MY_RUBY_HOME'] && ENV['MY_RUBY_HOME'].include?('rvm')
  begin
    gems_path = ENV['MY_RUBY_HOME'].split(/@/)[0].sub(/rubies/,'gems')
    ENV['GEM_PATH'] = "#{gems_path}:#{gems_path}@global"
    require 'rvm'
    RVM.use_from_path! File.dirname(File.dirname(__FILE__))
  rescue LoadError
    raise "RVM gem is currently unavailable."
  end
end
say_wizard "creating RVM gemset '#{app_name}'"
RVM.gemset_create app_name
run "rvm rvmrc trust"
say_wizard "switching to gemset '#{app_name}'"
begin
  RVM.gemset_use! app_name
rescue StandardError => e
  raise "rvm failure: unable to use gemset #{app_name}, reason: #{e}"
end
run "rvm gemset list"
copy_from_repo '.rvmrc'
gsub_file '.rvmrc', /MY_APP/, "#{app_name}"

# ---------- GITHUB ---------- #

current_recipe 'github'
say_recipe 'github'

gem 'hub', '>= 1.10.2', :require => nil, :group => [ :development ]
after_everything do
  git_uri = `git config remote.origin.url`.strip
  unless git_uri.size == 0
    say "repo exists: #{git_uri}"
  else
    if config[:private]
      run "hub create -p #{app_name}"
    else
      run "hub create #{app_name}"
    end
    run "hub push -u origin master"
  end
end

# ---------- BUNDLER ---------- #
current_recipe nil

say "installing gems"
run "bundle install"

# ---------- AFTER BUNDLER ---------- #
current_recipe nil

say "running after_bundler callbacks"
# require 'bundler/setup'

@after_blocks.each do |callback|
  callback.call
end

# ---------- AFTER EVERYTHING ---------- #
current_recipe nil

say "running after everything callbacks"

@after_everything_blocks.each do |callback|
  callback.call
end
