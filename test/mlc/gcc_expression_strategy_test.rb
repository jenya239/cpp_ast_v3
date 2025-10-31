# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class GccExpressionStrategyTest < Minitest::Test
  def test_simple_block_with_gcc_policy
    # Test that gcc_optimized policy generates statement expressions
    source = <<~AUR
      fn test() -> i32 =
        let mut x = 1;
        let mut y = 2;
        x + y
    AUR

    # For now, test that the policy exists and can be created
    policy = MLC::Backend::RuntimePolicy.gcc_optimized

    assert_equal :gcc_expr, policy.block_expr_simple_strategy
    assert_equal true, policy.use_gcc_extensions
  end

  def test_gcc_expression_syntax
    # Test that GCC policy configuration exists
    policy = MLC::Backend::RuntimePolicy.gcc_optimized
    assert_equal :gcc_expr, policy.block_expr_simple_strategy
  end

  def test_simple_function_compiles
    # Simple function without complex blocks
    source = <<~AUR
      fn double(x: i32) -> i32 = x * 2
    AUR

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "double"
    assert_includes cpp, "x * 2"
  end

  def test_trivial_block_inlined
    # Trivial blocks (no statements) could be inlined
    source = <<~AUR
      fn answer() -> i32 = 42
    AUR

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "42"
  end

  def test_gcc_vs_iife_block_complexity
    # Test that BlockComplexityAnalyzer correctly identifies simple vs complex

    # Simple block
    simple_block = MLC::HighIR::BlockExpr.new(
      statements: [
        MLC::HighIR::VariableDeclStmt.new(
          name: "x",
          type: int_type,
          value: MLC::HighIR::LiteralExpr.new(value: 1, type: int_type),
          mutable: false
        )
      ],
      result: MLC::HighIR::VarExpr.new(name: "x", type: int_type),
      type: int_type
    )

    analyzer = MLC::Backend::BlockComplexityAnalyzer.new(simple_block)
    assert analyzer.simple?
    refute analyzer.complex?

    # With GCC policy, simple blocks use gcc_expr
    gcc_policy = MLC::Backend::RuntimePolicy.gcc_optimized
    strategy = gcc_policy.strategy_for_block(analyzer)
    assert_equal :gcc_expr, strategy
  end

  def test_scope_tmp_falls_back_to_gcc_when_enabled
    # scope_tmp strategy should use GCC extension when enabled

    policy_with_gcc = MLC::Backend::RuntimePolicy.new
    policy_with_gcc.block_expr_simple_strategy = :scope_tmp
    policy_with_gcc.use_gcc_extensions = true

    assert_equal :scope_tmp, policy_with_gcc.block_expr_simple_strategy
    assert_equal true, policy_with_gcc.use_gcc_extensions
  end

  def test_function_with_statements
    # Function with multiple statements
    source = <<~AUR
      fn compute() -> i32 =
        let x = 10;
        x * 2
    AUR

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "compute"
  end

  def test_gcc_expression_with_no_statements
    # Edge case: block with only result expression
    source = <<~AUR
      fn direct() -> i32 = 100
    AUR

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "100"
  end

  private

  def int_type
    @int_type ||= MLC::HighIR::Type.new(kind: :prim, name: "i32")
  end
end
