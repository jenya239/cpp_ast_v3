# frozen_string_literal: true

require_relative "../test_helper"

class TestMemberAccess < Minitest::Test
  def test_dot_access
    object = CppAst::Nodes::Identifier.new(name: "obj")
    member = CppAst::Nodes::Identifier.new(name: "field")
    node = CppAst::Nodes::MemberAccessExpression.new(
      object: object,
      operator: ".",
      member: member
    )
    
    assert_equal "obj.field", node.to_source
  end
  
  def test_arrow_access
    object = CppAst::Nodes::Identifier.new(name: "ptr")
    member = CppAst::Nodes::Identifier.new(name: "field")
    node = CppAst::Nodes::MemberAccessExpression.new(
      object: object,
      operator: "->",
      member: member
    )
    
    assert_equal "ptr->field", node.to_source
  end
  
  def test_scope_resolution
    scope = CppAst::Nodes::Identifier.new(name: "Class")
    member = CppAst::Nodes::Identifier.new(name: "method")
    node = CppAst::Nodes::MemberAccessExpression.new(
      object: scope,
      operator: "::",
      member: member
    )
    
    assert_equal "Class::method", node.to_source
  end
  
  def test_with_operator_prefix
    object = CppAst::Nodes::Identifier.new(name: "obj")
    member = CppAst::Nodes::Identifier.new(name: "field")
    node = CppAst::Nodes::MemberAccessExpression.new(
      object: object,
      operator: ".",
      member: member,
      operator_prefix: " "
    )
    
    assert_equal "obj .field", node.to_source
  end
  
  def test_with_operator_suffix
    object = CppAst::Nodes::Identifier.new(name: "obj")
    member = CppAst::Nodes::Identifier.new(name: "field")
    node = CppAst::Nodes::MemberAccessExpression.new(
      object: object,
      operator: ".",
      member: member,
      operator_suffix: " "
    )
    
    assert_equal "obj. field", node.to_source
  end
  
  def test_chained_access
    obj = CppAst::Nodes::Identifier.new(name: "obj")
    field1 = CppAst::Nodes::Identifier.new(name: "a")
    first = CppAst::Nodes::MemberAccessExpression.new(
      object: obj,
      operator: ".",
      member: field1
    )
    field2 = CppAst::Nodes::Identifier.new(name: "b")
    second = CppAst::Nodes::MemberAccessExpression.new(
      object: first,
      operator: ".",
      member: field2
    )
    
    assert_equal "obj.a.b", second.to_source
  end
end

