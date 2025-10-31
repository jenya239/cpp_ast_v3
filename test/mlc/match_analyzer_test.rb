# frozen_string_literal: true

require_relative "../test_helper"
require "ostruct"

class MatchAnalyzerTest < Minitest::Test
  Arm = Struct.new(:pattern, :guard, :body)

  def build_analyzer
    MLC::TypeSystem::MatchAnalyzer.new(
      ensure_compatible_type: ->(actual, expected, _context) do
        raise "type mismatch" unless actual == expected
      end
    )
  end

  def test_analyzer_returns_result_type
    analyzer = build_analyzer
    body_type = OpenStruct.new(type: "i32")
    arms = [
      { pattern: nil, guard: nil, body: OpenStruct.new(type: "i32") },
      { pattern: nil, guard: nil, body: OpenStruct.new(type: "i32") }
    ]

    analysis = analyzer.analyze(
      scrutinee_type: "Option<i32>",
      arms: arms,
      transform_arm: ->(_scrutinee, arm) { arm }
    )

    assert_equal "i32", analysis.result_type
    assert_equal arms, analysis.arms
  end

  def test_analyzer_persists_guards
    analyzer = build_analyzer
    guard = OpenStruct.new(type: "bool")
    arms = [
      { pattern: nil, guard: guard, body: OpenStruct.new(type: "i32") }
    ]

    analysis = analyzer.analyze(
      scrutinee_type: "Option<i32>",
      arms: arms,
      transform_arm: ->(_scrutinee, arm) { arm }
    )

    assert_equal guard, analysis.arms.first[:guard]
  end

  def test_analyzer_rejects_empty_match
    analyzer = build_analyzer

    assert_raises(ArgumentError) do
      analyzer.analyze(
        scrutinee_type: "Option<i32>",
        arms: [],
        transform_arm: ->(_scrutinee, arm) { arm }
      )
    end
  end

  def test_analyzer_propagates_type_mismatches
    ensure_calls = []
    analyzer = MLC::TypeSystem::MatchAnalyzer.new(
      ensure_compatible_type: lambda do |actual, expected, context|
        ensure_calls << [actual, expected, context]
        raise MLC::CompileError, "Mismatch" unless actual == expected
      end
    )
    arms = [
      { pattern: nil, guard: nil, body: OpenStruct.new(type: "i32") },
      { pattern: nil, guard: nil, body: OpenStruct.new(type: "string") }
    ]

    assert_raises(MLC::CompileError) do
      analyzer.analyze(
        scrutinee_type: "Option<i32>",
        arms: arms,
        transform_arm: ->(_scrutinee, arm) { arm }
      )
    end

    assert_equal 2, ensure_calls.length
    assert_equal "match arm 2", ensure_calls.last.last
  end
end
