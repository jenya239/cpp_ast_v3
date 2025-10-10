# frozen_string_literal: true

require_relative "../test_helper"

class NestedClassMembersTest < Minitest::Test
  # Test nested struct inside class
  def test_nested_struct_in_class
    source = <<~CPP
      class Foo {
      public:
          struct Bar {
              int x;
          };
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Nested struct should preserve roundtrip"
  end
  
  # Test method with body inside class
  def test_method_with_body_in_class
    source = <<~CPP
      class Foo {
      public:
          void method() {
              x = 42;
          }
      private:
          int x;
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Method body should preserve roundtrip"
  end
  
  # Minimal failing case
  def test_minimal_nested_struct
    source = <<~CPP
      class A {
          struct B {
              int x;
          };
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Minimal nested struct case"
  end
  
  # Multiple nested types
  def test_multiple_nested_types
    source = <<~CPP
      class Outer {
          struct S1 { int a; };
          struct S2 { int b; };
          enum E { A, B };
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Multiple nested types"
  end
end

