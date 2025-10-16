#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class OwnershipDSLTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_owned_type
    # Test owned type (unique_ptr)
    owned_type = t.owned(:Buffer)
    assert_not_nil owned_type
    assert_equal "std::unique_ptr<Buffer>", owned_type.to_cpp_type
    assert_equal :owned, owned_type.ownership_kind
    assert_equal :Buffer, owned_type.inner_type.name
  end

  def test_shared_type
    # Test shared type (shared_ptr)
    shared_type = t.shared(:Resource)
    assert_not_nil shared_type
    assert_equal "std::shared_ptr<Resource>", shared_type.to_cpp_type
    assert_equal :shared, shared_type.ownership_kind
    assert_equal :Resource, shared_type.inner_type.name
  end

  def test_weak_type
    # Test weak type (weak_ptr)
    weak_type = t.weak(:Resource)
    assert_not_nil weak_type
    assert_equal "std::weak_ptr<Resource>", weak_type.to_cpp_type
    assert_equal :weak, weak_type.ownership_kind
    assert_equal :Resource, weak_type.inner_type.name
  end

  def test_borrowed_type
    # Test borrowed type (const T&)
    borrowed_type = t.borrowed(:Config)
    assert_not_nil borrowed_type
    assert_equal "const Config&", borrowed_type.to_cpp_type
    assert_equal :borrowed, borrowed_type.ownership_kind
    assert_equal :Config, borrowed_type.inner_type.name
  end

  def test_mut_borrowed_type
    # Test mutable borrowed type (T&)
    mut_borrowed_type = t.mut_borrowed(:State)
    assert_not_nil mut_borrowed_type
    assert_equal "State&", mut_borrowed_type.to_cpp_type
    assert_equal :mut_borrowed, mut_borrowed_type.ownership_kind
    assert_equal :State, mut_borrowed_type.inner_type.name
  end

  def test_span_type
    # Test span type (std::span<T>)
    span_type = t.span(:f32)
    assert_not_nil span_type
    assert_equal "std::span<float>", span_type.to_cpp_type
    assert_equal :span, span_type.ownership_kind
    assert_equal :float, span_type.inner_type.name
  end

  def test_span_const_type
    # Test const span type (std::span<const T>)
    span_const_type = t.span_const(:f32)
    assert_not_nil span_const_type
    assert_equal "std::span<const float>", span_const_type.to_cpp_type
    assert_equal :span_const, span_const_type.ownership_kind
    assert_equal :float, span_const_type.inner_type.name
  end

  def test_raw_pointer_type
    # Test raw pointer type (T*)
    raw_ptr_type = t.raw_ptr(:i32)
    assert_not_nil raw_ptr_type
    assert_equal "int*", raw_ptr_type.to_cpp_type
    assert_equal :raw_ptr, raw_ptr_type.ownership_kind
    assert_equal :int, raw_ptr_type.inner_type.name
  end

  def test_const_raw_pointer_type
    # Test const raw pointer type (const T*)
    const_raw_ptr_type = t.const_raw_ptr(:i32)
    assert_not_nil const_raw_ptr_type
    assert_equal "const int*", const_raw_ptr_type.to_cpp_type
    assert_equal :const_raw_ptr, const_raw_ptr_type.ownership_kind
    assert_equal :int, const_raw_ptr_type.inner_type.name
  end

  def test_array_type
    # Test array type (T[])
    array_type = t.array(:i32)
    assert_not_nil array_type
    assert_equal "std::array<int>", array_type.to_cpp_type
    assert_equal :array, array_type.ownership_kind
    assert_equal :int, array_type.inner_type.name
  end

  def test_sized_array_type
    # Test sized array type (T[N])
    sized_array_type = t.array(:i32, 10)
    assert_not_nil sized_array_type
    assert_equal "std::array<int, 10>", sized_array_type.to_cpp_type
    assert_equal :array, sized_array_type.ownership_kind
    assert_equal :int, sized_array_type.inner_type[0].name
    assert_equal 10, sized_array_type.inner_type[1]
  end

  def test_result_type
    # Test Result type (std::expected<T, E>)
    result_type = t.result(:f32, :string)
    assert_not_nil result_type
    assert_equal "std::expected<float, std::string>", result_type.to_cpp_type
    assert_equal :result, result_type.ownership_kind
    assert_equal :float, result_type.inner_type[0].name
    assert_equal :string, result_type.inner_type[1].name
  end

  def test_option_type
    # Test Option type (std::optional<T>)
    option_type = t.option(:i32)
    assert_not_nil option_type
    assert_equal "std::optional<int>", option_type.to_cpp_type
    assert_equal :option, option_type.ownership_kind
    assert_equal :int, option_type.inner_type.name
  end

  def test_variant_type
    # Test Variant type (std::variant<Ts...>)
    variant_type = t.variant(:Circle, :Rect, :Polygon)
    assert_not_nil variant_type
    assert_equal "std::variant<Circle, Rect, Polygon>", variant_type.to_cpp_type
    assert_equal :variant, variant_type.ownership_kind
    assert_equal [:Circle, :Rect, :Polygon], variant_type.inner_type.map(&:name)
  end

  def test_tuple_type
    # Test Tuple type (std::tuple<Ts...>)
    tuple_type = t.tuple(:i32, :f32, :string)
    assert_not_nil tuple_type
    assert_equal "std::tuple<int, float, std::string>", tuple_type.to_cpp_type
    assert_equal :tuple, tuple_type.ownership_kind
    assert_equal [:int, :float, :string], tuple_type.inner_type.map(&:name)
  end

  def test_function_type
    # Test Function type (std::function<R(Args...)>)
    function_type = t.function(:f32, :i32, :f32)
    assert_not_nil function_type
    assert_equal "std::function<float(int, float)>", function_type.to_cpp_type
    assert_equal :function, function_type.ownership_kind
    assert_equal [:float, :int, :float], function_type.inner_type.map(&:name)
  end

  def test_lambda_type
    # Test Lambda type (auto)
    lambda_type = t.lambda
    assert_not_nil lambda_type
    assert_equal "auto", lambda_type.to_cpp_type
    assert_equal :lambda, lambda_type.ownership_kind
    assert_nil lambda_type.inner_type
  end

  def test_auto_type
    # Test Auto type (auto)
    auto_type = t.auto
    assert_not_nil auto_type
    assert_equal "auto", auto_type.to_cpp_type
    assert_equal :auto, auto_type.ownership_kind
    assert_nil auto_type.inner_type
  end

  def test_void_type
    # Test Void type (void)
    void_type = t.void
    assert_not_nil void_type
    assert_equal "void", void_type.to_cpp_type
    assert_equal :void, void_type.ownership_kind
    assert_nil void_type.inner_type
  end

  def test_null_type
    # Test Null type (nullptr_t)
    null_type = t.null
    assert_not_nil null_type
    assert_equal "nullptr_t", null_type.to_cpp_type
    assert_equal :null, null_type.ownership_kind
    assert_nil null_type.inner_type
  end

  def test_size_t_type
    # Test size_t type
    size_t_type = t.size_t
    assert_not_nil size_t_type
    assert_equal "size_t", size_t_type.to_cpp_type
    assert_equal :size_t, size_t_type.ownership_kind
    assert_nil size_t_type.inner_type
  end

  def test_ptrdiff_t_type
    # Test ptrdiff_t type
    ptrdiff_t_type = t.ptrdiff_t
    assert_not_nil ptrdiff_t_type
    assert_equal "ptrdiff_t", ptrdiff_t_type.to_cpp_type
    assert_equal :ptrdiff_t, ptrdiff_t_type.ownership_kind
    assert_nil ptrdiff_t_type.inner_type
  end

  def test_integer_types
    # Test integer types
    assert_equal "int8_t", t.int8.to_cpp_type
    assert_equal "int16_t", t.int16.to_cpp_type
    assert_equal "int32_t", t.int32.to_cpp_type
    assert_equal "int64_t", t.int64.to_cpp_type
    
    assert_equal "uint8_t", t.uint8.to_cpp_type
    assert_equal "uint16_t", t.uint16.to_cpp_type
    assert_equal "uint32_t", t.uint32.to_cpp_type
    assert_equal "uint64_t", t.uint64.to_cpp_type
  end

  def test_float_types
    # Test float types
    assert_equal "float", t.float32.to_cpp_type
    assert_equal "double", t.float64.to_cpp_type
  end

  def test_boolean_type
    # Test boolean type
    assert_equal "bool", t.bool.to_cpp_type
  end

  def test_character_types
    # Test character types
    assert_equal "char", t.char.to_cpp_type
    assert_equal "wchar_t", t.wchar.to_cpp_type
    assert_equal "char16_t", t.char16.to_cpp_type
    assert_equal "char32_t", t.char32.to_cpp_type
  end

  def test_string_types
    # Test string types - using wstring which returns OwnershipTypeBuilder
    wstring_type = t.wstring
    assert_equal "wstring", wstring_type.to_cpp_type

    u16string_type = t.u16string
    assert_equal "u16string", u16string_type.to_cpp_type

    u32string_type = t.u32string
    assert_equal "u32string", u32string_type.to_cpp_type
  end

  def test_custom_type
    # Test custom type
    custom_type = t.of(:MyType)
    assert_not_nil custom_type
    assert_equal "MyType", custom_type.to_cpp_type
    assert_equal :custom, custom_type.ownership_kind
    assert_equal :MyType, custom_type.inner_type
  end

  def test_template_type
    # Test template type with proper syntax
    template_type = t.template("std::vector", :i32)
    assert_not_nil template_type
    assert_equal "std::vector<int>", template_type.to_cpp_type
  end

  def test_ownership_type_builder_methods
    # Test ownership type builder methods
    inner_type = t.i32
    owned_type = t.owned(inner_type)
    
    assert_equal "std::unique_ptr<int>", owned_type.to_cpp_type
    assert_equal :owned, owned_type.ownership_kind
    assert_equal inner_type, owned_type.inner_type
  end

  def test_ownership_type_ast_conversion
    # Test conversion to AST node
    owned_type = t.owned(:Buffer)
    ast_node = owned_type.to_ast_node
    
    assert_not_nil ast_node
    assert_equal "std::unique_ptr<Buffer>", ast_node.name
    assert_equal false, ast_node.is_const
    assert_equal false, ast_node.is_reference
    assert_equal false, ast_node.is_mutable
  end

  def test_complex_ownership_types
    # Test complex ownership types
    complex_type = t.owned(t.vec(t.ref(:Point, const: true)))
    assert_equal "std::unique_ptr<std::vector<const Point&>>", complex_type.to_cpp_type
    
    nested_type = t.shared(t.option(t.owned(:Buffer)))
    assert_equal "std::shared_ptr<std::optional<std::unique_ptr<Buffer>>>", nested_type.to_cpp_type
    
    result_with_option = t.result(t.option(:i32), :string)
    assert_equal "std::expected<std::optional<int>, std::string>", result_with_option.to_cpp_type
  end

  def test_ownership_type_equality
    # Test ownership type equality
    type1 = t.owned(:Buffer)
    type2 = t.owned(:Buffer)
    type3 = t.shared(:Buffer)
    
    assert_equal type1.to_cpp_type, type2.to_cpp_type
    assert_not_equal type1.to_cpp_type, type3.to_cpp_type
  end

  def test_ownership_type_error_handling
    # Test error handling for invalid ownership types
    assert_raise(ArgumentError) do
      t.owned(nil)
    end
    
    assert_raise(ArgumentError) do
      t.borrowed(nil)
    end
  end

  def test_ownership_type_chaining
    # Test ownership type chaining
    base_type = t.i32
    owned_type = t.owned(base_type)
    shared_type = t.shared(owned_type)
    
    assert_equal "std::shared_ptr<std::unique_ptr<int>>", shared_type.to_cpp_type
  end

  def test_ownership_type_with_template_arguments
    # Test ownership type with template arguments
    template_type = t.vec(:i32)
    owned_template = t.owned(template_type)

    assert_equal "std::unique_ptr<std::vector<int>>", owned_template.to_cpp_type
  end

  def test_ownership_type_with_const_qualifiers
    # Test ownership type with const qualifiers
    const_type = t.i32.const
    owned_const_type = t.owned(const_type)
    
    assert_equal "std::unique_ptr<const int>", owned_const_type.to_cpp_type
  end

  def test_ownership_type_with_reference_qualifiers
    # Test ownership type with reference qualifiers
    ref_type = t.i32.ref
    owned_ref_type = t.owned(ref_type)
    
    assert_equal "std::unique_ptr<const int&>", owned_ref_type.to_cpp_type
  end
end
