# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"
require_relative "../../lib/aurora/backend/block_complexity_analyzer"

class BlockComplexityAnalyzerTest < Minitest::Test
  def test_trivial_block_no_statements
    # Block with no statements, only result
    block = Aurora::CoreIR::BlockExpr.new(
      statements: [],
      result: Aurora::CoreIR::LiteralExpr.new(value: 42, type: int_type),
      type: int_type
    )

    analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(block)

    assert analyzer.trivial?
    assert analyzer.simple?
    refute analyzer.complex?
    refute analyzer.has_control_flow
    assert_equal 0, analyzer.statement_count
  end

  def test_simple_block_with_let_statements
    # Block with 2 let statements and simple result
    let1 = Aurora::CoreIR::VariableDeclStmt.new(
      name: "x",
      type: int_type,
      value: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      mutable: false
    )

    let2 = Aurora::CoreIR::VariableDeclStmt.new(
      name: "y",
      type: int_type,
      value: Aurora::CoreIR::LiteralExpr.new(value: 2, type: int_type),
      mutable: false
    )

    result = Aurora::CoreIR::BinaryExpr.new(
      op: "+",
      left: Aurora::CoreIR::VarExpr.new(name: "x", type: int_type),
      right: Aurora::CoreIR::VarExpr.new(name: "y", type: int_type),
      type: int_type
    )

    block = Aurora::CoreIR::BlockExpr.new(
      statements: [let1, let2],
      result: result,
      type: int_type
    )

    analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(block)

    assert analyzer.simple?
    refute analyzer.complex?
    refute analyzer.has_control_flow
    assert_equal 2, analyzer.statement_count
  end

  def test_complex_block_with_if_expr
    # Block with if expression in result
    let_stmt = Aurora::CoreIR::VariableDeclStmt.new(
      name: "x",
      type: int_type,
      value: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      mutable: false
    )

    if_expr = Aurora::CoreIR::IfExpr.new(
      condition: Aurora::CoreIR::VarExpr.new(name: "x", type: bool_type),
      then_branch: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      else_branch: Aurora::CoreIR::LiteralExpr.new(value: 2, type: int_type),
      type: int_type
    )

    block = Aurora::CoreIR::BlockExpr.new(
      statements: [let_stmt],
      result: if_expr,
      type: int_type
    )

    analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(block)

    refute analyzer.simple?
    assert analyzer.complex?
    assert analyzer.has_control_flow
    assert analyzer.has_nested_constructs?
  end

  def test_complex_block_too_many_statements
    # Block with 4 statements (exceeds threshold of 3)
    statements = (1..4).map do |i|
      Aurora::CoreIR::VariableDeclStmt.new(
        name: "x#{i}",
        type: int_type,
        value: Aurora::CoreIR::LiteralExpr.new(value: i, type: int_type),
        mutable: false
      )
    end

    block = Aurora::CoreIR::BlockExpr.new(
      statements: statements,
      result: Aurora::CoreIR::VarExpr.new(name: "x1", type: int_type),
      type: int_type
    )

    analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(block)

    refute analyzer.simple?
    assert analyzer.complex?
    assert_equal 4, analyzer.statement_count
  end

  def test_complexity_score_calculation
    # Simple block
    simple_block = Aurora::CoreIR::BlockExpr.new(
      statements: [],
      result: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      type: int_type
    )
    simple_analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(simple_block)

    # Complex block with control flow
    if_expr = Aurora::CoreIR::IfExpr.new(
      condition: Aurora::CoreIR::VarExpr.new(name: "x", type: bool_type),
      then_branch: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      else_branch: Aurora::CoreIR::LiteralExpr.new(value: 2, type: int_type),
      type: int_type
    )
    complex_block = Aurora::CoreIR::BlockExpr.new(
      statements: [
        Aurora::CoreIR::VariableDeclStmt.new(
          name: "x",
          type: int_type,
          value: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
          mutable: false
        )
      ],
      result: if_expr,
      type: int_type
    )
    complex_analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(complex_block)

    # Complex should have higher score
    assert simple_analyzer.complexity_score < complex_analyzer.complexity_score
    assert_operator complex_analyzer.complexity_score, :>=, 5
  end

  private

  def int_type
    @int_type ||= Aurora::CoreIR::Type.new(kind: :prim, name: "i32")
  end

  def bool_type
    @bool_type ||= Aurora::CoreIR::Type.new(kind: :prim, name: "bool")
  end
end

