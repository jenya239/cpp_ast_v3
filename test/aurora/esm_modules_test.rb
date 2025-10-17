# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraESMModulesTest < Minitest::Test
  def test_parse_export_function
    aurora_source = <<~AURORA
      export fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 1, ast.declarations.length
    func = ast.declarations[0]
    assert_instance_of Aurora::AST::FuncDecl, func
    assert_equal "add", func.name
    assert func.exported, "Function should be marked as exported"
  end

  def test_parse_export_type
    aurora_source = <<~AURORA
      export type Point = { x: f32, y: f32 }
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 1, ast.declarations.length
    type_decl = ast.declarations[0]
    assert_instance_of Aurora::AST::TypeDecl, type_decl
    assert_equal "Point", type_decl.name
    assert type_decl.exported, "Type should be marked as exported"
  end

  def test_parse_mixed_exported_and_private
    aurora_source = <<~AURORA
      export fn public_fn() -> i32 = 42
      fn private_fn() -> i32 = 24
      export type PublicType = { x: i32 }
      type PrivateType = { y: i32 }
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 4, ast.declarations.length
    assert ast.declarations[0].exported, "First function should be exported"
    refute ast.declarations[1].exported, "Second function should be private"
    assert ast.declarations[2].exported, "First type should be exported"
    refute ast.declarations[3].exported, "Second type should be private"
  end

  def test_parse_esm_named_import
    aurora_source = <<~AURORA
      import { add, subtract } from Math

      fn test() -> i32 = add(1, 2)
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 1, ast.imports.length
    import_decl = ast.imports[0]
    assert_equal "Math", import_decl.path
    assert_equal ["add", "subtract"], import_decl.items
    refute import_decl.import_all
    assert_nil import_decl.alias
  end

  def test_parse_esm_wildcard_import
    aurora_source = <<~AURORA
      import * as Math from Math

      fn test() -> i32 = Math.add(1, 2)
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 1, ast.imports.length
    import_decl = ast.imports[0]
    assert_equal "Math", import_decl.path
    assert import_decl.import_all
    assert_equal "Math", import_decl.alias
    assert_nil import_decl.items
  end

  def test_parse_esm_named_import_with_module_path
    aurora_source = <<~AURORA
      import { Vector, Point } from Math::Geometry

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    import_decl = ast.imports[0]
    assert_equal "Math::Geometry", import_decl.path
    assert_equal ["Vector", "Point"], import_decl.items
  end

  def test_backward_compat_simple_import
    aurora_source = <<~AURORA
      import Math

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    import_decl = ast.imports[0]
    assert_equal "Math", import_decl.path
    assert_nil import_decl.items
    refute import_decl.import_all
  end

  def test_backward_compat_selective_import
    aurora_source = <<~AURORA
      import Math::{add, subtract}

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    import_decl = ast.imports[0]
    assert_equal "Math", import_decl.path
    assert_equal ["add", "subtract"], import_decl.items
  end

  def test_multiple_esm_imports
    aurora_source = <<~AURORA
      import { add } from Math
      import * as Geo from Geometry
      import Utils

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 3, ast.imports.length

    # First import: named
    assert_equal ["add"], ast.imports[0].items
    refute ast.imports[0].import_all

    # Second import: wildcard
    assert ast.imports[1].import_all
    assert_equal "Geo", ast.imports[1].alias

    # Third import: simple
    assert_nil ast.imports[2].items
    refute ast.imports[2].import_all
  end

  def test_complete_esm_module
    aurora_source = <<~AURORA
      import { sqrt } from Math

      export type Point = { x: f32, y: f32 }

      export fn distance(p1: Point, p2: Point) -> f32 =
        sqrt(p1.x * p1.x + p2.y * p2.y)

      fn helper() -> i32 = 42
    AURORA

    ast = Aurora.parse(aurora_source)

    # Verify imports
    assert_equal 1, ast.imports.length
    assert_equal ["sqrt"], ast.imports[0].items

    # Verify declarations
    assert_equal 3, ast.declarations.length

    # Type is exported
    assert_instance_of Aurora::AST::TypeDecl, ast.declarations[0]
    assert ast.declarations[0].exported

    # Function is exported
    assert_instance_of Aurora::AST::FuncDecl, ast.declarations[1]
    assert ast.declarations[1].exported

    # Helper is private
    assert_instance_of Aurora::AST::FuncDecl, ast.declarations[2]
    refute ast.declarations[2].exported
  end

  def test_generate_header_with_exports
    aurora_source = <<~AURORA
      export fn add(a: i32, b: i32) -> i32 = a + b
      fn helper() -> i32 = 42
    AURORA

    result = Aurora.to_hpp_cpp(aurora_source)

    # Both functions should be in header (for now, we generate all declarations)
    # But in future, we could omit non-exported ones
    assert_includes result[:header], "int add"
    assert_includes result[:header], "int helper"
  end

  def test_esm_import_generates_includes
    aurora_source = <<~AURORA
      import { Vector } from Math::Geometry

      export fn test() -> i32 = 0
    AURORA

    result = Aurora.to_hpp_cpp(aurora_source)

    # Should generate #include
    assert_includes result[:header], '#include "math/geometry.hpp"'
  end

  def test_parse_esm_import_with_relative_path
    aurora_source = <<~AURORA
      import { add } from "./math"

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    import_decl = ast.imports[0]
    assert_equal "./math", import_decl.path
    assert_equal ["add"], import_decl.items
  end

  def test_parse_esm_import_with_parent_path
    aurora_source = <<~AURORA
      import { Utils } from "../core/utils"

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    import_decl = ast.imports[0]
    assert_equal "../core/utils", import_decl.path
    assert_equal ["Utils"], import_decl.items
  end

  def test_parse_esm_wildcard_import_with_path
    aurora_source = <<~AURORA
      import * as Math from "./math"

      fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    import_decl = ast.imports[0]
    assert_equal "./math", import_decl.path
    assert import_decl.import_all
    assert_equal "Math", import_decl.alias
  end

  def test_generate_include_from_file_path
    aurora_source = <<~AURORA
      import { add } from "./math"

      export fn test() -> i32 = 0
    AURORA

    result = Aurora.to_hpp_cpp(aurora_source)

    # File path should be preserved in #include
    assert_includes result[:header], '#include "./math.hpp"'
  end

  def test_generate_include_from_parent_path
    aurora_source = <<~AURORA
      import { Utils } from "../core/utils"

      export fn test() -> i32 = 0
    AURORA

    result = Aurora.to_hpp_cpp(aurora_source)

    assert_includes result[:header], '#include "../core/utils.hpp"'
  end

  def test_mixed_import_styles
    aurora_source = <<~AURORA
      import { add } from "./math"
      import { Point } from Geometry
      import * as Utils from "../utils"

      export fn test() -> i32 = 0
    AURORA

    ast = Aurora.parse(aurora_source)

    assert_equal 3, ast.imports.length
    assert_equal "./math", ast.imports[0].path
    assert_equal "Geometry", ast.imports[1].path
    assert_equal "../utils", ast.imports[2].path
  end
end
