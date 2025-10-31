# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class RuntimePolicyApiTest < Minitest::Test
  def test_to_cpp_accepts_runtime_policy
    source = <<~AUR
      fn test() -> i32 = 42
    AUR

    # Should work with default policy
    cpp = MLC.to_cpp(source)
    assert_includes cpp, "test"
    assert_includes cpp, "42"

    # Should work with conservative policy
    cpp = MLC.to_cpp(source, runtime_policy: MLC::Backend::RuntimePolicy.conservative)
    assert_includes cpp, "test"
    assert_includes cpp, "42"

    # Should work with optimized policy
    cpp = MLC.to_cpp(source, runtime_policy: MLC::Backend::RuntimePolicy.optimized)
    assert_includes cpp, "test"
    assert_includes cpp, "42"

    # Should work with gcc_optimized policy
    cpp = MLC.to_cpp(source, runtime_policy: MLC::Backend::RuntimePolicy.gcc_optimized)
    assert_includes cpp, "test"
    assert_includes cpp, "42"
  end

  def test_compile_accepts_runtime_policy
    source = <<~AUR
      fn add(x: i32, y: i32) -> i32 = x + y
    AUR

    # Compile with custom policy
    policy = MLC::Backend::RuntimePolicy.gcc_optimized
    cpp_ast = MLC.compile(source, runtime_policy: policy)

    assert cpp_ast.is_a?(CppAst::Nodes::Program)
    cpp = cpp_ast.to_source
    assert_includes cpp, "add"
  end

  def test_to_hpp_cpp_accepts_runtime_policy
    source = <<~AUR
      fn factorial(n: i32) -> i32 =
        if n <= 1 then 1 else n * factorial(n - 1)
    AUR

    result = MLC.to_hpp_cpp(source, runtime_policy: MLC::Backend::RuntimePolicy.optimized)

    assert result.key?(:header)
    assert result.key?(:implementation)
    assert_includes result[:header], "factorial"
  end

  def test_lower_to_cpp_accepts_runtime_policy
    source = <<~AUR
      fn double(x: i32) -> i32 = x * 2
    AUR

    # Parse and transform
    ast = MLC.parse(source)
    core_ir, type_registry, function_registry = MLC.transform_to_core_with_registry(ast)

    # Lower with custom policy
    policy = MLC::Backend::RuntimePolicy.new
    policy.block_expr_simple_strategy = :gcc_expr
    policy.use_gcc_extensions = true

    cpp_ast = MLC.lower_to_cpp(core_ir, type_registry: type_registry, function_registry: function_registry, runtime_policy: policy)
    cpp = cpp_ast.to_source

    assert_includes cpp, "double"
  end

  def test_custom_policy_configuration
    # Test that we can create and configure a custom policy
    policy = MLC::Backend::RuntimePolicy.new

    # Configure to use GCC extensions
    policy.block_expr_simple_strategy = :gcc_expr
    policy.use_gcc_extensions = true
    policy.match_threshold = 10

    source = <<~AUR
      fn test() -> i32 = 100
    AUR

    cpp = MLC.to_cpp(source, runtime_policy: policy)

    assert_includes cpp, "test"
    assert_includes cpp, "100"
  end

  def test_nil_policy_uses_default
    source = <<~AUR
      fn test() -> i32 = 1 + 2
    AUR

    # Nil policy should work (uses default)
    cpp = MLC.to_cpp(source, runtime_policy: nil)

    assert_includes cpp, "test"
    assert_includes cpp, "1 + 2"
  end
end
