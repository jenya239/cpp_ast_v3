# frozen_string_literal: true

require_relative '../test_helper'

class StdlibScannerIntegrationTest < Minitest::Test
  def test_compile_with_math_functions
    source = <<~AURORA
      import Math::{ sqrt_f, sin_f }

      fn test() -> f32 =
        sqrt_f(sin_f(0.5))

      fn main() -> i32 = do
        let result = test();
        0
      end
    AURORA

    cpp = Aurora.compile(source).to_source

    # Should use proper C++ namespaced function names
    assert_includes cpp, "aurora::math::sqrt_f"
    assert_includes cpp, "aurora::math::sin_f"
  end

  def test_compile_with_graphics_functions
    source = <<~AURORA
      import Graphics::{ create_window, flush_window }

      fn test() -> void = do
        let win = create_window(800, 600, "Test");
        flush_window(win)
      end

      fn main() -> i32 = do
        test();
        0
      end
    AURORA

    cpp = Aurora.compile(source).to_source

    # Should use proper C++ namespaced function names
    assert_includes cpp, "aurora::graphics::create_window"
    assert_includes cpp, "aurora::graphics::flush_window"
  end

  def test_compile_with_io_functions
    source = <<~AURORA
      import IO::{ println }

      fn main() -> i32 = do
        println("Hello, world!");
        0
      end
    AURORA

    cpp = Aurora.compile(source).to_source

    # IO functions should work
    assert_includes cpp, "aurora::io::println"
  end

  def test_compile_with_conv_functions
    source = <<~AURORA
      import Conv::{ parse_i32, to_string_i32 }

      fn test() -> str =
        to_string_i32(42)

      fn main() -> i32 = do
        let s = test();
        0
      end
    AURORA

    cpp = Aurora.compile(source).to_source

    # Conv functions should use aurora namespace (not aurora::conv)
    assert_includes cpp, "aurora::to_string_i32"
  end

  def test_stdlib_resolver_uses_scanner
    resolver = Aurora::StdlibResolver.new

    # Should find all stdlib modules
    assert resolver.stdlib_module?('Math')
    assert resolver.stdlib_module?('Graphics')
    assert resolver.stdlib_module?('IO')
    assert resolver.stdlib_module?('Conv')
    assert resolver.stdlib_module?('String')

    # Should not find non-existent modules
    refute resolver.stdlib_module?('NonExistent')
  end

  def test_stdlib_resolver_resolve_returns_paths
    resolver = Aurora::StdlibResolver.new

    math_path = resolver.resolve('Math')
    refute_nil math_path
    assert File.exist?(math_path)
    assert math_path.end_with?('math.aur')
  end

  def test_scanner_available_from_resolver
    resolver = Aurora::StdlibResolver.new
    scanner = resolver.scanner

    refute_nil scanner
    assert_instance_of Aurora::StdlibScanner, scanner

    # Can use scanner to look up functions
    assert_equal 'aurora::math::sqrt_f', scanner.cpp_function_name('sqrt_f')
  end

  def test_compile_with_multiple_modules
    source = <<~AURORA
      import Math::{ sqrt_f }
      import Graphics::{ create_window }
      import IO::{ println }

      fn test() -> f32 = do
        let win = create_window(800, 600, "Test");
        let x = sqrt_f(4.0);
        println("Done");
        x
      end

      fn main() -> i32 = do
        let y = test();
        0
      end
    AURORA

    cpp = Aurora.compile(source).to_source

    # All namespaced functions should work
    assert_includes cpp, "aurora::math::sqrt_f"
    assert_includes cpp, "aurora::graphics::create_window"
    assert_includes cpp, "aurora::io::println"
  end

  def test_backward_compatibility_with_hardcoded_functions
    # Even if scanner fails, should fall back to hardcoded STDLIB_FUNCTIONS
    source = <<~AURORA
      import Math::{ abs }

      fn test() -> i32 =
        abs(-5)

      fn main() -> i32 = do
        let x = test();
        0
      end
    AURORA

    cpp = Aurora.compile(source).to_source

    # Should use proper namespace
    assert_includes cpp, "aurora::math::abs"
  end

  def test_scanner_handles_extern_functions
    scanner = Aurora::StdlibScanner.new
    scanner.scan_all

    graphics = scanner.module_info('Graphics')

    # create_window is extern fn without export
    assert graphics.functions.key?('create_window')
    create_window = graphics.functions['create_window']
    assert create_window.extern?
    assert_equal 'aurora::graphics::create_window', create_window.qualified_name
  end

  def test_scanner_handles_export_functions
    scanner = Aurora::StdlibScanner.new
    scanner.scan_all

    graphics = scanner.module_info('Graphics')

    # is_quit_event is export fn (not extern)
    assert graphics.functions.key?('is_quit_event')
    is_quit = graphics.functions['is_quit_event']
    refute is_quit.extern?
    assert_equal 'aurora::graphics::is_quit_event', is_quit.qualified_name
  end
end
