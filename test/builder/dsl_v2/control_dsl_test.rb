#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class ControlDSLTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_if_statement_basic
    # Test basic if statement
    condition = id(:x) > int(0)
    then_block = id(:result).assign(int(1))
    
    if_stmt = if_(condition) { then_block }
    
    assert_not_nil if_stmt
    assert_equal condition.node, if_stmt.to_node.condition
    assert_equal then_block.node, if_stmt.to_node.then_statement
    assert_nil if_stmt.to_node.else_statement
  end

  def test_if_statement_with_else
    # Test if statement with else
    condition = id(:x) > int(0)
    then_block = id(:result).assign(int(1))
    else_block = id(:result).assign(int(-1))
    
    if_stmt = if_(condition) { then_block }.else_ { else_block }
    
    assert_not_nil if_stmt
    assert_equal condition.node, if_stmt.to_node.condition
    assert_equal then_block.node, if_stmt.to_node.then_statement
    assert_not_nil if_stmt.to_node.else_statement
  end

  def test_if_statement_with_elsif
    # Test if statement with elsif
    condition1 = id(:x) > int(0)
    condition2 = id(:x) < int(0)
    then_block1 = id(:result).assign(int(1))
    then_block2 = id(:result).assign(int(-1))
    else_block = id(:result).assign(int(0))
    
    if_stmt = if_(condition1) { then_block1 }
              .elsif(condition2) { then_block2 }
              .else_ { else_block }
    
    assert_not_nil if_stmt
    assert_equal condition1.node, if_stmt.to_node.condition
    assert_equal then_block1.node, if_stmt.to_node.then_statement
    assert_not_nil if_stmt.to_node.else_statement
  end

  def test_while_statement
    # Test while statement
    condition = id(:i) < int(10)
    body = id(:i).assign(id(:i) + int(1))
    
    while_stmt = while_(condition) { body }
    
    assert_not_nil while_stmt
    assert_equal condition.node, while_stmt.to_node.condition
    assert_equal body.node, while_stmt.to_node.body
  end

  def test_for_statement
    # Test for statement
    init = id(:i).assign(int(0))
    condition = id(:i) < int(10)
    increment = id(:i).assign(id(:i) + int(1))
    body = id(:sum).assign(id(:sum) + id(:i))
    
    for_stmt = for_(init, condition, increment) { body }
    
    assert_not_nil for_stmt
    assert_equal init.node, for_stmt.to_node.init
    assert_equal condition.node, for_stmt.to_node.condition
    assert_equal increment.node, for_stmt.to_node.increment
    assert_equal body.node, for_stmt.to_node.body
  end

  def test_range_for_statement
    # Test range-based for statement
    var = id(:it)
    range = id(:container)
    body = id(:sum).assign(id(:sum) + deref(id(:it)))
    
    range_for_stmt = for_range(:it, range) { body }
    
    assert_not_nil range_for_stmt
    assert_equal var.node, range_for_stmt.to_node.variable
    assert_equal range.node, range_for_stmt.to_node.range
    assert_equal body.node, range_for_stmt.to_node.body
  end

  def test_switch_statement
    # Test switch statement
    expression = id(:value)
    case1 = case_(int(1)) { id(:result).assign(string("one")) }
    case2 = case_(int(2)) { id(:result).assign(string("two")) }
    default_case = default_ { id(:result).assign(string("unknown")) }
    
    switch_stmt = switch_(expression) { [case1, case2, default_case] }
    
    assert_not_nil switch_stmt
    assert_equal expression.node, switch_stmt.to_node.expression
    assert_equal 3, switch_stmt.to_node.cases.size
  end

  def test_case_clause
    # Test case clause
    value = int(1)
    body = id(:result).assign(string("one"))
    
    case_clause = case_(value) { body }
    
    assert_not_nil case_clause
    assert_equal value.node, case_clause.to_node.value
    assert_equal body.node, case_clause.to_node.body
  end

  def test_default_clause
    # Test default clause
    body = id(:result).assign(string("unknown"))
    
    default_clause = default_ { body }
    
    assert_not_nil default_clause
    assert_equal body.node, default_clause.to_node.body
  end

  def test_break_statement
    # Test break statement
    break_stmt = break_
    
    assert_not_nil break_stmt
    assert_kind_of CppAst::Nodes::BreakStatement, break_stmt
  end

  def test_continue_statement
    # Test continue statement
    continue_stmt = continue_
    
    assert_not_nil continue_stmt
    assert_kind_of CppAst::Nodes::ContinueStatement, continue_stmt
  end

  def test_return_statement_with_expression
    # Test return statement with expression
    expression = id(:result) + int(1)
    return_stmt = ret(expression)
    
    assert_not_nil return_stmt
    assert_equal expression.node, return_stmt.expression
  end

  def test_return_statement_without_expression
    # Test return statement without expression
    return_stmt = ret
    
    assert_not_nil return_stmt
    assert_nil return_stmt.expression
  end

  def test_throw_statement
    # Test throw statement
    expression = string("Error occurred")
    throw_stmt = throw_(expression)
    
    assert_not_nil throw_stmt
    assert_equal expression.node, throw_stmt.expression
  end

  def test_try_catch_statement
    # Test try-catch statement
    try_body = id(:result).assign(id(:x) / id(:y))
    catch_type = t.string
    catch_var = id(:error)
    catch_body = id(:result).assign(string("Division by zero"))
    
    try_stmt = try_ { try_body }
    try_stmt.catch(catch_type, catch_var) { catch_body }
    
    assert_not_nil try_stmt
    assert_equal try_body.node, try_stmt.to_node.body
    assert_equal 1, try_stmt.to_node.catch_clauses.size
  end

  def test_catch_clause
    # Test catch clause
    type = t.string
    var = id(:error)
    body = id(:result).assign(string("Error handled"))
    
    catch_clause = catch_(type, var) { body }
    
    assert_not_nil catch_clause
    assert_equal "std::string", catch_clause.to_node.type
    assert_equal var.node, catch_clause.to_node.variable
    assert_equal body.node, catch_clause.to_node.body
  end

  def test_nested_control_flow
    # Test nested control flow
    outer_condition = id(:x) > int(0)
    inner_condition = id(:y) > int(0)
    inner_body = id(:result).assign(int(1))
    outer_body = if_(inner_condition) { inner_body }
    
    nested_if = if_(outer_condition) { outer_body }
    
    assert_not_nil nested_if
    assert_equal outer_condition.node, nested_if.to_node.condition
    assert_not_nil nested_if.to_node.then_statement
  end

  def test_control_flow_with_expressions
    # Test control flow with complex expressions
    condition = (id(:x) + id(:y)) > int(0)
    then_expr = (id(:x) * id(:y)).call(:sqrt)
    else_expr = int(0)
    
    if_stmt = if_(condition) { then_expr }.else_ { else_expr }
    
    assert_not_nil if_stmt
    assert_equal condition.node, if_stmt.to_node.condition
    assert_equal then_expr.node, if_stmt.to_node.then_statement
    assert_equal else_expr.node, if_stmt.to_node.else_statement
  end

  def test_loop_with_break_continue
    # Test loop with break and continue
    condition = id(:i) < int(10)
    body_with_continue = if_(id(:i) % int(2) == int(0)) { continue_ }
    body_with_break = if_(id(:i) > int(5)) { break_ }
    
    # This would need to be implemented as a block statement
    # For now, just test individual components
    assert_not_nil condition
    assert_not_nil body_with_continue
    assert_not_nil body_with_break
  end

  def test_switch_with_multiple_cases
    # Test switch with multiple cases
    expression = id(:value)
    case1 = case_(int(1)) { id(:result).assign(string("one")) }
    case2 = case_(int(2)) { id(:result).assign(string("two")) }
    case3 = case_(int(3)) { id(:result).assign(string("three")) }
    default_case = default_ { id(:result).assign(string("unknown")) }
    
    switch_stmt = switch_(expression) { [case1, case2, case3, default_case] }
    
    assert_not_nil switch_stmt
    assert_equal 4, switch_stmt.to_node.cases.size
  end

  def test_try_catch_with_multiple_catches
    # Test try-catch with multiple catch clauses
    try_body = id(:result).assign(id(:x) / id(:y))
    catch1_type = t.string
    catch1_var = id(:error)
    catch1_body = id(:result).assign(string("String error"))
    
    catch2_type = t.i32
    catch2_var = id(:code)
    catch2_body = id(:result).assign(string("Numeric error"))
    
    try_stmt = try_ { try_body }
    try_stmt.catch(catch1_type, catch1_var) { catch1_body }
    try_stmt.catch(catch2_type, catch2_var) { catch2_body }
    
    assert_not_nil try_stmt
    assert_equal 2, try_stmt.to_node.catch_clauses.size
  end

  def test_control_flow_builder_methods
    # Test that control flow methods return appropriate builders
    condition = id(:x) > int(0)
    
    if_builder = if_(condition)
    assert_kind_of CppAst::Builder::ControlDSL::IfStatementBuilder, if_builder
    
    while_builder = while_(condition)
    assert_kind_of CppAst::Builder::ControlDSL::WhileStatementBuilder, while_builder
    
    for_builder = for_(id(:i).assign(int(0)), condition, id(:i).increment)
    assert_kind_of CppAst::Builder::ControlDSL::ForStatementBuilder, for_builder
  end

  def test_control_flow_node_conversion
    # Test conversion to AST nodes
    condition = id(:x) > int(0)
    body = id(:result).assign(int(1))
    
    if_stmt = if_(condition) { body }
    node = if_stmt.to_node
    
    assert_kind_of CppAst::Nodes::IfStatement, node
    assert_equal condition.node, node.condition
    assert_equal body.node, node.then_statement
  end
end
