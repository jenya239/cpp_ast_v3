# frozen_string_literal: true

require_relative "../test_helper"

class StdlibResolutionTest < Minitest::Test
  def test_stdlib_resolver_recognizes_math
    resolver = Aurora::StdlibResolver.new
    assert resolver.stdlib_module?('Math')
  end

  def test_stdlib_resolver_recognizes_io
    resolver = Aurora::StdlibResolver.new
    assert resolver.stdlib_module?('IO')
  end

  def test_stdlib_resolver_does_not_recognize_unknown
    resolver = Aurora::StdlibResolver.new
    refute resolver.stdlib_module?('Unknown')
    refute resolver.stdlib_module?('CustomModule')
  end

  def test_stdlib_resolver_resolves_math
    resolver = Aurora::StdlibResolver.new
    path = resolver.resolve('Math')
    refute_nil path
    assert File.exist?(path)
    assert path.end_with?('math.aur')
  end

  def test_stdlib_resolver_resolves_io
    resolver = Aurora::StdlibResolver.new
    path = resolver.resolve('IO')
    refute_nil path
    assert File.exist?(path)
    assert path.end_with?('io.aur')
  end

  def test_stdlib_resolver_returns_nil_for_unknown
    resolver = Aurora::StdlibResolver.new
    assert_nil resolver.resolve('Unknown')
  end

  def test_available_modules
    resolver = Aurora::StdlibResolver.new
    modules = resolver.available_modules
    assert_includes modules, 'Math'
    assert_includes modules, 'IO'
    assert_equal 2, modules.length
  end
end
