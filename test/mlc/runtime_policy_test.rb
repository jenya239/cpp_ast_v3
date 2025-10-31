# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc/backend/runtime_policy"

class RuntimePolicyTest < Minitest::Test
  def test_default_policy
    policy = MLC::Backend::RuntimePolicy.new

    assert_equal :iife, policy.block_expr_simple_strategy
    assert_equal :iife, policy.block_expr_complex_strategy
    assert_equal :ternary, policy.if_join_strategy
    assert_equal 5, policy.match_threshold
    assert_equal :lambda, policy.loop_capture_strategy
    assert_equal false, policy.use_gcc_extensions
    assert_equal :expected, policy.error_model
    assert_equal true, policy.always_use_runtime
  end

  def test_optimized_policy
    policy = MLC::Backend::RuntimePolicy.optimized

    assert_equal :scope_tmp, policy.block_expr_simple_strategy
    assert_equal :iife, policy.block_expr_complex_strategy
    assert_equal false, policy.use_gcc_extensions
  end

  def test_gcc_optimized_policy
    policy = MLC::Backend::RuntimePolicy.gcc_optimized

    assert_equal :gcc_expr, policy.block_expr_simple_strategy
    assert_equal true, policy.use_gcc_extensions
  end

  def test_conservative_policy
    policy = MLC::Backend::RuntimePolicy.conservative

    # Conservative uses defaults (IIFE everywhere)
    assert_equal :iife, policy.block_expr_simple_strategy
    assert_equal :iife, policy.block_expr_complex_strategy
  end

  def test_policy_with_overrides
    policy = MLC::Backend::RuntimePolicy.new
    modified = policy.with(
      block_expr_simple_strategy: :scope_tmp,
      match_threshold: 10
    )

    # Original unchanged
    assert_equal :iife, policy.block_expr_simple_strategy
    assert_equal 5, policy.match_threshold

    # Modified version
    assert_equal :scope_tmp, modified.block_expr_simple_strategy
    assert_equal 10, modified.match_threshold
  end

  def test_block_strategies_constant
    strategies = MLC::Backend::RuntimePolicy::BLOCK_STRATEGIES

    assert_includes strategies, :iife
    assert_includes strategies, :scope_tmp
    assert_includes strategies, :gcc_expr
    assert_includes strategies, :inline
  end

  def test_if_strategies_constant
    strategies = MLC::Backend::RuntimePolicy::IF_STRATEGIES

    assert_includes strategies, :ternary
    assert_includes strategies, :variant_tmp
    assert_includes strategies, :inline_if
  end

  def test_match_strategies_constant
    strategies = MLC::Backend::RuntimePolicy::MATCH_STRATEGIES

    assert_includes strategies, :std_visit
    assert_includes strategies, :iife
    assert_includes strategies, :named_visitor
  end

  def test_policy_modification
    policy = MLC::Backend::RuntimePolicy.new

    policy.block_expr_simple_strategy = :scope_tmp
    policy.match_threshold = 10
    policy.use_gcc_extensions = true

    assert_equal :scope_tmp, policy.block_expr_simple_strategy
    assert_equal 10, policy.match_threshold
    assert_equal true, policy.use_gcc_extensions
  end
end
