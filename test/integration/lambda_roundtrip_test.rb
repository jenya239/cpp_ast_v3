# frozen_string_literal: true

require_relative "../test_helper"

class LambdaRoundtripTest < Minitest::Test
  def test_simple_lambda
    source = "auto f = [](int x) { return x * 2; };"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_lambda_with_capture
    source = "auto f = [x](int y) { return x + y; };"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_lambda_with_capture_by_reference
    source = "auto f = [&x](int y) { return x + y; };"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_lambda_with_default_capture
    source = "auto f = [=](int y) { return x + y; };"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
  
  def test_lambda_no_params
    source = "auto f = []() { return 42; };"
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output
  end
end

