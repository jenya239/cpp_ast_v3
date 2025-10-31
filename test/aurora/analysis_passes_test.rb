# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora/analysis/base_pass"
require_relative "../../lib/aurora/analysis/effect_analysis_pass"
require_relative "../../lib/aurora/analysis/type_check_pass"
require_relative "../../lib/aurora/analysis/name_resolution_pass"

class AnalysisPassesTest < Minitest::Test
  def setup
    @source = <<~AURORA
      fn add(x: i32, y: i32) -> i32 = x + y
      fn main() -> i32 = add(2, 3)
    AURORA

    ast = Aurora.parse(@source)
    @core_ir, @type_registry = Aurora.transform_to_core_with_registry(ast)
  end

  def test_effect_analysis_pass
    analyzer = Aurora::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(body) { body.is_a?(Aurora::CoreIR::BinaryExpr) },
      non_literal_type: ->(type) { false }
    )

    pass = Aurora::Analysis::EffectAnalysisPass.new(effect_analyzer: analyzer)
    context = { core_ir: @core_ir }

    pass.run(context)

    assert context[:function_effects]
    assert context[:function_effects]["add"]
    assert context[:function_effects]["main"]
  end

  def test_type_check_pass
    pass = Aurora::Analysis::TypeCheckPass.new(type_registry: @type_registry)
    context = { core_ir: @core_ir }

    pass.run(context)

    assert context.key?(:type_errors)
    assert context.key?(:type_check_passed)
  end

  def test_name_resolution_pass
    pass = Aurora::Analysis::NameResolutionPass.new
    context = { core_ir: @core_ir }

    pass.run(context)

    assert context.key?(:symbol_table)
    assert context.key?(:resolution_errors)
    assert context.key?(:name_resolution_passed)

    # Should find both functions
    assert context[:symbol_table]["add"]
    assert context[:symbol_table]["main"]
  end

  def test_pass_integration_with_pass_manager
    analyzer = Aurora::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(body) { body.is_a?(Aurora::CoreIR::BinaryExpr) },
      non_literal_type: ->(type) { false }
    )

    manager = Aurora::PassManager.new
    manager.register(:name_resolution, Aurora::Analysis::NameResolutionPass.new.to_callable)
    manager.register(:type_check, Aurora::Analysis::TypeCheckPass.new(type_registry: @type_registry).to_callable)
    manager.register(:effect_analysis, Aurora::Analysis::EffectAnalysisPass.new(effect_analyzer: analyzer).to_callable)

    context = { core_ir: @core_ir }
    manager.run(context)

    # All passes should have run and populated context
    assert context[:symbol_table]
    assert context[:type_errors]
    assert context[:function_effects]
  end
end
