# frozen_string_literal: true

require_relative "../test_helper"

class TemplateTypesRoundtripTest < Minitest::Test
  def test_vector_type
    source = <<~CPP
      std::vector<int> v;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_unique_ptr_type
    source = <<~CPP
      std::unique_ptr<int> ptr;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_nested_template_type
    source = <<~CPP
      std::vector<std::string> v;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_with_template_return
    source = <<~CPP
      std::vector<int> foo();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_with_template_param
    source = <<~CPP
      void foo(std::vector<int> v);
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