class IfComplexityAnalyzerTest < Minitest::Test
  def test_simple_ternary_candidate
    # if x { 1 } else { 2 }
    if_expr = Aurora::CoreIR::IfExpr.new(
      condition: Aurora::CoreIR::VarExpr.new(name: "x", type: bool_type),
      then_branch: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      else_branch: Aurora::CoreIR::LiteralExpr.new(value: 2, type: int_type),
      type: int_type
    )

    analyzer = Aurora::Backend::IfComplexityAnalyzer.new(if_expr)

    assert analyzer.simple_ternary_candidate?
    assert analyzer.same_types?
  end

  def test_complex_if_with_nested_control_flow
    # if x { if y { 1 } else { 2 } } else { 3 }
    nested_if = Aurora::CoreIR::IfExpr.new(
      condition: Aurora::CoreIR::VarExpr.new(name: "y", type: bool_type),
      then_branch: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type),
      else_branch: Aurora::CoreIR::LiteralExpr.new(value: 2, type: int_type),
      type: int_type
    )

    if_expr = Aurora::CoreIR::IfExpr.new(
      condition: Aurora::CoreIR::VarExpr.new(name: "x", type: bool_type),
      then_branch: nested_if,
      else_branch: Aurora::CoreIR::LiteralExpr.new(value: 3, type: int_type),
      type: int_type
    )

    analyzer = Aurora::Backend::IfComplexityAnalyzer.new(if_expr)

    refute analyzer.simple_ternary_candidate?
  end

  private

  def int_type
    @int_type ||= Aurora::CoreIR::Type.new(kind: :prim, name: "i32")
  end

  def bool_type
    @bool_type ||= Aurora::CoreIR::Type.new(kind: :prim, name: "bool")
  end
end

class MatchComplexityAnalyzerTest < Minitest::Test
  def test_simple_adt_match
    # match option { Some(x) => x, None => 0 }
    match_expr = Aurora::CoreIR::MatchExpr.new(
      scrutinee: Aurora::CoreIR::VarExpr.new(name: "option", type: option_type),
      arms: [
        {
          pattern: { kind: :constructor, name: "Some", bindings: ["x"] },
          body: Aurora::CoreIR::VarExpr.new(name: "x", type: int_type)
        },
        {
          pattern: { kind: :constructor, name: "None", bindings: [] },
          body: Aurora::CoreIR::LiteralExpr.new(value: 0, type: int_type)
        }
      ],
      type: int_type
    )

    analyzer = Aurora::Backend::MatchComplexityAnalyzer.new(match_expr)

    assert_equal 2, analyzer.arm_count
    refute analyzer.has_regex?
    assert analyzer.pure_adt_match?
    refute analyzer.needs_named_visitor?
  end

  def test_match_with_regex_patterns
    # match text { /\d+/ => 1, _ => 0 }
    match_expr = Aurora::CoreIR::MatchExpr.new(
      scrutinee: Aurora::CoreIR::VarExpr.new(name: "text", type: string_type),
      arms: [
        {
          pattern: { kind: :regex, pattern: "\\d+", flags: "" },
          body: Aurora::CoreIR::LiteralExpr.new(value: 1, type: int_type)
        },
        {
          pattern: { kind: :wildcard },
          body: Aurora::CoreIR::LiteralExpr.new(value: 0, type: int_type)
        }
      ],
      type: int_type
    )

    analyzer = Aurora::Backend::MatchComplexityAnalyzer.new(match_expr)

    assert analyzer.has_regex?
    refute analyzer.pure_adt_match?
  end

  def test_large_match_needs_named_visitor
    # Match with 10 arms
    arms = (1..10).map do |i|
      {
        pattern: { kind: :constructor, name: "Case#{i}", bindings: [] },
        body: Aurora::CoreIR::LiteralExpr.new(value: i, type: int_type)
      }
    end

    match_expr = Aurora::CoreIR::MatchExpr.new(
      scrutinee: Aurora::CoreIR::VarExpr.new(name: "value", type: sum_type),
      arms: arms,
      type: int_type
    )

    analyzer = Aurora::Backend::MatchComplexityAnalyzer.new(match_expr)

    assert_equal 10, analyzer.arm_count
    assert analyzer.pure_adt_match?
    assert analyzer.needs_named_visitor?(5)  # threshold = 5
  end

  private

  def int_type
    @int_type ||= Aurora::CoreIR::Type.new(kind: :prim, name: "i32")
  end

  def string_type
    @string_type ||= Aurora::CoreIR::Type.new(kind: :prim, name: "string")
  end

  def option_type
    @option_type ||= Aurora::CoreIR::SumType.new(
      name: "Option",
      variants: [
        { name: "Some", fields: [] },
        { name: "None", fields: [] }
      ]
    )
  end

  def sum_type
    @sum_type ||= Aurora::CoreIR::SumType.new(
      name: "BigSum",
      variants: (1..10).map { |i| { name: "Case#{i}", fields: [] } }
    )
  end
end
