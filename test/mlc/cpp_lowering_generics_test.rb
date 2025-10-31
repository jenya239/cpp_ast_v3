# frozen_string_literal: true

require_relative '../test_helper'

class CppLoweringGenericsTest < Minitest::Test
  include MLC::HighIR

  def setup
    @lowerer = MLC::Backend::CodeGen.new
  end

  def test_type_variable_lowering
    # T -> T
    type_var = Builder.type_variable('T')
    cpp_type = @lowerer.map_type(type_var)

    assert_equal 'T', cpp_type
  end

  def test_generic_type_single_param
    # Option<i32> -> Option<int>
    option_base = Builder.primitive_type('Option')
    i32_type = Builder.primitive_type('i32')
    option_i32 = Builder.generic_type(option_base, [i32_type])

    cpp_type = @lowerer.map_type(option_i32)

    assert_equal 'Option<int>', cpp_type
  end

  def test_generic_type_multiple_params
    # Result<i32, str> -> Result<int, aurora::String>
    result_base = Builder.primitive_type('Result')
    i32_type = Builder.primitive_type('i32')
    str_type = Builder.primitive_type('str')
    result_type = Builder.generic_type(result_base, [i32_type, str_type])

    cpp_type = @lowerer.map_type(result_type)

    assert_equal 'Result<int, aurora::String>', cpp_type
  end

  def test_generic_type_with_type_variable
    # Option<T> -> Option<T>
    option_base = Builder.primitive_type('Option')
    t_var = Builder.type_variable('T')
    option_t = Builder.generic_type(option_base, [t_var])

    cpp_type = @lowerer.map_type(option_t)

    assert_equal 'Option<T>', cpp_type
  end

  def test_nested_generic_types
    # Option<Result<i32, str>> -> Option<Result<int, aurora::String>>
    option_base = Builder.primitive_type('Option')
    result_base = Builder.primitive_type('Result')
    i32_type = Builder.primitive_type('i32')
    str_type = Builder.primitive_type('str')

    result_i32_str = Builder.generic_type(result_base, [i32_type, str_type])
    option_result = Builder.generic_type(option_base, [result_i32_str])

    cpp_type = @lowerer.map_type(option_result)

    assert_equal 'Option<Result<int, aurora::String>>', cpp_type
  end

  def test_array_of_generic_type
    # Option<i32>[] -> std::vector<Option<int>>
    option_base = Builder.primitive_type('Option')
    i32_type = Builder.primitive_type('i32')
    option_i32 = Builder.generic_type(option_base, [i32_type])
    array_type = Builder.array_type(option_i32)

    cpp_type = @lowerer.map_type(array_type)

    assert_equal 'std::vector<Option<int>>', cpp_type
  end

  def test_function_type_simple
    # fn(i32) -> f32 -> std::function<float(int)>
    i32_type = Builder.primitive_type('i32')
    f32_type = Builder.primitive_type('f32')
    fn_type = Builder.function_type([{name: 'x', type: i32_type}], f32_type)

    cpp_type = @lowerer.map_type(fn_type)

    assert_equal 'std::function<float(int)>', cpp_type
  end

  def test_function_type_multiple_params
    # fn(i32, f32, str) -> bool -> std::function<bool(int, float, aurora::String)>
    i32_type = Builder.primitive_type('i32')
    f32_type = Builder.primitive_type('f32')
    str_type = Builder.primitive_type('str')
    bool_type = Builder.primitive_type('bool')

    fn_type = Builder.function_type(
      [{name: 'x', type: i32_type}, {name: 'y', type: f32_type}, {name: 'z', type: str_type}],
      bool_type
    )

    cpp_type = @lowerer.map_type(fn_type)

    assert_equal 'std::function<bool(int, float, aurora::String)>', cpp_type
  end

  def test_function_type_with_type_variables
    # fn(T) -> U -> std::function<U(T)>
    t_var = Builder.type_variable('T')
    u_var = Builder.type_variable('U')
    fn_type = Builder.function_type([{name: 'x', type: t_var}], u_var)

    cpp_type = @lowerer.map_type(fn_type)

    assert_equal 'std::function<U(T)>', cpp_type
  end

  def test_function_type_with_generic_types
    # fn(Option<i32>) -> Result<f32, str> -> std::function<Result<float, aurora::String>(Option<int>)>
    option_base = Builder.primitive_type('Option')
    result_base = Builder.primitive_type('Result')
    i32_type = Builder.primitive_type('i32')
    f32_type = Builder.primitive_type('f32')
    str_type = Builder.primitive_type('str')

    option_i32 = Builder.generic_type(option_base, [i32_type])
    result_f32_str = Builder.generic_type(result_base, [f32_type, str_type])

    fn_type = Builder.function_type([{name: 'x', type: option_i32}], result_f32_str)

    cpp_type = @lowerer.map_type(fn_type)

    assert_equal 'std::function<Result<float, aurora::String>(Option<int>)>', cpp_type
  end

  def test_generic_function_lowering
    # fn identity<T>(x: T) -> T
    t_var = Builder.type_variable('T')
    param = Builder.param('x', t_var)
    type_param = Builder.type_param('T')
    body = Builder.block_expr([], Builder.unit_literal, t_var)

    func = Func.new(
      name: 'identity',
      params: [param],
      ret_type: t_var,
      body: body,
      type_params: [type_param]
    )

    cpp_func = @lowerer.lower_function(func)

    # Should generate a template declaration
    assert_instance_of CppAst::Nodes::TemplateDeclaration, cpp_func
    assert_match(/template/, cpp_func.to_source)
  end

  def test_generic_function_with_multiple_type_params
    # fn pair<T, U>(x: T, y: U) -> {T, U}
    t_var = Builder.type_variable('T')
    u_var = Builder.type_variable('U')
    param1 = Builder.param('x', t_var)
    param2 = Builder.param('y', u_var)
    type_param1 = Builder.type_param('T')
    type_param2 = Builder.type_param('U')

    # Return type is a record with T and U fields
    ret_type = Builder.record_type('pair', [
      {name: 'first', type: t_var},
      {name: 'second', type: u_var}
    ])

    body = Builder.block_expr([], Builder.unit_literal, ret_type)

    func = Func.new(
      name: 'pair',
      params: [param1, param2],
      ret_type: ret_type,
      body: body,
      type_params: [type_param1, type_param2]
    )

    cpp_func = @lowerer.lower_function(func)

    # Should generate template<typename T, typename U>
    assert_instance_of CppAst::Nodes::TemplateDeclaration, cpp_func
    source = cpp_func.to_source
    assert_match(/template/, source)
    assert_match(/typename T/, source)
    assert_match(/typename U/, source)
  end

  def test_function_with_generic_array_param
    # fn length<T>(arr: T[]) -> i32
    t_var = Builder.type_variable('T')
    array_t = Builder.array_type(t_var)
    i32_type = Builder.primitive_type('i32')

    param = Builder.param('arr', array_t)
    type_param = Builder.type_param('T')
    body = Builder.block_expr([], Builder.unit_literal, i32_type)

    func = Func.new(
      name: 'length',
      params: [param],
      ret_type: i32_type,
      body: body,
      type_params: [type_param]
    )

    cpp_func = @lowerer.lower_function(func)

    assert_instance_of CppAst::Nodes::TemplateDeclaration, cpp_func
    source = cpp_func.to_source

    # Should have template<typename T>
    assert_match(/template/, source)
    assert_match(/typename T/, source)

    # Parameter should be std::vector<T>
    assert_match(/std::vector<T>/, source)
  end

  def test_function_with_generic_option_param
    # fn unwrap<T>(opt: Option<T>, default: T) -> T
    option_base = Builder.primitive_type('Option')
    t_var = Builder.type_variable('T')
    option_t = Builder.generic_type(option_base, [t_var])

    param1 = Builder.param('opt', option_t)
    param2 = Builder.param('default', t_var)
    type_param = Builder.type_param('T')
    body = Builder.block_expr([], Builder.unit_literal, t_var)

    func = Func.new(
      name: 'unwrap',
      params: [param1, param2],
      ret_type: t_var,
      body: body,
      type_params: [type_param]
    )

    cpp_func = @lowerer.lower_function(func)

    assert_instance_of CppAst::Nodes::TemplateDeclaration, cpp_func
    source = cpp_func.to_source

    # Should have template<typename T>
    assert_match(/template/, source)
    assert_match(/typename T/, source)

    # First parameter should be Option<T>
    assert_match(/Option<T>/, source)
  end

  def test_function_effects_are_reflected_in_cpp_signature
    i32_type = Builder.primitive_type('i32')
    param = Builder.param('value', i32_type)
    body = Builder.literal(1, i32_type)

    func = Func.new(
      name: 'const_one',
      params: [param],
      ret_type: i32_type,
      body: body,
      effects: [:constexpr, :noexcept]
    )

    cpp_func = @lowerer.lower_function(func)

    assert_instance_of CppAst::Nodes::FunctionDeclaration, cpp_func
    source = cpp_func.to_source

    assert_includes source, 'constexpr'
    assert_includes source, 'noexcept'
    assert_match(/constexpr\s+int\s+const_one/, source)
  end
end
