#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../test_helper"

class EnumClassTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_enum_class_basic
    ast = enum_class("Type", [
      ["Vertex", "GL_VERTEX_SHADER"],
      ["Fragment", "GL_FRAGMENT_SHADER"],
      ["Geometry", "GL_GEOMETRY_SHADER"]
    ])
    
    cpp_code = ast.to_source
    expected = "enum class Type {Vertex = GL_VERTEX_SHADER, Fragment = GL_FRAGMENT_SHADER, Geometry = GL_GEOMETRY_SHADER};"
    
    assert_equal expected, cpp_code
  end

  def test_enum_class_with_underlying_type
    ast = enum_class("Format", [
      ["A8"],
      ["RGB8"],
      ["RGBA8"]
    ], underlying_type: "uint8_t")
    
    cpp_code = ast.to_source
    expected = "enum class Format  : uint8_t{A8, RGB8, RGBA8};"
    
    assert_equal expected, cpp_code
  end

  def test_enum_class_with_values_and_underlying_type
    ast = enum_class("Usage", [
      ["Static", "GL_STATIC_DRAW"],
      ["Dynamic", "GL_DYNAMIC_DRAW"],
      ["Stream", "GL_STREAM_DRAW"]
    ], underlying_type: "GLenum")
    
    cpp_code = ast.to_source
    expected = "enum class Usage  : GLenum{Static = GL_STATIC_DRAW, Dynamic = GL_DYNAMIC_DRAW, Stream = GL_STREAM_DRAW};"
    
    assert_equal expected, cpp_code
  end

  def test_enum_class_simple_values
    ast = enum_class("Color", [
      ["Red"],
      ["Green"],
      ["Blue"]
    ])
    
    cpp_code = ast.to_source
    expected = "enum class Color {Red, Green, Blue};"
    
    assert_equal expected, cpp_code
  end

  def test_enum_class_mixed_values
    ast = enum_class("State", [
      ["Idle"],
      ["Running", "STATE_RUNNING"],
      ["Paused"],
      ["Stopped", "STATE_STOPPED"]
    ])
    
    cpp_code = ast.to_source
    expected = "enum class State {Idle, Running = STATE_RUNNING, Paused, Stopped = STATE_STOPPED};"
    
    assert_equal expected, cpp_code
  end

  def test_enum_class_in_class
    ast = class_decl("Shader",
      access_spec("public"),
      enum_class("Type", [
        ["Vertex", "GL_VERTEX_SHADER"],
        ["Fragment", "GL_FRAGMENT_SHADER"]
      ]),
      function_decl("", "Shader", [param("Type", "type")], block())
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class Type"
    assert_includes cpp_code, "Vertex = GL_VERTEX_SHADER"
    assert_includes cpp_code, "Fragment = GL_FRAGMENT_SHADER"
  end

  def test_roundtrip_enum_class
    # Generate C++ code
    ast = enum_class("Type", [
      ["Vertex", "GL_VERTEX_SHADER"],
      ["Fragment", "GL_FRAGMENT_SHADER"]
    ])
    cpp_code = ast.to_source
    
    # Basic validation - should contain expected elements
    assert_includes cpp_code, "enum class Type"
    assert_includes cpp_code, "Vertex = GL_VERTEX_SHADER"
    assert_includes cpp_code, "Fragment = GL_FRAGMENT_SHADER"
  end

  def test_roundtrip_enum_class_with_underlying_type
    # Generate C++ code
    ast = enum_class("Format", [
      ["A8"],
      ["RGB8"]
    ], underlying_type: "uint8_t")
    cpp_code = ast.to_source
    
    # Basic validation - should contain expected elements
    assert_includes cpp_code, "enum class Format  : uint8_t"
    assert_includes cpp_code, "A8"
    assert_includes cpp_code, "RGB8"
  end
end
