# frozen_string_literal: true

require_relative "../test_helper"

class AttributesRoundtripTest < Minitest::Test
  def test_attribute_before_function
    source = <<~CPP
      [[nodiscard]] int foo();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_attribute_on_parameter
    source = <<~CPP
      void foo([[maybe_unused]] int x);
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_multiple_attributes_on_parameter
    source = <<~CPP
      void foo([[maybe_unused]] [[nodiscard]] int x);
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_attribute_before_variable
    source = <<~CPP
      [[maybe_unused]] int x;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_attribute_with_function_body
    source = <<~CPP
      [[nodiscard]] int foo() {
          return 42;
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_nested_attributes
    source = <<~CPP
      [[maybe_unused]] [[nodiscard]] int foo();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_attribute_in_class
    source = <<~CPP
      class Foo {
          [[nodiscard]] int bar();
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

