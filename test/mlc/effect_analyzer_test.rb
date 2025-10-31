# frozen_string_literal: true

require_relative "../test_helper"

class EffectAnalyzerTest < Minitest::Test
  def test_pure_expression_marks_constexpr
    analyzer = MLC::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { true },
      non_literal_type: ->(_type) { false }
    )

    effects = analyzer.analyze(Object.new)

    assert_equal [:constexpr, :noexcept], effects
  end

  def test_nil_body_returns_default_effects
    analyzer = MLC::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { false },
      non_literal_type: ->(_type) { false }
    )

    effects = analyzer.analyze(nil)

    assert_equal [:noexcept], effects
  end

  def test_impure_expression_skips_constexpr
    analyzer = MLC::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { false },
      non_literal_type: ->(_type) { false }
    )

    effects = analyzer.analyze(Object.new)

    assert_equal [:noexcept], effects
  end

  def test_non_literal_return_type_skips_constexpr
    analyzer = MLC::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { true },
      non_literal_type: ->(_type) { true }
    )

    mock_type = Object.new
    effects = analyzer.analyze(Object.new, return_type: mock_type)

    assert_equal [:noexcept], effects
  end

  def test_pure_with_literal_type_marks_constexpr
    analyzer = MLC::TypeSystem::EffectAnalyzer.new(
      pure_expression: ->(_expr) { true },
      non_literal_type: ->(_type) { false }
    )

    mock_type = Object.new
    effects = analyzer.analyze(Object.new, return_type: mock_type)

    assert_equal [:constexpr, :noexcept], effects
  end
end
