# frozen_string_literal: true

require_relative "../test_helper"

class EffectAnalyzerTest < Minitest::Test
  def test_pure_expression_marks_constexpr
    analyzer = Aurora::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { true }
    )

    effects = analyzer.analyze(Object.new)

    assert_equal [:constexpr, :noexcept], effects
  end

  def test_nil_body_returns_default_effects
    analyzer = Aurora::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { false }
    )

    effects = analyzer.analyze(nil)

    assert_equal [:noexcept], effects
  end

  def test_impure_expression_skips_constexpr
    analyzer = Aurora::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { false }
    )

    effects = analyzer.analyze(Object.new)

    assert_equal [:noexcept], effects
  end
end
