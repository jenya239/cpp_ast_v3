# frozen_string_literal: true

require_relative "../test_helper"

class TemplateRoundtripTest < Minitest::Test
  def setup
    CppAst.formatting_mode = :lossless
  end
  
  def teardown
    CppAst.formatting_mode = :pretty
  end
  
  def test_template_function
    source = <<~CPP
      template <typename T>
      void foo(T arg);
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_class
    source = <<~CPP
      template <typename T>
      class Container {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_struct
    source = <<~CPP
      template <typename T>
      struct Node {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_multiple_params
    source = <<~CPP
      template <typename T, typename U>
      void foo(T a, U b);
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_with_default
    source = <<~CPP
      template <typename T = int>
      void foo();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_class_keyword
    source = <<~CPP
      template <class T>
      void foo();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_non_type_param
    source = <<~CPP
      template <int N>
      void foo();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_template_with_body
    source = <<~CPP
      template <typename T>
      void foo() {
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

