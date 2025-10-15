#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../test_helper"

class TemplateDslTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_template_class_basic
    ast = template_class("Buffer", ["typename T"],
      access_spec("public"),
      function_decl("void", "data", [param("T", "value")], block())
    )
    
    cpp_code = ast.to_source
    expected = "template <typename T>\nclass Buffer {\npublic:\nvoid data(T value ){\n}\n};"
    
    assert_equal expected, cpp_code
  end

  def test_template_method_basic
    ast = template_method("void", "data", ["typename T"], 
      [param("T", "value")], 
      block(expr_stmt(call(id("process"), id("value"))))
    )
    
    cpp_code = ast.to_source
    expected = "template <typename T>\nvoid data(T value) {\nprocess(value);\n}"
    
    assert_equal expected, cpp_code
  end

  def test_template_class_with_enum
    ast = template_class("Buffer", ["typename T"],
      access_spec("public"),
      function_decl("", "Buffer", [param("Type", "type")], block()).explicit()
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "class Buffer"
    assert_includes cpp_code, "explicit  Buffer(Type type)"
  end

  def test_template_method_with_span
    ast = template_method("void", "data", ["typename T"],
      [param(span_of("const T"), "data"), param("Usage", "usage", default: "Usage::Static")],
      block(
        expr_stmt(call(id("bind"))),
        expr_stmt(call(id("glBufferData"), 
          call(id("static_cast"), id("GLenum"), id("type_")),
          call(member(id("data"), ".", "size_bytes")),
          call(member(id("data"), ".", "data")),
          call(id("static_cast"), id("GLenum"), id("usage"))
        ))
      )
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "void data(std::span<const T> data, Usage usage = Usage::Static)"
    assert_includes cpp_code, "bind();"
    assert_includes cpp_code, "glBufferData"
  end

  def test_roundtrip_template_class
    # Generate C++ code
    ast = template_class("Buffer", ["typename T"],
      access_spec("public"),
      function_decl("void", "data", [param("T", "value")], block())
    )
    
    cpp_code = ast.to_source
    
    # Parse it back
    parsed_ast = CppAst.parse(cpp_code)
    
    # Should be able to parse without errors
    assert parsed_ast
    assert_equal cpp_code, parsed_ast.to_source
  end

  def test_roundtrip_template_method
    # Generate C++ code
    ast = template_method("void", "process", ["typename T"],
      [param("T", "value")],
      block(expr_stmt(call(id("handle"), id("value"))))
    )
    
    cpp_code = ast.to_source
    
    # Parse it back
    parsed_ast = CppAst.parse(cpp_code)
    
    # Should be able to parse without errors
    assert parsed_ast
    assert_equal cpp_code, parsed_ast.to_source
  end
end
