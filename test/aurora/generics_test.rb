# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraGenericsTest < Minitest::Test
  def test_parse_generic_type
    aurora_source = <<~AURORA
      type Result<T, E> = Ok(T) | Err(E)
    AURORA

    ast = Aurora.parse(aurora_source)
    refute_nil ast

    type_decl = ast.declarations.first
    assert_instance_of Aurora::AST::TypeDecl, type_decl
    assert_equal "Result", type_decl.name

    # Should have type parameters
    assert_equal 2, type_decl.type_params.length
    assert_equal ["T", "E"], type_decl.type_params.map(&:name)
  end

  def test_parse_generic_function
    aurora_source = <<~AURORA
      fn identity<T>(x: T) -> T = x
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations.first

    assert_instance_of Aurora::AST::FuncDecl, func
    assert_equal "identity", func.name

    # Should have type parameters
    assert_equal 1, func.type_params.length
    assert_equal ["T"], func.type_params.map(&:name)
  end

  def test_generic_option_type
    aurora_source = <<~AURORA
      type Option<T> = Some(T) | None
    AURORA

    ast = Aurora.parse(aurora_source)
    type_decl = ast.declarations.first

    assert_equal "Option", type_decl.name
    assert_equal 1, type_decl.type_params.length
    assert_equal ["T"], type_decl.type_params.map(&:name)

    # Type should be a sum type
    assert_instance_of Aurora::AST::SumType, type_decl.type
    assert_equal 2, type_decl.type.variants.length
  end

  def test_generic_function_with_constraints
    aurora_source = <<~AURORA
      fn add<T: Numeric>(a: T, b: T) -> T = a + b
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations.first

    # Should have type parameter with constraint
    assert_equal 1, func.type_params.length
    assert_equal "T", func.type_params[0].name
    assert_equal "Numeric", func.type_params[0].constraint
  end

  def test_constraint_lowering_to_cpp
    aurora_source = <<~AURORA
      fn add<T: Numeric>(a: T, b: T) -> T = a + b
    AURORA

    cpp = Aurora.to_cpp(aurora_source)

    assert_includes cpp, "template<typename T>"
    assert_includes cpp, "requires Numeric<T>"
  end

  def test_type_constraint_in_cpp_output
    aurora_source = <<~AURORA
      type Box<T: Numeric> = { value: T }
      type IntBox = Box<i32>
    AURORA

    cpp = Aurora.to_cpp(aurora_source)

    assert_includes cpp, "template<typename T>"
    assert_includes cpp, "requires Numeric<T>"
    assert_includes cpp, "struct Box"
  end

  def test_type_constraint_violation_raises
    aurora_source = <<~AURORA
      type Box<T: Numeric> = { value: T }
      type BoolBox = Box<bool>
    AURORA

    error = assert_raises Aurora::CompileError do
      Aurora.to_cpp(aurora_source)
    end

    assert_includes error.message, "does not satisfy constraint"
    assert_includes error.message, "Numeric"
  end

  def test_unknown_constraint_raises
    aurora_source = <<~AURORA
      type Box<T: Fancy> = { value: T }
    AURORA

    error = assert_raises Aurora::CompileError do
      Aurora.to_cpp(aurora_source)
    end

    assert_includes error.message, "Unknown constraint"
  end

  def test_generic_lowering_to_cpp_templates
    aurora_source = <<~AURORA
      type Option<T> = Some(T) | None

      fn unwrap_or<T>(opt: Option<T>, default: T) -> T =
        match opt
          | Some(x) => x
          | None => default
    AURORA

    cpp_code = Aurora.to_cpp(aurora_source)

    # Should generate C++ templates
    assert_includes cpp_code, "template"
    assert_includes cpp_code, "typename T"

    # Should have generic Option type structures
    assert_includes cpp_code, "struct Some"
    assert_includes cpp_code, "struct None"

    # Should have generic function
    assert_includes cpp_code, "unwrap_or"
  end
end
