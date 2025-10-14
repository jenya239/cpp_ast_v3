# frozen_string_literal: true

require_relative "../test_helper"

class NestedTypesTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_nested_class
    outer = class_decl("Outer",
      nested_class("Inner",
        var_decl("int", "value")
      )
    )
    
    expected = <<~CPP.strip
      class Outer {
      class Inner {
      int value;
      };
      };
    CPP
    
    assert_equal expected, outer.to_source
  end
  
  def test_nested_struct
    outer = struct_decl("Outer",
      nested_struct("Inner",
        var_decl("double", "x"),
        var_decl("double", "y")
      )
    )
    
    expected = <<~CPP.strip
      struct Outer {
      struct Inner {
      double x;
      double y;
      };
      };
    CPP
    
    assert_equal expected, outer.to_source
  end
  
  def test_nested_enum
    outer = class_decl("Outer",
      nested_enum("State", "IDLE", "RUNNING", "STOPPED")
    )
    
    expected = <<~CPP.strip
      class Outer {
      enum State {IDLE, RUNNING, STOPPED};
      };
    CPP
    
    assert_equal expected, outer.to_source
  end
  
  def test_nested_enum_class
    outer = class_decl("Outer",
      nested_enum_class("State", "IDLE", "RUNNING", "STOPPED")
    )
    
    expected = <<~CPP.strip
      class Outer {
      enum class State{IDLE, RUNNING, STOPPED};
      };
    CPP
    
    assert_equal expected, outer.to_source
  end
  
  def test_nested_namespace
    outer = namespace_decl("Outer",
      nested_namespace("Inner",
        var_decl("int", "value")
      )
    )
    
    expected = <<~CPP.strip
      namespace  Outer  {namespace  Inner  {int value;}}
    CPP
    
    assert_equal expected, outer.to_source
  end
  
  def test_complex_nested_types
    outer = class_decl("Outer",
      # Nested class
      nested_class("Inner",
        var_decl("int", "value"),
        function_decl("void", "method", [], block(
          expr_stmt(cout_chain(string("Inner method called"), endl))
        ))
      ),
      
      # Nested enum
      nested_enum("State", "IDLE", "RUNNING", "STOPPED"),
      
      # Nested struct
      nested_struct("Data",
        var_decl("double", "x"),
        var_decl("double", "y")
      )
    )
    
    expected = <<~CPP.strip
      class Outer {
      class Inner {
      int value;
      void method()  {
      std::cout << Inner method called << std::endl;
      }
      };
      enum State {IDLE, RUNNING, STOPPED};
      struct Data {
      double x;
      double y;
      };
      };
    CPP
    
    assert_equal expected, outer.to_source
  end
  
  def test_nested_types_with_access_specifiers
    outer = class_decl("Outer",
      public_section(
        nested_class("PublicInner",
          var_decl("int", "public_value")
        )
      ),
      private_section(
        nested_class("PrivateInner",
          var_decl("int", "private_value")
        )
      )
    )
    
    expected = <<~CPP.strip
      class Outer {
      public:
      class PublicInner {
      int public_value;
      };
      private:class PrivateInner {
      int private_value;
      };};
    CPP
    
    assert_equal expected, outer.to_source
  end
end
