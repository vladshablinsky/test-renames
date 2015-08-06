require "minitest/autorun"
require "pathname"

HOMEBREW_CELLAR = Pathname.new("/usr/local/Cellar")
HOMEBREW_LIBRARY = Pathname.new("/usr/local/Library")
REPO = Pathname.new("/usr/local")
TAP_REPO = HOMEBREW_LIBRARY.join("Taps/vladshablinsky/homebrew-taptest")

class TestFormulaRenames < Minitest::Test
  def `(cmd)
    out = super
    unless $?.success?
      $stderr.puts(out) unless out.empty?
      raise "Error executing #{cmd}"
    end
    out
  end

  def shutup
    err = $stderr.dup
    out = $stdout.dup

    begin
      $stderr.reopen("/dev/null")
      $stdout.reopen("/dev/null")
      yield
    ensure
      $stderr.reopen(err)
      $stdout.reopen(out)
      err.close
      out.close
    end
  end

  def initialize_revisions
    @repo_dir ||= REPO
    @tap_dir ||= TAP_REPO
    @formula_dir ||= HOMEBREW_LIBRARY/"Formula"
    Dir.chdir(@repo_dir.to_s) do
      @initial_repo_branch ||= `git symbolic-ref --short HEAD`.chomp
    end
    Dir.chdir(@tap_dir.to_s) do
      @initial_tap_branch ||= `git symbolic-ref --short HEAD`.chomp
    end
    @new_branch ||= "test_renames_branch"
  end

  def install_core
    `brew install libpng`
  end

  def install_tap
    `brew install vladshablinsky/taptest/libpng`
  end

  def rename_core
    `cp newlibpng.rb #{@formula_dir.join("newlibpng.rb")}`
    `cp formula_renames.rb #{HOMEBREW_LIBRARY.join("Homebrew/formula_renames.rb")}`
    `rm #{@formula_dir.join("libpng.rb")}`
    Dir.chdir(@repo_dir.to_s) do
      `git add -A`
      `git status`
      `git commit -m "libpng->newlibpng"`
    end
  end

  def rename_tap
    `cp newlibpng.rb #{@tap_dir.join("newlibpng.rb")}`
    `cp formula_renames.json #{@tap_dir.join("formula_renames.json")}`
    `rm #{@tap_dir.join("libpng.rb")}`
    Dir.chdir(@tap_dir.to_s) do
      `git add -A`
      `git status`
      `git commit -m "libpng->newlibpng"`
    end
  end

  def update
    `brew update`
  end

  def migrate
    `brew migrate libpng`
  end

  def migrate_fully
    `brew migrate vladshablinsky/taptest/libpng`
  end

  def migrate_core_fully
    `brew migrate homebrew/homebrew/libpng`
  end

  def uninstall
    `brew uninstall libpng`
  end

  def check_migration
    assert_predicate HOMEBREW_CELLAR.join("newlibpng"), :directory?
    assert_equal HOMEBREW_CELLAR.join("newlibpng").realpath, HOMEBREW_CELLAR.join("libpng").realpath
  end

  def migration_occured?
    HOMEBREW_CELLAR.join("libpng").symlink?
  end

  def check_uninstalled
    refute File.exist?(HOMEBREW_CELLAR.join("libpng").to_s)
    refute File.exist?(HOMEBREW_CELLAR.join("newlibpng").to_s)
  end

  def run_zint
    `zint -o 1.png -d"hi"`
  end

  # The following designations are used:
  # TI - tap installed
  # TR - tap renamed
  # CI - core installed
  # CR - core renamed

  def setup
    # checkout to new branch
    initialize_revisions
    [@repo_dir, @tap_dir].each do |dir|
      Dir.chdir(dir.to_s) do
        shutup { `git checkout -b #{@new_branch}` }
      end
    end
  end

  def teardown
    Dir.chdir(@repo_dir.to_s) do
      shutup { `git checkout #{@initial_repo_branch}` }
      shutup { `git branch -D #{@new_branch}` }
    end

    Dir.chdir(@tap_dir.to_s) do
      shutup { `git checkout #{@initial_tap_branch}` }
      shutup { `git branch -D #{@new_branch}` }
    end
    begin
      shutup { uninstall }
    rescue RuntimeError
    end
  end

  def test_migrate_CI_CR
    install_core
    assert_predicate HOMEBREW_CELLAR.join("libpng"), :directory?
    rename_core
    assert_raises(RuntimeError) { shutup { migrate } }
    migrate_core_fully
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled
  end

  def test_migrate_CI_TR
    install_core
    rename_tap
    assert_raises(RuntimeError) { shutup { migrate } }
    refute migration_occured?, "Mustn't occur"
  end

  def test_migrate_TI_CR
    install_tap
    rename_core
  end

  def test_migrate_TI_TR
    install_tap
    rename_tap
    migrate
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled
  end

  def test_migrate_CI_CR_TR
    install_core
    rename_core
    rename_tap
    migrate
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled
  end

  def test_migrate_TI_CR_TR
    install_tap
    rename_core
    rename_tap
    migrate
    check_migration
    assert migration_occured?, "Migration must have occured"
    run_zint
    uninstall
    check_uninstalled
  end

  def test_update_CI_CR
    install_core
    assert_predicate HOMEBREW_CELLAR.join("libpng"), :directory?
    rename_core
    update
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled
  end

  def test_update_CI_TR
    install_core
    rename_tap
    update
    refute migration_occured?, "Mustn't occur"
  end

  def test_update_TI_CR
    install_tap
    rename_core
    update
    refute migration_occured?, "Mustn't occur"
  end

  def test_update_TI_TR
    install_tap
    rename_tap
    update
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled
  end

  def test_update_CI_CR_TR
    install_tap
    rename_core
    rename_tap
    update
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled

  end

  def test_update_TI_CR_TR
    install_tap
    rename_core
    rename_tap
    update
    assert migration_occured?, "Migration must have occured"
    check_migration
    run_zint
    uninstall
    check_uninstalled
  end
end
