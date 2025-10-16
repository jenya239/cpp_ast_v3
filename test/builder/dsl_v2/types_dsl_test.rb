#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class TypesDSLTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_basic_types
    # Test basic types
    assert_equal "int", t.i32.to_cpp_type
    assert_equal "float", t.f32.to_cpp_type
    assert_equal "double", t.f64.to_cpp_type
    assert_equal "bool", t.bool.to_cpp_type
    assert_equal "void", t.void.to_cpp_type
    assert_equal "char", t.char.to_cpp_type
    assert_equal "std::string", t.string.to_cpp_type
  end

  def test_reference_types
    # Test reference types
    ref_type = t.ref(:i32)
    assert_equal "int&", ref_type.to_cpp_type
    
    const_ref_type = t.ref(:i32, const: true)
    assert_equal "const int&", const_ref_type.to_cpp_type
    
    mut_ref_type = t.mut(:i32)
    assert_equal "int&", mut_ref_type.to_cpp_type
  end

  def test_ownership_types
    # Test ownership types
    owned_type = t.owned(:Buffer)
    assert_equal "std::unique_ptr<Buffer>", owned_type.to_cpp_type
    
    borrowed_type = t.borrowed(:Config)
    assert_equal "const Config&", borrowed_type.to_cpp_type
    
    mut_borrowed_type = t.mut_borrowed(:State)
    assert_equal "State&", mut_borrowed_type.to_cpp_type
    
    span_type = t.span(:f32)
    assert_equal "std::span<float>", span_type.to_cpp_type
    
    span_const_type = t.span_const(:f32)
    assert_equal "std::span<const float>", span_const_type.to_cpp_type
  end

  def test_container_types
    # Test container types
    vec_type = t.vec(:i32)
    assert_equal "std::vector<int>", vec_type.to_cpp_type
    
    array_type = t.array(:i32, 10)
    assert_equal "std::array<int, 10>", array_type.to_cpp_type
    
    array_dynamic_type = t.array(:i32)
    assert_equal "std::array<int>", array_dynamic_type.to_cpp_type
  end

  def test_result_option_types
    # Test Result/Option types
    result_type = t.result(:f32, :string)
    assert_equal "std::expected<float, std::string>", result_type.to_cpp_type
    
    option_type = t.option(:i32)
    assert_equal "std::optional<int>", option_type.to_cpp_type
    
    variant_type = t.variant(:Circle, :Rect, :Polygon)
    assert_equal "std::variant<Circle, Rect, Polygon>", variant_type.to_cpp_type
    
    tuple_type = t.tuple(:i32, :f32, :string)
    assert_equal "std::tuple<int, float, std::string>", tuple_type.to_cpp_type
  end

  def test_template_types
    # Test template types
    # Use proper template syntax: template(name, *type_params)
    template_type = t.template("std::vector", :i32)
    assert_equal "std::vector<int>", template_type.to_cpp_type

    # For standard containers, prefer using dedicated methods
    vec_type = t.vec(:i32)
    assert_equal "std::vector<int>", vec_type.to_cpp_type

    custom_type = t.of(:MyType)
    assert_equal "MyType", custom_type.to_cpp_type
  end

  def test_type_builder_methods
    # Test type builder methods
    type = t.i32
    
    # Test const
    const_type = type.const
    assert_equal "const int", const_type.to_cpp_type
    
    # Test ref
    ref_type = type.ref
    assert_equal "const int&", ref_type.to_cpp_type
    
    # Test mut
    mut_type = type.mut
    assert_equal "int&", mut_type.to_cpp_type
    
    # Test template arguments
    template_type = type[:f32, :double]
    assert_equal "int<float, double>", template_type.to_cpp_type
  end

  def test_ast_node_conversion
    # Test conversion to AST nodes
    type = t.i32
    ast_node = type.to_ast_node
    
    assert_not_nil ast_node
    assert_equal "int", ast_node.name
    assert_equal false, ast_node.is_const
    assert_equal false, ast_node.is_reference
    assert_equal false, ast_node.is_mutable
  end

  def test_ownership_type_builder
    # Test ownership type builder
    inner_type = t.i32
    owned_type = t.owned(inner_type)
    
    assert_equal "std::unique_ptr<int>", owned_type.to_cpp_type
    assert_equal :owned, owned_type.ownership_kind
    assert_equal inner_type, owned_type.inner_type
  end

  def test_type_chain_operations
    # Test chaining operations
    type = t.i32.const.ref

    assert_equal "const int&", type.to_cpp_type
    assert_equal true, type.is_const
    assert_equal true, type.is_ref
    assert_equal false, type.is_mutable
  end

  def test_error_handling
    # Test error handling for invalid types
    assert_raise(ArgumentError) do
      t.owned(nil)
    end
    
    assert_raise(ArgumentError) do
      t.ref(nil)
    end
  end

  def test_type_equality
    # Test type equality
    type1 = t.i32
    type2 = t.i32
    type3 = t.f32
    
    assert_equal type1.to_cpp_type, type2.to_cpp_type
    assert_not_equal type1.to_cpp_type, type3.to_cpp_type
  end

  def test_complex_type_combinations
    # Test complex type combinations
    complex_type = t.vec(t.ref(:Point, const: true))
    assert_equal "std::vector<const Point&>", complex_type.to_cpp_type
    
    nested_type = t.owned(t.vec(t.owned(:Buffer)))
    assert_equal "std::unique_ptr<std::vector<std::unique_ptr<Buffer>>>", nested_type.to_cpp_type
    
    result_with_option = t.result(t.option(:i32), :string)
    assert_equal "std::expected<std::optional<int>, std::string>", result_with_option.to_cpp_type
  end
end
