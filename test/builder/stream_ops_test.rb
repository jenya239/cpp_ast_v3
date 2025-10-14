# frozen_string_literal: true

require_relative "../test_helper"

class StreamOpsTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_stream_chain_basic
    chain = stream_chain("std::cout", string("Hello"), string("World"))
    assert_equal "std::cout << Hello << World", chain.to_source
  end
  
  def test_stream_chain_with_variables
    chain = stream_chain("std::cerr", 
      string("Error: "), 
      id("error_code"), 
      string(" at line "), 
      id("line_number")
    )
    assert_equal "std::cerr << Error:  << error_code <<  at line  << line_number", chain.to_source
  end
  
  def test_cerr_chain_helper
    chain = cerr_chain(string("Error: "), id("message"), string(" occurred"))
    assert_equal "std::cerr << Error:  << message <<  occurred", chain.to_source
  end
  
  def test_cout_chain_helper
    chain = cout_chain(string("Debug: "), id("value"), string(" = "), id("result"))
    assert_equal "std::cout << Debug:  << value <<  =  << result", chain.to_source
  end
  
  def test_endl_helper
    chain = cout_chain(string("Hello"), endl)
    assert_equal "std::cout << Hello << std::endl", chain.to_source
  end
  
  def test_complex_stream_chain
    chain = cerr_chain(
      string("OpenGL Error: "),
      id("glGetError()"),
      string(" in "),
      id("__FILE__"),
      string(":"),
      id("__LINE__"),
      endl
    )
    
    expected = "std::cerr << OpenGL Error:  << glGetError() <<  in  << __FILE__ << : << __LINE__ << std::endl"
    assert_equal expected, chain.to_source
  end
  
  def test_stream_chain_in_statement
    stmt = expr_stmt(cerr_chain(string("Debug mode enabled"), endl))
    assert_equal "std::cerr << Debug mode enabled << std::endl;", stmt.to_source
  end
  
  def test_multiple_stream_operations
    program = program(
      expr_stmt(cout_chain(string("Application started"), endl)),
      expr_stmt(cerr_chain(string("Warning: "), id("warning_msg"), endl)),
      expr_stmt(cout_chain(string("Application finished"), endl))
    )
    
    expected = <<~CPP.strip + "\n"
      std::cout << Application started << std::endl;
      std::cerr << Warning:  << warning_msg << std::endl;
      std::cout << Application finished << std::endl;
    CPP
    
    assert_equal expected, program.to_source
  end
end
