# frozen_string_literal: true

require_relative "../test_helper"

class TypeInferenceArchitectureTest < Minitest::Test
  def build_core_ir(source)
    passes = Aurora::Passes::ToCore.new
    ast = Aurora.parse(source)
    passes.transform(ast)
  end

  def find_function(core_ir, name)
    core_ir.items.find { |item| item.is_a?(Aurora::CoreIR::Func) && item.name == name }
  end

  def test_sum_constructor_instantiation_produces_generic_type
    source = <<~AURORA
      type Option<T> = Some(T) | None

      fn build() -> Option<i32> =
        Some(1)
    AURORA

    core = build_core_ir(source)
    func = find_function(core, "build")
    call = func.body

    assert_instance_of Aurora::CoreIR::GenericType, call.type
    assert_equal "Option", call.type.name
    assert_equal "i32", call.type.type_args.first.name
  end

  def test_generic_function_instantiation_resolves_return_type
    source = <<~AURORA
      type Option<T> = Some(T) | None

      fn unwrap<T>(opt: Option<T>, default: T) -> T =
        match opt
          | Some(x) => x
          | None => default

      fn use_unwrap() -> i32 =
        unwrap(Some(5), 0)
    AURORA

    core = build_core_ir(source)
    func = find_function(core, "use_unwrap")
    call = func.body

    assert_instance_of Aurora::CoreIR::Type, call.type
    assert_equal "i32", call.type.name
  end
end
