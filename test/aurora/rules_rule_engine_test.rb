# frozen_string_literal: true

require_relative "../test_helper"

class RulesRuleEngineTest < Minitest::Test
  class CaptureRule < Aurora::Rules::BaseRule
    def initialize(bucket)
      @bucket = bucket
    end

    def applies?(node, _context = {})
      node.is_a?(Aurora::CoreIR::Func)
    end

    def apply(node, _context = {})
      @bucket << node.name
    end
  end

  def test_rule_engine_can_register_objects
    bucket = []
    engine = Aurora::Rules::RuleEngine.new
    engine.register(:stage, CaptureRule.new(bucket))

    engine.apply(:stage, :node)

    assert_equal [], bucket
  end

  def test_rule_engine_is_invoked_during_transform
    bucket = []
    engine = Aurora::Rules::RuleEngine.new
    engine.register(:core_ir_function, CaptureRule.new(bucket))

    source = <<~AURORA
      fn id(x: i32) -> i32 = x
    AURORA

    ast = Aurora.parse(source)
    transformer = Aurora::Passes::ToCore.new(rule_engine: engine)
    transformer.transform(ast)

    assert_includes bucket, "id"
  end

  def test_sum_constructor_rule_registers_variants
    engine = Aurora::Rules::RuleEngine.new
    engine.register(:core_ir_type_decl, Aurora::Rules::IRGen::SumConstructorRule.new)

    source = <<~AURORA
      type Option<T> = Some(T) | None
    AURORA

    ast = Aurora.parse(source)
    transformer = Aurora::Passes::ToCore.new(rule_engine: engine)
    transformer.transform(ast)

    info = transformer.send(:lookup_function_info, "Some")
    refute_nil info
    assert_equal "Option", transformer.type_registry.lookup("Option").name
  end

  def test_match_rule_builds_core_ir_match_expression
    engine = Aurora::Rules::RuleEngine.new
    engine.register(:core_ir_match_expr, Aurora::Rules::IRGen::MatchRule.new)

    source = <<~AURORA
      type Option<T> = Some(T) | None

      fn unwrap(opt: Option<i32>) -> i32 =
        match opt
          | Some(x) => x
          | None => 0
    AURORA

    ast = Aurora.parse(source)
    transformer = Aurora::Passes::ToCore.new(rule_engine: engine)
    core = transformer.transform(ast)
    func = core.items.find { |item| item.is_a?(Aurora::CoreIR::Func) && item.name == "unwrap" }

    assert_instance_of Aurora::CoreIR::MatchExpr, func.body
  end

  def test_function_effect_rule_sets_effects
    engine = Aurora::Rules::RuleEngine.new
    engine.register(:core_ir_function, Aurora::Rules::IRGen::FunctionEffectRule.new)

    source = <<~AURORA
      fn identity(x: i32) -> i32 = x
    AURORA

    ast = Aurora.parse(source)
    transformer = Aurora::Passes::ToCore.new(rule_engine: engine)
    core = transformer.transform(ast)
    func = core.items.find { |item| item.is_a?(Aurora::CoreIR::Func) && item.name == "identity" }

    assert_equal [:constexpr, :noexcept], func.effects
  end
end
