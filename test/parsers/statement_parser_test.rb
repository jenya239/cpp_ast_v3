# frozen_string_literal: true

require_relative "../test_helper"

class TestStatementParser < Minitest::Test
  def parse_statement(source, leading_trivia = "")
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::StatementParser.new(lexer)
    stmt, trailing = parser.parse_statement(leading_trivia)
    [stmt, trailing]
  end
  
  # ExpressionStatement tests
  def test_parse_expression_statement_simple
    stmt, trailing = parse_statement("foo;")
    
    assert_instance_of CppAst::Nodes::ExpressionStatement, stmt
    assert_equal "foo", stmt.expression.name
    assert_equal "", trailing
  end
  
  def test_parse_expression_statement_with_leading_trivia
    stmt, trailing = parse_statement("foo;", "  ")
    
    assert_equal "  ", stmt.leading_trivia
    assert_equal "  foo;", stmt.to_source
  end
  
  def test_parse_expression_statement_with_trailing
    stmt, trailing = parse_statement("foo;\n")
    
    assert_equal "\n", trailing
  end
  
  def test_parse_expression_statement_binary_expr
    stmt, _ = parse_statement("x = 42;")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, stmt.expression
    assert_equal "=", stmt.expression.operator
  end
  
  def test_expression_statement_roundtrip
    source = "  x = 42;\n"
    stmt, trailing = parse_statement(source[2..-1], "  ")
    
    assert_equal source, stmt.to_source + trailing
  end
  
  # ReturnStatement tests
  def test_parse_return_statement
    stmt, _ = parse_statement("return 42;")
    
    assert_instance_of CppAst::Nodes::ReturnStatement, stmt
    assert_equal "42", stmt.expression.value
  end
  
  def test_parse_return_statement_with_spacing
    stmt, _ = parse_statement("return  x;")
    
    assert_equal "  ", stmt.keyword_suffix
  end
  
  def test_parse_return_statement_with_trailing
    stmt, trailing = parse_statement("return x;\n")
    
    assert_equal "\n", trailing
  end
  
  def test_return_statement_roundtrip
    source = "  return x + 42;\n"
    stmt, trailing = parse_statement(source[2..-1], "  ")
    
    assert_equal source, stmt.to_source + trailing
  end
  
  # Edge cases
  def test_statement_with_complex_expression
    source = "result = x + y * 2;"
    stmt, _ = parse_statement(source)
    
    assert_equal source, stmt.to_source
  end
  
  def test_statement_with_comment
    source = "x = 42; // comment"
    stmt, trailing = parse_statement(source)
    
    assert_equal " // comment", trailing
  end
end

