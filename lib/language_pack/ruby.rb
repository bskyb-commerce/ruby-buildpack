require "language_pack"
require "language_pack/base"

class LanguagePack::Ruby < LanguagePack::Base

  def self.use?
    File.exist?("Gemfile")
  end

  def name
    "Ruby"
  end

  def default_addons
    []
  end

  def default_config_vars
    {
      "LANG" => "en_US.UTF-8",
      "PATH" => default_path,
      "GEM_PATH" => slug_vendor_base
    }
  end

  def default_process_types
    { "rake" => "bundle exec rake",
      "console" => "bundle exec irb" }
  end

  def compile
    Dir.chdir(build_path)
    setup_language_pack_environment
    git_dir = ENV.delete("GIT_DIR") # can mess with bundler
    build_bundler
    run_compile_hook
    ENV["GIT_DIR"] = git_dir
  end

private

  def default_path
    "#{slug_vendor_base}/bin:/usr/local/bin:/usr/bin:/bin"
  end

  def language_pack_gems
    File.expand_path("../../../vendor/gems", __FILE__)
  end

  def slug_vendor_base
    "vendor/bundle/ruby/1.9.1"
  end

  def setup_language_pack_environment
    default_config_vars.each do |key, value|
      ENV[key] = value
    end
    ENV["GEM_HOME"] = slug_vendor_base
  end

  def install_language_pack_gems
    FileUtils.mkdir_p(File.dirname(slug_vendor_base))
    FileUtils.cp_r("#{language_pack_gems}/.", slug_vendor_base, :preserve => true)
  end

  def build_bundler
    bundle_vendor = "#{slug_vendor_base}/gems/bundler-1.1.pre.1"
    bundle_command = "bundle install --without development:test --path vendor/bundle"

    unless File.exist?("Gemfile.lock")
      error "Gemfile.lock is required. Please run \"bundle install\" locally\nand commit your Gemfile.lock."
    end

    if has_windows_gemfile_lock?
      File.rm("Gemfile.lock")
    else
      bundle_command += " --deployment"
    end

    cache_load ".bundle"
    cache_load "vendor/bundle"

    install_language_pack_gems

    version = run("bundle version").strip
    topic("Installing dependencies using #{version}")

    puts "Checking for unresolved dependencies."
    run "bundle check"

    if $?.success?
      puts "All dependencies are satisfied."
    else
      puts "Unresolved dependencies detected."
      puts "Running: #{bundle_command}"

      pipe("#{bundle_command} 2>&1")

      if $?.success?
        cache_store ".bundle"
        cache_store "vendor/bundle"
      else
        error "Failed to install gems via Bundler."
      end
    end
  end

  def run_compile_hook
    if rake_task_defined?("compile")
      topic "Running compile hook"
      pipe("bundle exec rake compile 2>&1")
      unless $?.success?
        error "Compile hook failed"
      end
    end
  end

  def has_windows_gemfile_lock?
    File.read("Gemfile.lock") =~ /^PLATFORMS\n  .*(mingw|mswin)/
  end

  def gem_is_bundled?(gem)
    run("bundle show").split("\n").detect { |line| line =~ / \* #{gem} / }
  end

  def rake_task_defined?(task)
    output = run("bundle exec rake -T compile")
    return false unless $?.success?
    output.split("\n")[1..-1].detect do |line|
      line.split(" ")[1] == task
    end
  end
end