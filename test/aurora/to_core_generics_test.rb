# frozen_string_literal: true

require_relative '../test_helper'

class ToCoreGenericsTest < Minitest::Test
  def test_simple_generic_function
    source = <<~AURORA
      export fn identity<T>(x: T) -> T = x
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    func = core_ir.items.first
    assert_equal 'identity', func.name
    assert_equal 1, func.type_params.size
    assert_equal 'T', func.type_params.first.name

    # Parameter type should be TypeVariable
    assert func.params.first.type.type_variable?
    assert_equal 'T', func.params.first.type.name

    # Return type should be TypeVariable
    assert func.ret_type.type_variable?
    assert_equal 'T', func.ret_type.name
  end

  def test_generic_function_multiple_type_params
    source = <<~AURORA
      export fn map<T, U>(x: T, f: fn(T) -> U) -> U = f(x)
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    func = core_ir.items.first
    assert_equal 2, func.type_params.size
    assert_equal 'T', func.type_params[0].name
    assert_equal 'U', func.type_params[1].name

    # First param is type variable T
    assert func.params[0].type.type_variable?
    assert_equal 'T', func.params[0].type.name

    # Second param is function type fn(T) -> U
    assert func.params[1].type.function?
    assert func.params[1].type.params.first[:type].type_variable?
    assert_equal 'T', func.params[1].type.params.first[:type].name
    assert func.params[1].type.ret_type.type_variable?
    assert_equal 'U', func.params[1].type.ret_type.name

    # Return type is U
    assert func.ret_type.type_variable?
    assert_equal 'U', func.ret_type.name
  end

  def test_generic_type_declaration
    source = <<~AURORA
      export type Option<T> = Some(T) | None
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    type_decl = core_ir.items.first
    assert_equal 'Option', type_decl.name
    assert_equal 1, type_decl.type_params.size
    assert_equal 'T', type_decl.type_params.first.name

    # Type should be SumType
    sum_type = type_decl.type
    assert_equal :sum, sum_type.kind
    assert_equal 2, sum_type.variants.size

    # Some variant should have TypeVariable field
    some_variant = sum_type.variants.find { |v| v[:name] == 'Some' }
    refute_nil some_variant
    assert_equal 1, some_variant[:fields].size
    assert some_variant[:fields].first[:type].type_variable?
    assert_equal 'T', some_variant[:fields].first[:type].name

    # None variant should have no fields
    none_variant = sum_type.variants.find { |v| v[:name] == 'None' }
    refute_nil none_variant
    assert_empty none_variant[:fields]
  end

  def test_generic_type_with_multiple_params
    source = <<~AURORA
      export type Result<T, E> = Ok(T) | Err(E)
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    type_decl = core_ir.items.first
    assert_equal 'Result', type_decl.name
    assert_equal 2, type_decl.type_params.size
    assert_equal 'T', type_decl.type_params[0].name
    assert_equal 'E', type_decl.type_params[1].name

    sum_type = type_decl.type
    ok_variant = sum_type.variants.find { |v| v[:name] == 'Ok' }
    err_variant = sum_type.variants.find { |v| v[:name] == 'Err' }

    # Ok has T field
    assert ok_variant[:fields].first[:type].type_variable?
    assert_equal 'T', ok_variant[:fields].first[:type].name

    # Err has E field
    assert err_variant[:fields].first[:type].type_variable?
    assert_equal 'E', err_variant[:fields].first[:type].name
  end

  def test_function_type_parameter
    source = <<~AURORA
      export fn apply<T, U>(f: fn(T) -> U, x: T) -> U = f(x)
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    func = core_ir.items.first

    # First parameter is function type
    fn_param = func.params[0]
    assert fn_param.type.function?
    assert_equal 1, fn_param.type.params.size

    # Function param type is T
    assert fn_param.type.params.first[:type].type_variable?
    assert_equal 'T', fn_param.type.params.first[:type].name

    # Function return type is U
    assert fn_param.type.ret_type.type_variable?
    assert_equal 'U', fn_param.type.ret_type.name
  end

  def test_array_of_type_variable
    source = <<~AURORA
      export fn length<T>(arr: T[]) -> i32 = 0
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    func = core_ir.items.first

    # Parameter type should be array
    assert func.params.first.type.array?

    # Array element type should be type variable T
    assert func.params.first.type.element_type.type_variable?
    assert_equal 'T', func.params.first.type.element_type.name
  end

  def test_extern_generic_function
    source = <<~AURORA
      export extern fn length<T>(arr: T[]) -> i32
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    func = core_ir.items.first
    assert_equal 'length', func.name
    assert func.external
    assert_equal 1, func.type_params.size
    assert_equal 'T', func.type_params.first.name

    # Should have no body
    assert_nil func.body
  end

  def test_nested_generic_array_function
    source = <<~AURORA
      export fn first<T>(arr: T[]) -> T = arr[0]
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    func = core_ir.items.first

    # Parameter is T[]
    assert func.params.first.type.array?
    assert func.params.first.type.element_type.type_variable?

    # Return type is T
    assert func.ret_type.type_variable?
    assert_equal 'T', func.ret_type.name
  end

  def test_generic_with_instantiated_type
    # Test that Option<T> is parsed and transformed correctly
    source = <<~AURORA
      export type Option<T> = Some(T) | None
      export fn unwrap<T>(opt: Option<T>, default: T) -> T = default
    AURORA

    ast = Aurora.parse(source)
    core_ir, _ = Aurora.transform_to_core_with_registry(ast)

    # Second item is the unwrap function
    func = core_ir.items[1]
    assert_equal 'unwrap', func.name
    assert_equal 1, func.type_params.size
    assert_equal 'T', func.type_params.first.name

    # First param: Option<T>
    opt_param = func.params[0]
    # Option<T> should be GenericType with type arg TypeVariable(T)
    assert opt_param.type.generic?
    assert_equal 'Option', opt_param.type.name
    assert_equal 1, opt_param.type.type_args.size
    assert opt_param.type.type_args.first.type_variable?
    assert_equal 'T', opt_param.type.type_args.first.name

    # Second param: T (type variable)
    default_param = func.params[1]
    assert default_param.type.type_variable?
    assert_equal 'T', default_param.type.name

    # Return type: T
    assert func.ret_type.type_variable?
    assert_equal 'T', func.ret_type.name
  end
end
