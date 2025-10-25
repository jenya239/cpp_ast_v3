# frozen_string_literal: true

require_relative '../test_helper'

class CoreIRGenericsTest < Minitest::Test
  include Aurora::CoreIR

  def test_type_variable_creation
    type_var = Builder.type_variable('T')

    assert_equal 'T', type_var.name
    assert_nil type_var.constraint
    assert type_var.type_variable?
    refute type_var.primitive?
    refute type_var.generic?
  end

  def test_type_variable_with_constraint
    constraint = Builder.primitive_type('Display')
    type_var = Builder.type_variable('T', constraint: constraint)

    assert_equal 'T', type_var.name
    assert_equal constraint, type_var.constraint
    assert type_var.type_variable?
  end

  def test_generic_type_creation
    # Create Option<i32>
    option_base = Builder.primitive_type('Option')
    i32_type = Builder.primitive_type('i32')

    option_i32 = Builder.generic_type(option_base, [i32_type])

    assert_equal 'Option', option_i32.name
    assert_equal option_base, option_i32.base_type
    assert_equal 1, option_i32.type_args.size
    assert_equal i32_type, option_i32.type_args.first
    assert option_i32.generic?
    refute option_i32.type_variable?
  end

  def test_generic_type_multiple_args
    # Create Result<String, Error>
    result_base = Builder.primitive_type('Result')
    string_type = Builder.primitive_type('String')
    error_type = Builder.primitive_type('Error')

    result_type = Builder.generic_type(result_base, [string_type, error_type])

    assert_equal 'Result', result_type.name
    assert_equal 2, result_type.type_args.size
    assert_equal string_type, result_type.type_args[0]
    assert_equal error_type, result_type.type_args[1]
    assert result_type.generic?
  end

  def test_nested_generic_types
    # Create Option<Result<i32, String>>
    option_base = Builder.primitive_type('Option')
    result_base = Builder.primitive_type('Result')
    i32_type = Builder.primitive_type('i32')
    string_type = Builder.primitive_type('String')

    result_i32_string = Builder.generic_type(result_base, [i32_type, string_type])
    option_result = Builder.generic_type(option_base, [result_i32_string])

    assert_equal 'Option', option_result.name
    assert_equal 1, option_result.type_args.size
    assert option_result.type_args.first.generic?
    assert_equal 'Result', option_result.type_args.first.name
  end

  def test_generic_type_with_type_variable
    # Create Option<T> where T is a type variable
    option_base = Builder.primitive_type('Option')
    t_var = Builder.type_variable('T')

    option_t = Builder.generic_type(option_base, [t_var])

    assert_equal 'Option', option_t.name
    assert_equal 1, option_t.type_args.size
    assert option_t.type_args.first.type_variable?
    assert_equal 'T', option_t.type_args.first.name
  end

  def test_array_type_creation
    i32_type = Builder.primitive_type('i32')
    array_type = Builder.array_type(i32_type)

    assert_equal 'array', array_type.name
    assert_equal i32_type, array_type.element_type
    assert array_type.array?
    refute array_type.generic?
  end

  def test_array_of_generic_type
    # Create i32[]
    # Then create Option<i32>[]
    option_base = Builder.primitive_type('Option')
    i32_type = Builder.primitive_type('i32')
    option_i32 = Builder.generic_type(option_base, [i32_type])

    array_of_options = Builder.array_type(option_i32)

    assert array_of_options.array?
    assert array_of_options.element_type.generic?
    assert_equal 'Option', array_of_options.element_type.name
  end

  def test_type_param_creation
    type_param = Builder.type_param('T')

    assert_equal 'T', type_param.name
    assert_nil type_param.constraint
  end

  def test_type_param_with_constraint
    type_param = Builder.type_param('T', constraint: 'Display')

    assert_equal 'T', type_param.name
    assert_equal 'Display', type_param.constraint
  end

  def test_function_with_type_params
    # fn identity<T>(x: T) -> T
    t_var = Builder.type_variable('T')
    param = Builder.param('x', t_var)
    type_param = Builder.type_param('T')
    body = Builder.unit_literal

    func = Func.new(
      name: 'identity',
      params: [param],
      ret_type: t_var,
      body: body,
      type_params: [type_param]
    )

    assert_equal 'identity', func.name
    assert_equal 1, func.type_params.size
    assert_equal 'T', func.type_params.first.name
    assert func.params.first.type.type_variable?
    assert func.ret_type.type_variable?
  end

  def test_function_type_with_generics
    # fn(T) -> U type where T and U are type variables
    t_var = Builder.type_variable('T')
    u_var = Builder.type_variable('U')

    fn_type = Builder.function_type([{name: 'x', type: t_var}], u_var)

    assert fn_type.function?
    assert_equal 1, fn_type.params.size
    assert fn_type.params.first[:type].type_variable?
    assert fn_type.ret_type.type_variable?
  end

  def test_type_declaration_with_generics
    # type Option<T> = Some(T) | None
    t_param = Builder.type_param('T')
    t_var = Builder.type_variable('T')

    # Sum type with variants
    variants = [
      {name: 'Some', fields: [{name: 'value', type: t_var}]},
      {name: 'None', fields: []}
    ]
    sum_type = Builder.sum_type('Option', variants)

    type_decl = TypeDecl.new(
      name: 'Option',
      type: sum_type,
      type_params: [t_param]
    )

    assert_equal 'Option', type_decl.name
    assert_equal 1, type_decl.type_params.size
    assert_equal 'T', type_decl.type_params.first.name
    assert_equal :sum, type_decl.type.kind
  end
end
