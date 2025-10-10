# frozen_string_literal: true

require_relative "../test_helper"

class TestMemberAccessRoundtrip < Minitest::Test
  # Basic access
  def test_dot_access
    assert_roundtrip "result = obj.field;\n"
  end
  
  def test_arrow_access
    assert_roundtrip "result = ptr->field;\n"
  end
  
  def test_scope_resolution
    assert_roundtrip "result = Class::method;\n"
  end
  
  # Chained access
  def test_chained_dot
    assert_roundtrip "result = obj.a.b.c;\n"
  end
  
  def test_mixed_operators
    assert_roundtrip "result = ptr->obj.field;\n"
  end
  
  # Method calls
  def test_method_call
    assert_roundtrip "result = obj.method();\n"
  end
  
  def test_method_with_args
    assert_roundtrip "result = obj.calculate(x, y);\n"
  end
  
  def test_chained_method_calls
    assert_roundtrip "result = obj.foo().bar();\n"
  end
  
  # In expressions
  def test_member_in_expression
    assert_roundtrip "result = obj.value + 10;\n"
  end
  
  def test_member_in_call
    assert_roundtrip "result = calculate(obj.x, obj.y);\n"
  end
  
  # With return
  def test_return_member
    assert_roundtrip "return obj.field;\n"
  end
  
  def test_return_method_call
    assert_roundtrip "return obj.getValue();\n"
  end
  
  # Complex
  def test_complex_chaining
    assert_roundtrip "result = obj.getChild().getValue();\n"
  end
  
  def test_scope_and_call
    assert_roundtrip "result = MyClass::getInstance().process();\n"
  end
end

