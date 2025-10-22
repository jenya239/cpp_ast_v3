# frozen_string_literal: true

require_relative "../test_helper"

class StdlibIOTest < Minitest::Test
  def test_io_module_parses
    source = File.read(File.expand_path('../../lib/aurora/stdlib/io.aur', __dir__))
    ast = Aurora.parse(source)

    assert_equal 'IO', ast.module_decl.name
    assert ast.declarations.length > 0
  end

  def test_io_extern_functions_are_marked_external
    source = File.read(File.expand_path('../../lib/aurora/stdlib/io.aur', __dir__))
    ast = Aurora.parse(source)

    # Find println function
    println = ast.declarations.find { |d| d.is_a?(Aurora::AST::FuncDecl) && d.name == 'println' }
    refute_nil println, "println function should exist"
    assert println.external, "println should be marked as external"
  end

  def test_io_helper_functions_not_external
    source = File.read(File.expand_path('../../lib/aurora/stdlib/io.aur', __dir__))
    ast = Aurora.parse(source)

    # Find debug_print function
    debug_print = ast.declarations.find { |d| d.is_a?(Aurora::AST::FuncDecl) && d.name == 'debug_print' }
    refute_nil debug_print, "debug_print function should exist"
    refute debug_print.external, "debug_print should not be external"
    assert debug_print.exported, "debug_print should be exported"
    refute_nil debug_print.body, "debug_print should have a body"
  end

  def test_import_selective_from_io
    source = <<~AURORA
      import { println, print } from "IO"

      fn greet(name: str) -> void = println("Hello")
    AURORA

    ast = Aurora.parse(source)

    assert_equal 1, ast.imports.length
    import_decl = ast.imports.first
    assert_equal 'IO', import_decl.path
    assert_equal ['println', 'print'], import_decl.items
    refute import_decl.import_all
  end

  def test_import_wildcard_from_io
    source = <<~AURORA
      import * as IO from "IO"

      fn test() -> void = IO::println("Test")
    AURORA

    ast = Aurora.parse(source)

    assert_equal 1, ast.imports.length
    import_decl = ast.imports.first
    assert_equal 'IO', import_decl.path
    assert import_decl.import_all
    assert_equal 'IO', import_decl.alias
  end

  def test_io_and_math_combined
    source = <<~AURORA
      import { sqrt_f } from "Math"
      import { println } from "IO"

      fn test() -> f32 = sqrt_f(16.0)
    AURORA

    ast = Aurora.parse(source)

    assert_equal 2, ast.imports.length
    math_import = ast.imports.find { |i| i.path == 'Math' }
    io_import = ast.imports.find { |i| i.path == 'IO' }

    refute_nil math_import
    refute_nil io_import
    assert_equal ['sqrt_f'], math_import.items
    assert_equal ['println'], io_import.items
  end
end
