root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/WORTHWHILE_VERSION").strip
tag     = "v#{version}"

directory 'pkg'

['worthwhile-models', 'worthwhile'].each do |framework|
  namespace framework do
    gem     = "pkg/#{framework}-#{version}.gem"
    gemspec = "#{framework}.gemspec"

    task :clean do
      rm_f gem
    end

    task :update_version_rb do
      glob = root.dup
      if framework == "worthwhile"
        glob << "/lib/*"
      else
        glob << "/#{framework}/lib/**"
      end
      glob << "/version.rb"

      file = Dir[glob].first
      if file
        ruby = File.read(file)

        major, minor, tiny, pre = version.split('.')
        pre = pre ? pre.inspect : "nil"

        ruby.gsub!(/^(\s*)VERSION = ".*?"$/, "\\1VERSION = \"#{version}\"")
        raise "Could not insert VERSION in #{file}" unless $1
        File.open(file, 'w') { |f| f.write ruby }
      end
    end
    task gem => %w(update_version_rb pkg) do
      cmd = ""
      cmd << "cd #{framework} && " unless framework == "worthwhile"
      cmd << "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/pkg/"
      sh cmd
    end

    task build: [:clean, gem]
    task install: :build do
      sh "gem install #{gem}"
    end

    task prep_release: [:ensure_clean_state, :build]

    task push: :build do
      sh "gem push #{gem}"
    end
  end
end


namespace :all do
  task build: ['worthwhile-models:build', 'worthwhile:build']
  task install: ['worthwhile-models:install', 'worthwhile:install']
  task push: ['worthwhile-models:push', 'worthwhile:push']

  task :ensure_clean_state do
    unless `git status -s | grep -v WORTHWHILE_VERSION | grep -v History.md`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV['SKIP_TAG'] || `git tag | grep "#{tag}$"`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task :commit do
    File.open('pkg/commit_message.txt', 'w') do |f|
      f.puts "# Preparing for #{version} release\n"
      f.puts
      f.puts "# UNCOMMENT THE LINE ABOVE TO APPROVE THIS COMMIT"
    end

    sh "git add . && git commit --verbose --template=pkg/commit_message.txt"
    rm_f "pkg/commit_message.txt"
  end

  task :tag do
    sh "git tag #{tag}"
    sh "git push --tags"
  end

  desc "Release both worthwhile and worthwhile-models and update the version to #{version} in all locations"
  task release: %w(ensure_clean_state build commit tag push)
end

