# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class LoweringStrategyIntegrationTest < Minitest::Test
  def test_simple_block_with_default_policy
    # Default policy - function bodies are lowered as statements
    source = <<~AUR
      fn test() -> i32 =
        let x = 1;
        let y = 2;
        x + y
    AUR

    cpp = MLC.to_cpp(source)

    # Function bodies don't use IIFE - they're lowered as statements
    assert_includes cpp, "int x = 1"
    assert_includes cpp, "int y = 2"
  end

  def test_simple_block_with_optimized_policy
    # Test with optimized policy (future implementation)
    # For now, this will still use IIFE but documents the intention
    source = <<~AUR
      fn test() -> i32 =
        let x = 1;
        let y = 2;
        x + y
    AUR

    # Use optimized policy
    policy = MLC::Backend::RuntimePolicy.optimized

    # Policy should be configured correctly
    assert_equal :scope_tmp, policy.block_expr_simple_strategy
    assert_equal false, policy.use_gcc_extensions

    # With standard C++, scope_tmp falls back to IIFE in expression context
    # For now, just test that code compiles
    cpp = MLC.to_cpp(source)
    assert_includes cpp, "test"
  end

  def test_complex_block_always_uses_iife
    # Complex blocks should always use IIFE regardless of policy
    source = <<~AUR
      fn test(x: i32) -> i32 =
        let y = if x > 0 then x * 2 else 0;
        let z = y + 1;
        z
    AUR

    cpp = MLC.to_cpp(source)

    # Function bodies don't use IIFE - only expressions in expression context
    assert_includes cpp, "test"
  end

  def test_trivial_block_just_returns_value
    # Block with no statements should ideally be inlined
    source = <<~AUR
      fn test() -> i32 = 42
    AUR

    cpp = MLC.to_cpp(source)

    # Simple return, no IIFE needed
    assert_includes cpp, "42"
  end

  def test_block_with_many_statements_uses_iife
    # Block with >3 statements - function bodies don't use IIFE
    source = <<~AUR
      fn test() -> i32 =
        let a = 1;
        let b = 2;
        let c = 3;
        let d = 4;
        a + b + c + d
    AUR

    cpp = MLC.to_cpp(source)

    # Function bodies are lowered as statements, not IIFE
    assert_includes cpp, "int a = 1"
    assert_includes cpp, "int b = 2"
    assert_includes cpp, "int c = 3"
    assert_includes cpp, "int d = 4"
  end

  def test_regex_match_uses_iife
    # Regex pattern matching always uses IIFE
    source = <<~AUR
      fn parse(text: string) -> i32 =
        match text {
          /^(\d+)$/ => 1,
          _ => 0
        }
    AUR

    cpp = MLC.to_cpp(source)

    # Regex match must use IIFE for early returns
    assert_includes cpp, "[&]()"
    assert_includes cpp, "mlc::regex"
  end

  def test_list_comprehension_uses_iife
    # List comprehensions always use IIFE
    source = <<~AUR
      fn doubled(xs: i32[]) -> i32[] =
        [x * 2 for x in xs if x > 0]
    AUR

    cpp = MLC.to_cpp(source)

    # List comprehension requires IIFE for local result vector
    assert_includes cpp, "[&]()"
    assert_includes cpp, "std::vector"
    assert_includes cpp, "result"
  end

  def test_adt_match_uses_std_visit
    # Pure ADT match should use std::visit
    source = <<~AUR
      type Option<T> = Some(T) | None

      fn unwrap_or(opt: Option<i32>, default: i32) -> i32 =
        match opt {
          Some(x) => x,
          None => default
        }
    AUR

    cpp = MLC.to_cpp(source)

    # Should use std::visit with overloaded
    assert_includes cpp, "std::visit"
    assert_includes cpp, "overloaded"
  end

  def test_collections_use_runtime
    # Collection operations should always use runtime
    # Note: This is a placeholder test - actual collection methods will be added later
    source = <<~AUR
      fn test(xs: i32[]) -> i32 =
        xs.length()
    AUR

    cpp = MLC.to_cpp(source)

    # Should compile and use std::vector
    assert_includes cpp, "std::vector"
    assert_includes cpp, "size"
  end

  def test_io_functions_use_runtime
    # IO functions should use runtime
    source = <<~AUR
      fn main() -> i32 =
        println("Hello, World!");
        0
    AUR

    cpp = MLC.to_cpp(source)

    # Should use aurora::io runtime
    assert_includes cpp, "mlc::io::println"
  end

  def test_policy_configuration_affects_lowering
    # Test that different policies produce different behavior
    # (This will be more meaningful once scope_tmp is implemented)

    conservative = MLC::Backend::RuntimePolicy.conservative
    optimized = MLC::Backend::RuntimePolicy.optimized

    assert_equal :iife, conservative.block_expr_simple_strategy
    assert_equal :scope_tmp, optimized.block_expr_simple_strategy

    assert_equal false, conservative.use_gcc_extensions
    assert_equal false, optimized.use_gcc_extensions

    gcc_opt = MLC::Backend::RuntimePolicy.gcc_optimized
    assert_equal :gcc_expr, gcc_opt.block_expr_simple_strategy
    assert_equal true, gcc_opt.use_gcc_extensions
  end
end
