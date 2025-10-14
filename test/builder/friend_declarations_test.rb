# frozen_string_literal: true

require_relative "../test_helper"

class FriendDeclarationsTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_friend_class_declaration
    ast = friend_decl("class", "MyClass")
    cpp_code = ast.to_source
    expected = "friend class MyClass;"
    assert_equal expected, cpp_code
  end

  def test_friend_struct_declaration
    ast = friend_decl("struct", "hash")
    cpp_code = ast.to_source
    expected = "friend struct hash;"
    assert_equal expected, cpp_code
  end

  def test_friend_function_declaration
    ast = friend_decl("", "operator<<")
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend"
    assert_includes cpp_code, "operator<<"
  end

  def test_friend_template_specialization
    ast = friend_decl("struct", "hash<GlyphCacheKey>")
    cpp_code = ast.to_source
    expected = "friend struct hash<GlyphCacheKey>;"
    assert_equal expected, cpp_code
  end

  def test_friend_in_class
    # Test friend declaration as class member
    ast = class_decl("MyClass",
      friend_decl("struct", "hash<MyClass>"),
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend struct hash<MyClass>;"
    assert_includes cpp_code, "void method"
  end

  def test_friend_multiple_in_class
    ast = class_decl("MyClass",
      friend_decl("class", "MyFriend"),
      friend_decl("struct", "hash<MyClass>"),
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend class MyFriend;"
    assert_includes cpp_code, "friend struct hash<MyClass>;"
  end

  def test_friend_with_namespace
    ast = friend_decl("struct", "std::hash<MyClass>")
    cpp_code = ast.to_source
    expected = "friend struct std::hash<MyClass>;"
    assert_equal expected, cpp_code
  end

  def test_friend_template_class
    ast = friend_decl("class", "std::hash")
    cpp_code = ast.to_source
    expected = "friend class std::hash;"
    assert_equal expected, cpp_code
  end
end
