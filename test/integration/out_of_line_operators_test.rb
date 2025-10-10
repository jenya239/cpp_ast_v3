# frozen_string_literal: true

require_relative "../test_helper"

class OutOfLineOperatorsTest < Minitest::Test
  def test_operator_equals_simple
    source = "A& A::operator=(A& other) {}"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_operator_subscript
    source = "int& Foo::operator[](int i) {}"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_operator_call
    source = "void A::operator()(int x) {}"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_operator_plus
    source = "A A::operator+(A& other) {}"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
end

