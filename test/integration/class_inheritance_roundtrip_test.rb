# frozen_string_literal: true

require_relative "../test_helper"

class ClassInheritanceRoundtripTest < Minitest::Test
  def test_class_simple_inheritance
    source = <<~CPP
      class Derived : public Base {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_private_inheritance
    source = <<~CPP
      class Derived : private Base {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_protected_inheritance
    source = <<~CPP
      class Derived : protected Base {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_multiple_inheritance
    source = <<~CPP
      class Derived : public Base1, public Base2, private Base3 {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_inheritance_with_spaces
    source = <<~CPP
      class Derived  :  public  Base {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_inheritance_with_members
    source = <<~CPP
      class Derived : public Base {
      public:
          int x;
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_struct_inheritance
    source = <<~CPP
      struct Derived : public Base {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_no_inheritance
    source = <<~CPP
      class Simple {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_class_inheritance_qualified_name
    source = <<~CPP
      class Derived : public std::base_class {
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

