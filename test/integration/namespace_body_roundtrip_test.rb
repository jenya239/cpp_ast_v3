# frozen_string_literal: true

require_relative "../test_helper"

class NamespaceBodyRoundtripTest < Minitest::Test
  def test_simple_namespace_with_function
    source = <<~CPP
      namespace myns {
          void foo() {
              int x = 42;
          }
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_nested_namespace_with_function
    source = <<~CPP
      namespace gtkgl::gl {
          void init() {
              glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
          }
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_namespace_with_out_of_class_method
    source = <<~CPP
      namespace myns {
          MyClass::MyClass() {
              value_ = 0;
          }
          
          MyClass::~MyClass() {
              cleanup();
          }
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_nested_namespace_with_multiple_methods
    source = <<~CPP
      namespace gtkgl::gl {
      
      VertexArray::VertexArray() {
          glGenVertexArrays(1, &vao_);
      }
      
      VertexArray::~VertexArray() {
          if (vao_ != 0) {
              glDeleteVertexArrays(1, &vao_);
          }
      }
      
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_namespace_with_variable_declarations
    source = <<~CPP
      namespace config {
          const int MAX_SIZE = 1024;
          constexpr uint32_t BUFFER_SIZE = 2048;
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
end

