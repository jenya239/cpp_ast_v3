# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraBlockExprTest < Minitest::Test
  def test_block_expr_creation
    # Test creating BlockExpr with statements and result_expr
    stmt1 = Aurora::AST::VariableDecl.new(
      name: "x",
      value: Aurora::AST::IntLit.new(value: 1),
      mutable: false
    )

    stmt2 = Aurora::AST::VariableDecl.new(
      name: "y",
      value: Aurora::AST::IntLit.new(value: 2),
      mutable: false
    )

    result = Aurora::AST::BinaryOp.new(
      op: "+",
      left: Aurora::AST::VarRef.new(name: "x"),
      right: Aurora::AST::VarRef.new(name: "y")
    )

    block = Aurora::AST::BlockExpr.new(
      statements: [stmt1, stmt2],
      result_expr: result
    )

    assert_equal 2, block.statements.length
    assert_instance_of Aurora::AST::VariableDecl, block.statements[0]
    assert_instance_of Aurora::AST::VariableDecl, block.statements[1]
    assert_instance_of Aurora::AST::BinaryOp, block.result_expr
    assert_equal :block_expr, block.kind
  end

  def test_block_expr_with_mutable_variables
    # Test BlockExpr with mutable variable and assignment
    var_decl = Aurora::AST::VariableDecl.new(
      name: "x",
      value: Aurora::AST::IntLit.new(value: 0),
      mutable: true
    )

    assignment = Aurora::AST::Assignment.new(
      target: Aurora::AST::VarRef.new(name: "x"),
      value: Aurora::AST::BinaryOp.new(
        op: "+",
        left: Aurora::AST::VarRef.new(name: "x"),
        right: Aurora::AST::IntLit.new(value: 1)
      )
    )

    result = Aurora::AST::VarRef.new(name: "x")

    block = Aurora::AST::BlockExpr.new(
      statements: [var_decl, assignment],
      result_expr: result
    )

    assert_equal 2, block.statements.length
    assert_instance_of Aurora::AST::VariableDecl, block.statements[0]
    assert block.statements[0].mutable
    assert_instance_of Aurora::AST::Assignment, block.statements[1]
    assert_instance_of Aurora::AST::VarRef, block.result_expr
  end

  def test_block_expr_with_expr_statements
    # Test BlockExpr with expression statements
    call_expr = Aurora::AST::Call.new(
      callee: Aurora::AST::VarRef.new(name: "println"),
      args: [Aurora::AST::StringLit.new(value: "Hello")]
    )

    expr_stmt = Aurora::AST::ExprStmt.new(expr: call_expr)

    result = Aurora::AST::IntLit.new(value: 0)

    block = Aurora::AST::BlockExpr.new(
      statements: [expr_stmt],
      result_expr: result
    )

    assert_equal 1, block.statements.length
    assert_instance_of Aurora::AST::ExprStmt, block.statements[0]
    assert_instance_of Aurora::AST::IntLit, block.result_expr
  end

  def test_block_expr_empty_statements
    # Test BlockExpr with no statements, only result
    result = Aurora::AST::IntLit.new(value: 42)

    block = Aurora::AST::BlockExpr.new(
      statements: [],
      result_expr: result
    )

    assert_equal 0, block.statements.length
    assert_instance_of Aurora::AST::IntLit, block.result_expr
    assert_equal 42, block.result_expr.value
  end

  def test_block_expr_nested_blocks
    # Test nested BlockExpr
    inner_block = Aurora::AST::BlockExpr.new(
      statements: [
        Aurora::AST::VariableDecl.new(
          name: "y",
          value: Aurora::AST::IntLit.new(value: 1),
          mutable: false
        )
      ],
      result_expr: Aurora::AST::BinaryOp.new(
        op: "+",
        left: Aurora::AST::VarRef.new(name: "y"),
        right: Aurora::AST::IntLit.new(value: 1)
      )
    )

    outer_block = Aurora::AST::BlockExpr.new(
      statements: [
        Aurora::AST::VariableDecl.new(
          name: "x",
          value: inner_block,
          mutable: false
        )
      ],
      result_expr: Aurora::AST::BinaryOp.new(
        op: "*",
        left: Aurora::AST::VarRef.new(name: "x"),
        right: Aurora::AST::IntLit.new(value: 2)
      )
    )

    assert_equal 1, outer_block.statements.length
    assert_instance_of Aurora::AST::VariableDecl, outer_block.statements[0]
    assert_instance_of Aurora::AST::BlockExpr, outer_block.statements[0].value
    assert_instance_of Aurora::AST::BinaryOp, outer_block.result_expr
  end

  def test_block_expr_origin_tracking
    # Test that origin information is preserved
    origin = Aurora::SourceOrigin.new(
      file: "test.aur",
      line: 10,
      column: 5
    )

    block = Aurora::AST::BlockExpr.new(
      statements: [],
      result_expr: Aurora::AST::IntLit.new(value: 0),
      origin: origin
    )

    assert_equal origin, block.origin
    assert_equal "test.aur", block.origin.file
    assert_equal 10, block.origin.line
    assert_equal 5, block.origin.column
  end
end
