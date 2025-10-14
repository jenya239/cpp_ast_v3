# frozen_string_literal: true

require "test_helper"

class UsingAliasesTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_using_alias_basic
    ast = using_alias("GlyphIndex", "uint32_t")
    cpp_code = ast.to_source
    expected = "using GlyphIndex = uint32_t;"
    assert_equal expected, cpp_code
  end

  def test_using_alias_multiple
    ast = using_alias("FontFaceID", "uint32_t")
    cpp_code = ast.to_source
    expected = "using FontFaceID = uint32_t;"
    assert_equal expected, cpp_code
  end

  def test_using_alias_with_namespace
    ast = using_alias("TextureID", "GLuint")
    cpp_code = ast.to_source
    expected = "using TextureID = GLuint;"
    assert_equal expected, cpp_code
  end

  def test_using_alias_complex_type
    ast = using_alias("BufferPtr", "std::unique_ptr<Buffer>")
    cpp_code = ast.to_source
    expected = "using BufferPtr = std::unique_ptr<Buffer>;"
    assert_equal expected, cpp_code
  end

  def test_using_alias_template_type
    ast = using_alias("Vector2f", "std::vector<float>")
    cpp_code = ast.to_source
    expected = "using Vector2f = std::vector<float>;"
    assert_equal expected, cpp_code
  end

  def test_using_namespace
    ast = using_namespace("std")
    cpp_code = ast.to_source
    expected = "using namespace std;"
    assert_equal expected, cpp_code
  end

  def test_using_name
    ast = using_name("std::vector")
    cpp_code = ast.to_source
    expected = "using std::vector;"
    assert_equal expected, cpp_code
  end

  def test_using_alias_in_class
    # Test that using aliases can be used as class members
    ast = class_decl("MyClass",
      using_alias("Index", "int"),
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "using Index = int;"
    assert_includes cpp_code, "void method"
  end
end
