# frozen_string_literal: true

require_relative "../test_helper"

class StdlibResolutionTest < Minitest::Test
  def test_stdlib_resolver_recognizes_math
    resolver = MLC::StdlibResolver.new
    assert resolver.stdlib_module?('Math')
  end

  def test_stdlib_resolver_recognizes_io
    resolver = MLC::StdlibResolver.new
    assert resolver.stdlib_module?('IO')
  end

  def test_stdlib_resolver_recognizes_string
    resolver = MLC::StdlibResolver.new
    assert resolver.stdlib_module?('String')
  end

  def test_stdlib_resolver_does_not_recognize_unknown
    resolver = MLC::StdlibResolver.new
    refute resolver.stdlib_module?('Unknown')
    refute resolver.stdlib_module?('CustomModule')
  end

  def test_stdlib_resolver_resolves_math
    resolver = MLC::StdlibResolver.new
    path = resolver.resolve('Math')
    refute_nil path
    assert File.exist?(path)
    assert path.end_with?('math.aur')
  end

  def test_stdlib_resolver_resolves_io
    resolver = MLC::StdlibResolver.new
    path = resolver.resolve('IO')
    refute_nil path
    assert File.exist?(path)
    assert path.end_with?('io.aur')
  end

  def test_stdlib_resolver_resolves_string
    resolver = MLC::StdlibResolver.new
    path = resolver.resolve('String')
    refute_nil path
    assert File.exist?(path)
    assert path.end_with?('string.aur')
  end

  def test_stdlib_resolver_returns_nil_for_unknown
    resolver = MLC::StdlibResolver.new
    assert_nil resolver.resolve('Unknown')
  end

  def test_available_modules
    resolver = MLC::StdlibResolver.new
    modules = resolver.available_modules
    expected = %w[Array Conv File Graphics IO Json Math Option Result String]
    expected.each do |mod|
      assert_includes modules, mod
    end
    assert_equal expected.sort, modules.sort
  end
end
