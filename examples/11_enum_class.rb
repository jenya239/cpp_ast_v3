#!/usr/bin/env ruby
# frozen_string_literal: true

# Enum Class Example - Aurora DSL
# Demonstrates enum class support with underlying types

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Enum Class Example ==="
puts "Generating OpenGL enums with enum class support"
puts

# Generate enums with enum class support
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<epoxy/gl.h>"'))),
  expr_stmt(call(id("include"), string('"<cstdint>"'))),
  
  # Namespace declaration
  namespace_decl("gtkgl::gl", [
    
    # Shader Type enum class
    enum_class("ShaderType", [
      ["Vertex", "GL_VERTEX_SHADER"],
      ["Fragment", "GL_FRAGMENT_SHADER"],
      ["Geometry", "GL_GEOMETRY_SHADER"],
      ["Compute", "GL_COMPUTE_SHADER"]
    ]),
    
    # Buffer Type enum class
    enum_class("BufferType", [
      ["Array", "GL_ARRAY_BUFFER"],
      ["ElementArray", "GL_ELEMENT_ARRAY_BUFFER"],
      ["Uniform", "GL_UNIFORM_BUFFER"],
      ["Texture", "GL_TEXTURE_BUFFER"]
    ]),
    
    # Usage enum class with underlying type
    enum_class("Usage", [
      ["Static", "GL_STATIC_DRAW"],
      ["Dynamic", "GL_DYNAMIC_DRAW"],
      ["Stream", "GL_STREAM_DRAW"]
    ], underlying_type: "GLenum"),
    
    # Format enum class with underlying type
    enum_class("Format", [
      ["A8"],
      ["RGB8"],
      ["RGBA8"],
      ["RGB16F"],
      ["RGBA16F"],
      ["RGB32F"],
      ["RGBA32F"]
    ], underlying_type: "uint8_t"),
    
    # State enum class
    enum_class("State", [
      ["Idle"],
      ["Running", "STATE_RUNNING"],
      ["Paused"],
      ["Stopped", "STATE_STOPPED"],
      ["Error", "STATE_ERROR"]
    ]),
    
    # Color enum class with underlying type
    enum_class("Color", [
      ["Red"],
      ["Green"],
      ["Blue"],
      ["White"],
      ["Black"]
    ], underlying_type: "uint8_t")
  ])
)

# Generate and display the C++ code
cpp_code = ast.to_source

puts "Generated C++ Code:"
puts "=" * 50
puts cpp_code
puts "=" * 50

puts
puts "Features demonstrated:"
puts "✅ Enum class declarations"
puts "✅ Underlying type support"
puts "✅ Mixed value assignments"
puts "✅ Type-safe enums"
puts "✅ Namespace organization"
puts

puts "This C++ code demonstrates:"
puts "- Type-safe enum classes for OpenGL"
puts "- Underlying type specification"
puts "- Mixed value assignments (some with values, some without)"
puts "- Namespace organization for OpenGL types"
puts

puts "Demo completed successfully! 🎉"
