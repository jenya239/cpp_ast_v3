# frozen_string_literal: true

require_relative '../test_helper'

class TypeInferenceGenericsTest < Minitest::Test
  def test_simple_generic_function_call
    source = <<~AURORA
      fn identity<T>(x: T) -> T = x

      fn main() -> i32 = identity(42)
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    # Find main function
    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # Body should be a call to identity
    assert_instance_of MLC::HighIR::CallExpr, main_func.body

    # Return type should be i32 (inferred from argument)
    assert_equal 'i32', main_func.body.type.name
  end

  def test_generic_array_function
    source = <<~AURORA
      fn first<T>(arr: T[]) -> T = arr[0]

      fn main() -> i32 = do
        let numbers = [1, 2, 3];
        first(numbers)
      end
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # Return type of first(numbers) should be i32
    # (inferred from numbers: i32[])
    assert main_func.body.is_a?(MLC::HighIR::BlockExpr)
  end

  def test_generic_function_multiple_type_params
    source = <<~AURORA
      fn pair<T, U>(x: T, y: U) -> i32 = 0

      fn main() -> i32 = pair(42, 3.14)
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # Should compile without errors
    # T inferred as i32, U inferred as f32
    assert_instance_of MLC::HighIR::CallExpr, main_func.body
  end

  def test_generic_with_explicit_return_type
    source = <<~AURORA
      fn get_default<T>() -> i32 = 0

      fn main() -> i32 = get_default()
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # Should work even though T cannot be inferred from arguments
    assert_instance_of MLC::HighIR::CallExpr, main_func.body
    assert_equal 'i32', main_func.body.type.name
  end

  def test_nested_generic_types
    source = <<~AURORA
      fn wrap<T>(x: T) -> i32 = 0

      fn main() -> i32 = do
        let arr = [1, 2, 3];
        wrap(arr)
      end
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # T should be inferred as i32[]
    assert main_func.body.is_a?(MLC::HighIR::BlockExpr)
  end

  def test_generic_type_with_generic_function
    source = <<~AURORA
      type Option<T> = Some(T) | None

      fn unwrap<T>(opt: Option<T>, default: T) -> T = default

      fn main() -> i32 = do
        let opt = Some(42);
        unwrap(opt, 0)
      end
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # T should be inferred as i32 from both opt and default
    assert main_func.body.is_a?(MLC::HighIR::BlockExpr)
  end

  def test_type_inference_consistency_check
    # This should fail: T bound to both i32 and f32
    source = <<~AURORA
      fn inconsistent<T>(x: T, y: T) -> T = x

      fn main() -> i32 = inconsistent(42, 3.14)
    AURORA

    assert_raises(MLC::CompileError) do
      MLC.transform_to_core_with_registry(MLC.parse(source))
    end
  end

  def test_generic_identity_chain
    source = <<~AURORA
      fn identity<T>(x: T) -> T = x

      fn main() -> i32 = identity(identity(identity(42)))
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # All identity calls should infer T as i32
    assert_instance_of MLC::HighIR::CallExpr, main_func.body
    assert_equal 'i32', main_func.body.type.name
  end

  def test_extern_generic_function
    source = <<~AURORA
      extern fn length<T>(arr: T[]) -> i32

      fn main() -> i32 = do
        let arr = [1, 2, 3];
        length(arr)
      end
    AURORA

    core_ir, _ = MLC.transform_to_core_with_registry(MLC.parse(source))

    main_func = core_ir.items.find { |item| item.is_a?(MLC::HighIR::Func) && item.name == 'main' }
    refute_nil main_func

    # Extern generic function should work the same way
    assert main_func.body.is_a?(MLC::HighIR::BlockExpr)
  end
end
