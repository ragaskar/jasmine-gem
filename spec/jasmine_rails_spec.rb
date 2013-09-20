require 'spec_helper'
require 'net/http'
require 'timeout'

if Jasmine::Dependencies.rails_available?
  describe 'A Rails app' do

    before :all do
      temp_dir_before
      Dir::chdir @tmp

      create_rails 'rails-example'
      Dir::chdir File.join(@tmp, 'rails-example')

      base = File.absolute_path(File.join(__FILE__, '../..'))

      open('Gemfile', 'a') { |f|
        f.puts "gem 'jasmine', :path => '#{base}'"
        f.puts "gem 'jasmine-core', :github => 'pivotal/jasmine'"
        f.flush
      }

      Bundler.with_clean_env do
        puts `NOKOGIRI_USE_SYSTEM_LIBRARIES=true bundle install --path vendor;`
        `bundle exec rails g jasmine:install`
        File.exists?('spec/javascripts/helpers/.gitkeep').should == true
        File.exists?('spec/javascripts/support/jasmine.yml').should == true
        `bundle exec rails g jasmine:examples`
        File.exists?('app/assets/javascripts/jasmine_examples/Player.js').should == true
        File.exists?('app/assets/javascripts/jasmine_examples/Song.js').should == true
        File.exists?('spec/javascripts/jasmine_examples/PlayerSpec.js').should == true
        File.exists?('spec/javascripts/helpers/SpecHelper.js').should == true
      end
    end

    after :all do
      temp_dir_after
    end

    it 'should have the jasmine & jasmine:ci rake task' do
      #See https://github.com/jimweirich/rake/issues/220 and https://github.com/jruby/activerecord-jdbc-adapter/pull/467
      #There's a workaround, but requires setting env vars & jruby opts (non-trivial when inside of a jruby process), so skip for now.
      pending "activerecord-jdbc + rake -T doesn't work correctly under Jruby" if ENV['RAILS_VERSION'] == 'rails3' && RUBY_PLATFORM == 'java'
      Bundler.with_clean_env do
        output = `bundle exec rake -T`
        output.should include('jasmine ')
        output.should include('jasmine:ci')
      end
    end

    it "rake jasmine:ci runs and returns expected results" do
      Bundler.with_clean_env do
        output = `bundle exec rake jasmine:ci`
        output.should include('5 specs, 0 failures')
      end
    end

    it "rake jasmine runs and serves the expected webpage when using asset pipeline" do
      open('app/assets/stylesheets/foo.css', 'w') { |f|
        f.puts "/* hi dere */"
        f.flush
      }

      jasmine_yml_path = 'spec/javascripts/support/jasmine.yml'
      jasmine_config = YAML.load_file(jasmine_yml_path)
      jasmine_config['src_files'] = ['assets/application.js']
      jasmine_config['stylesheets'] = ['assets/application.css']
      open(jasmine_yml_path, 'w') { |f|
        f.puts YAML.dump(jasmine_config)
        f.flush
      }

      Bundler.with_clean_env do
        begin
          pid = IO.popen("bundle exec rake jasmine").pid
          Jasmine::wait_for_listener(8888, 'jasmine server')
          p "server is up"
          output = Net::HTTP.get(URI.parse('http://localhost:8888/'))
          p "got it"
          output.should match(%r{script src.*/assets/jasmine_examples/Player.js})
          output.should match(%r{script src.*/assets/jasmine_examples/Song.js})
          output.should match(%r{<link rel=.stylesheet.*?href=./assets/foo.css\?.*?>})
        ensure
          p pid
          # Process.kill(:SIGKILL, pid)
          p 'beffoooooree ---'
          puts `ps -ef | grep #{pid}`
          p 'just pid ----'
          puts `ps -ef | grep jasmine`
          p `kill -9 #{pid}`
          p 'after ---'
          puts `ps -ef | grep jasmine`
          p 'just pid ----'
          puts `ps -ef | grep #{pid}`
          p "killed"
          sleep(5)
          p "Jasmine is listennnning : #{Jasmine.server_is_listening_on('localhost', 8888)}"
          # begin
            # Timeout::timeout(1) do
              # Process.waitpid pid
            # end
          # rescue Errno::ECHILD, Timeout::Error
          # end
        end
      end
    end
  end
end
