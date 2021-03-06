require 'testing_env'

require 'extend/ARGV' # needs to be after test/unit to avoid conflict with OptionsParser
ARGV.extend(HomebrewArgvExtension)

require 'extend/ENV'
ENV.extend(HomebrewEnvExtension)

require 'test/testball'

require 'hardware'

class AbstractDownloadStrategy
  attr_reader :url
end

class MostlyAbstractFormula <Formula
  @url=''
  @homepage = 'http://example.com/'
end

class FormulaTests < Test::Unit::TestCase

  def test_prefix
    nostdout do
      TestBall.new.brew do |f|
        assert_equal File.expand_path(f.prefix), (HOMEBREW_CELLAR+f.name+'0.1').to_s
        assert_kind_of Pathname, f.prefix
      end
    end
  end
  
  def test_class_naming
    assert_equal 'ShellFm', Formula.class_s('shell.fm')
    assert_equal 'Fooxx', Formula.class_s('foo++')
    assert_equal 'SLang', Formula.class_s('s-lang')
    assert_equal 'PkgConfig', Formula.class_s('pkg-config')
    assert_equal 'FooBar', Formula.class_s('foo_bar')
  end

  def test_cant_override_brew
    assert_raises(RuntimeError) do
      eval <<-EOS
      class TestBallOverrideBrew <Formula
        def initialize
          super "foo"
        end
        def brew
        end
      end
      EOS
    end
  end
  
  def test_abstract_formula
    f=MostlyAbstractFormula.new
    assert_equal '__UNKNOWN__', f.name
    assert_raises(RuntimeError) { f.prefix }
    nostdout { assert_raises(RuntimeError) { f.brew } }
  end

  def test_mirror_support
    HOMEBREW_CACHE.mkpath unless HOMEBREW_CACHE.exist?
    nostdout do
      f = TestBallWithMirror.new
      tarball, downloader = f.fetch
      assert_equal f.url, "file:///#{TEST_FOLDER}/bad_url/testball-0.1.tbz"
      assert_equal downloader.url, "file:///#{TEST_FOLDER}/tarballs/testball-0.1.tbz"
    end
  end

  def test_compiler_selection
    %W{HOMEBREW_USE_CLANG HOMEBEW_USE_LLVM HOMEBREW_USE_GCC}.each { |e| ENV.delete(e) }

    f = TestAllCompilerFailures.new
    assert f.fails_with? :clang
    assert f.fails_with? :llvm
    assert f.fails_with? :gcc
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert_equal MacOS.default_compiler, ENV.compiler
    ENV.send MacOS.default_compiler

    f = TestNoCompilerFailures.new
    assert !(f.fails_with? :clang)
    assert !(f.fails_with? :llvm)
    assert !(f.fails_with? :gcc)
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert_equal MacOS.default_compiler, ENV.compiler
    ENV.send MacOS.default_compiler

    f = TestLLVMFailure.new
    assert !(f.fails_with? :clang)
    assert f.fails_with? :llvm
    assert !(f.fails_with? :gcc)
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert ENV.compiler, case MacOS.clang_build_version
    when 0..210 then :gcc
    else :clang
    end
    ENV.send MacOS.default_compiler

    f = TestMixedCompilerFailures.new
    assert f.fails_with? :clang
    assert !(f.fails_with? :llvm)
    assert f.fails_with? :gcc
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert_equal :llvm, ENV.compiler
    ENV.send MacOS.default_compiler

    f = TestMoreMixedCompilerFailures.new
    assert !(f.fails_with? :clang)
    assert f.fails_with? :llvm
    assert f.fails_with? :gcc
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert_equal :clang, ENV.compiler
    ENV.send MacOS.default_compiler

    f = TestEvenMoreMixedCompilerFailures.new
    assert f.fails_with? :clang
    assert f.fails_with? :llvm
    assert !(f.fails_with? :gcc)
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert_equal :clang, ENV.compiler
    ENV.send MacOS.default_compiler

    f = TestBlockWithoutBuildCompilerFailure.new
    assert f.fails_with? :clang
    assert !(f.fails_with? :llvm)
    assert !(f.fails_with? :gcc)
    cs = CompilerSelector.new(f)
    cs.select_compiler
    assert_equal MacOS.default_compiler, ENV.compiler
    ENV.send MacOS.default_compiler
  end
end
