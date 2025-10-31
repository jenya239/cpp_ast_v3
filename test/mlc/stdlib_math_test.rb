# frozen_string_literal: true

require_relative "../test_helper"

class StdlibMathTest < Minitest::Test
  def test_math_module_parses
    source = File.read(File.expand_path('../../lib/mlc/stdlib/math.mlc', __dir__))
    ast = MLC.parse(source)

    assert_equal 'Math', ast.module_decl.name
    assert ast.declarations.length > 0
  end

  def test_math_extern_functions_are_marked_external
    source = File.read(File.expand_path('../../lib/mlc/stdlib/math.mlc', __dir__))
    ast = MLC.parse(source)

    # Find sqrt_f function
    sqrt_f = ast.declarations.find { |d| d.is_a?(MLC::AST::FuncDecl) && d.name == 'sqrt_f' }
    refute_nil sqrt_f, "sqrt_f function should exist"
    assert sqrt_f.external, "sqrt_f should be marked as external"
    assert sqrt_f.exported, "sqrt_f should be marked as exported"
  end

  def test_math_helper_functions_not_external
    source = File.read(File.expand_path('../../lib/mlc/stdlib/math.mlc', __dir__))
    ast = MLC.parse(source)

    # Find hypotenuse function
    hypotenuse = ast.declarations.find { |d| d.is_a?(MLC::AST::FuncDecl) && d.name == 'hypotenuse' }
    refute_nil hypotenuse, "hypotenuse function should exist"
    refute hypotenuse.external, "hypotenuse should not be external"
    assert hypotenuse.exported, "hypotenuse should be exported"
    refute_nil hypotenuse.body, "hypotenuse should have a body"
  end

  def test_import_selective_from_math
    source = <<~AURORA
      import { sqrt_f, pow_f } from "Math"

      fn test() -> f32 = sqrt_f(16.0)
    AURORA

    ast = MLC.parse(source)

    assert_equal 1, ast.imports.length
    import_decl = ast.imports.first
    assert_equal 'Math', import_decl.path
    assert_equal ['sqrt_f', 'pow_f'], import_decl.items
    refute import_decl.import_all
  end

  def test_import_wildcard_from_math
    source = <<~AURORA
      import * as Math from "Math"

      fn test() -> f32 = Math::sqrt_f(16.0)
    AURORA

    ast = MLC.parse(source)

    assert_equal 1, ast.imports.length
    import_decl = ast.imports.first
    assert_equal 'Math', import_decl.path
    assert import_decl.import_all
    assert_equal 'Math', import_decl.alias
  end

  def test_export_extern_combination
    source = <<~AURORA
      module TestMath

      export extern fn test_func(x: f32) -> f32
    AURORA

    ast = MLC.parse(source)
    func = ast.declarations.first

    assert func.is_a?(MLC::AST::FuncDecl)
    assert func.external, "Function should be external"
    assert func.exported, "Function should be exported"
  end
end
