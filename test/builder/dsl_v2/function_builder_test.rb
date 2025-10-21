#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class FunctionBuilderTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_basic_function
    # Test basic function creation
    fn_builder = fn :add, 
                   params: [[:i32, :a], [:i32, :b]], 
                   ret: t.i32,
                   constexpr: true,
                   noexcept: true do
      ret id(:a) + id(:b)
    end
    
    assert_not_nil fn_builder
    assert_equal :add, fn_builder.name
    assert_equal 2, fn_builder.params.size
    assert_equal t.i32.to_cpp_type, fn_builder.ret_type.to_cpp_type
    assert_equal true, fn_builder.modifiers[:constexpr]
    assert_equal true, fn_builder.modifiers[:noexcept]
  end

  def test_function_with_body
    # Test function with body
    fn_builder = fn :calculate, 
                   params: [[:f32, :x], [:f32, :y]], 
                   ret: t.f32 do
      let_ :result, id(:x) * id(:y)
      ret id(:result)
    end
    
    assert_not_nil fn_builder
    assert_not_nil fn_builder.body
  end

  def test_function_modifiers
    # Test function modifiers
    fn_builder = fn :test, 
                   params: [[:i32, :x]], 
                   ret: t.void,
                   const: true,
                   noexcept: true,
                   nodiscard: true,
                   static: true,
                   inline: true
    
    assert_equal true, fn_builder.modifiers[:const]
    assert_equal true, fn_builder.modifiers[:noexcept]
    assert_equal true, fn_builder.modifiers[:nodiscard]
    assert_equal true, fn_builder.modifiers[:static]
    assert_equal true, fn_builder.modifiers[:inline]
  end

  def test_function_without_return_type
    # Test function without return type (void)
    fn_builder = fn :print, 
                   params: [[:string, :message]] do
      call(:printf, id(:message))
    end
    
    assert_not_nil fn_builder
    assert_nil fn_builder.ret_type
  end

  def test_function_without_parameters
    # Test function without parameters
    fn_builder = fn :get_time, 
                   ret: t.i64 do
      ret call(:time, nullptr)
    end
    
    assert_not_nil fn_builder
    assert_equal 0, fn_builder.params.size
  end

  def test_constructor
    # Test constructor
    ctor_builder = ctor params: [[:f32, :x], [:f32, :y]], 
                       constexpr: true, 
                       noexcept: true do
        id(:self).member(:x).assign(id(:x))
        id(:self).member(:y).assign(id(:y))
    end
    
    assert_not_nil ctor_builder
    assert_equal "", ctor_builder.name
    assert_equal 2, ctor_builder.params.size
    assert_equal true, ctor_builder.modifiers[:constexpr]
    assert_equal true, ctor_builder.modifiers[:noexcept]
  end

  def test_destructor
    # Test destructor
    dtor_builder = dtor noexcept: true do
      delete id(:ptr)
    end
    
    assert_not_nil dtor_builder
    assert_equal "~", dtor_builder.name
    assert_equal true, dtor_builder.modifiers[:noexcept]
  end

  def test_method_definition
    # Test method definition
    method_builder = def_ :length, 
                      params: [], 
                      ret: t.f32, 
                      const: true, 
                      noexcept: true do
      ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
    end
    
    assert_not_nil method_builder
    assert_equal :length, method_builder.name
    assert_equal t.f32.to_cpp_type, method_builder.ret_type.to_cpp_type
    assert_equal true, method_builder.modifiers[:const]
    assert_equal true, method_builder.modifiers[:noexcept]
  end

  def test_template_function
    # Test template function
    template_builder = template_fn [:T], :max, 
                       params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], 
                       ret: t.ref(:T, const: true) do
      if_ id(:a) > id(:b) do
        ret id(:a)
      else_
        ret id(:b)
      end
    end
    
    assert_not_nil template_builder
    assert_equal :max, template_builder.name
    assert_equal [:T], template_builder.template_generics
  end

  def test_lambda_function
    # Test lambda function
    lambda_builder = lambda_fn params: [[:i32, :x], [:i32, :y]], 
                       ret: t.i32 do
      ret id(:x) + id(:y)
    end
    
    assert_not_nil lambda_builder
    assert_equal "", lambda_builder.name
    assert_equal true, lambda_builder.modifiers[:lambda]
  end

  def test_function_with_requires
    # Test function with requires clause
    requires_builder = fn_with_requires :sort, 
                                       params: [[t.span(t.ref(:T, mutable: true)), :arr]], 
                                       ret: t.void,
                                       requires: concept(:Sortable, :T) do
      # Sort implementation
    end
    
    assert_not_nil requires_builder
    assert_equal :sort, requires_builder.name
    assert_not_nil requires_builder.requires_clause
  end

  def test_function_parameter_formats
    # Test different parameter formats
    fn_builder1 = fn :test1, params: [[:i32, :x], [:f32, :y]] do
      # Simple format
    end
    
    fn_builder2 = fn :test2, params: [
      {type: t.i32, name: :x, default: int(0)},
      {type: t.f32, name: :y}
    ] do
      # Hash format
    end
    
    assert_not_nil fn_builder1
    assert_not_nil fn_builder2
    assert_equal 2, fn_builder1.params.size
    assert_equal 2, fn_builder2.params.size
  end

  def test_function_modifier_chaining
    # Test function modifier chaining
    fn_builder = fn :test, params: [[:i32, :x]], ret: t.i32
    fn_builder.const
    fn_builder.noexcept
    fn_builder.nodiscard
    fn_builder.constexpr
    fn_builder.static
    fn_builder.inline
    
    assert_equal true, fn_builder.modifiers[:const]
    assert_equal true, fn_builder.modifiers[:noexcept]
    assert_equal true, fn_builder.modifiers[:nodiscard]
    assert_equal true, fn_builder.modifiers[:constexpr]
    assert_equal true, fn_builder.modifiers[:static]
    assert_equal true, fn_builder.modifiers[:inline]
  end

  def test_function_to_node_conversion
    # Test conversion to AST node
    fn_builder = fn :add, 
                   params: [[:i32, :a], [:i32, :b]], 
                   ret: t.i32,
                   constexpr: true,
                   noexcept: true do
      ret id(:a) + id(:b)
    end
    
    node = fn_builder.to_node
    
    assert_kind_of CppAst::Nodes::FunctionDeclaration, node
    assert_equal "int", node.return_type
    assert_equal "add", node.name
    assert_equal 2, node.parameters.size
    assert_equal "constexpr ", node.prefix_modifiers
    assert_equal " noexcept", node.modifiers_text
  end

  def test_constructor_to_node_conversion
    # Test constructor conversion to AST node
    ctor_builder = ctor params: [[:f32, :x], [:f32, :y]], 
                       constexpr: true, 
                       noexcept: true do
        id(:self).member(:x).assign(id(:x))
        id(:self).member(:y).assign(id(:y))
    end
    
    node = ctor_builder.to_node
    
    assert_kind_of CppAst::Nodes::FunctionDeclaration, node
    assert_equal "", node.return_type
    assert_equal "", node.name
    assert_equal 2, node.parameters.size
    assert_equal "constexpr ", node.prefix_modifiers
    assert_equal " noexcept", node.modifiers_text
  end

  def test_destructor_to_node_conversion
    # Test destructor conversion to AST node
    dtor_builder = dtor noexcept: true do
      delete id(:ptr)
    end
    
    node = dtor_builder.to_node
    
    assert_kind_of CppAst::Nodes::FunctionDeclaration, node
    assert_equal "", node.return_type
    assert_equal "~", node.name
    assert_equal 0, node.parameters.size
    assert_equal "", node.prefix_modifiers
    assert_equal " noexcept", node.modifiers_text
  end

  def test_method_to_node_conversion
    # Test method conversion to AST node
    method_builder = def_ :length, 
                      params: [], 
                      ret: t.f32, 
                      const: true, 
                      noexcept: true do
      ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
    end
    
    node = method_builder.to_node
    
    assert_kind_of CppAst::Nodes::FunctionDeclaration, node
    assert_equal "float", node.return_type
    assert_equal "length", node.name
    assert_equal 0, node.parameters.size
    assert_equal "", node.prefix_modifiers
    assert_equal " const noexcept", node.modifiers_text
  end

  def test_function_with_complex_body
    # Test function with complex body
    fn_builder = fn :process_data, 
                   params: [[t.span(:f32), :data]], 
                   ret: t.f32,
                   noexcept: true do
      let_ :sum, float(0.0)
      for_range :it, id(:data) do
          id(:sum).assign(id(:sum) + deref(id(:it)))
      end
      ret id(:sum) / cast(t.f32, id(:data).call(:size))
    end
    
    assert_not_nil fn_builder
    assert_not_nil fn_builder.body
  end

  def test_function_with_error_handling
    # Test function with error handling
    fn_builder = fn :safe_divide, 
                   params: [[:f32, :a], [:f32, :b]], 
                   ret: t.result(t.f32, t.string),
                   noexcept: true do
      if_ id(:b) == float(0.0) do
        ret err(string("Division by zero"))
      else_
        ret ok(id(:a) / id(:b))
      end
    end
    
    assert_not_nil fn_builder
    assert_equal t.result(t.f32, t.string), fn_builder.ret_type
  end

  def test_function_with_template_parameters
    # Test function with template parameters
    fn_builder = fn :swap, 
                   params: [[t.ref(:T, mutable: true), :a], [t.ref(:T, mutable: true), :b]], 
                   ret: t.void,
                   noexcept: true do
      let_ :temp, id(:a)
        id(:a).assign(id(:b))
        id(:b).assign(id(:temp))
    end
    
    assert_not_nil fn_builder
    assert_equal 2, fn_builder.params.size
  end

  def test_function_builder_fluent_api
    # Test fluent API for function builder
    fn_builder = fn :test, params: [[:i32, :x]], ret: t.i32
    fn_builder.const.noexcept.nodiscard.constexpr
    
    assert_equal true, fn_builder.modifiers[:const]
    assert_equal true, fn_builder.modifiers[:noexcept]
    assert_equal true, fn_builder.modifiers[:nodiscard]
    assert_equal true, fn_builder.modifiers[:constexpr]
  end

  def test_function_with_default_parameters
    # Test function with default parameters
    fn_builder = fn :create_point, 
                   params: [
                     {type: t.f32, name: :x, default: float(0.0)},
                     {type: t.f32, name: :y, default: float(0.0)}
                   ], 
                   ret: t.Point do
      ret call(:Point, id(:x), id(:y))
    end
    
    assert_not_nil fn_builder
    assert_equal 2, fn_builder.params.size
  end

  def test_function_with_variadic_parameters
    # Test function with variadic parameters
    fn_builder = fn :printf, 
                   params: [[:string, :format]], 
                   ret: t.i32,
                   variadic: true do
      ret call(:printf, id(:format), id(:args))
    end
    
    assert_not_nil fn_builder
    assert_equal true, fn_builder.modifiers[:variadic]
  end
end
