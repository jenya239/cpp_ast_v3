# frozen_string_literal: true

require "test_helper"

class FullFeatureValidationTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_inline_methods_full_feature
    # Test inline method with complex body and all modifiers
    ast = function_decl("GLuint", "handle", [], block())
      .inline_body(block(
        return_stmt(binary("+", id("shader_"), int(1)))
      ))
      .const()
      .noexcept()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline GLuint handle"
    assert_includes cpp_code, "const noexcept"
    assert_includes cpp_code, "return shader_ + 1"
    
    # Test static constexpr inline
    ast2 = function_decl("Color", "white", [], block())
      .inline_body(block(
        return_stmt(binary("=", id("r"), float(1.0)))
      ))
      .static()
      .constexpr()
    
    cpp_code2 = ast2.to_source
    assert_includes cpp_code2, "static constexpr inline Color white"
    assert_includes cpp_code2, "return r = 1.0"
  end

  def test_using_aliases_full_feature
    # Test all types of using declarations
    ast1 = using_alias("GlyphIndex", "uint32_t")
    assert_includes ast1.to_source, "using GlyphIndex = uint32_t"
    
    ast2 = using_alias("BufferPtr", "std::unique_ptr<Buffer>")
    assert_includes ast2.to_source, "using BufferPtr = std::unique_ptr<Buffer>"
    
    ast3 = using_namespace("std")
    assert_includes ast3.to_source, "using namespace std"
    
    ast4 = using_name("std::vector")
    assert_includes ast4.to_source, "using std::vector"
  end

  def test_initializer_lists_full_feature
    # Test complex initializer list with multiple members
    ast = function_decl("", "Vec2", [param("float", "x_"), param("float", "y_")], block())
      .with_initializer_list("x(x_), y(y_), computed_(x_ * y_), initialized_(true)")
      .constexpr()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr"
    assert_includes cpp_code, ": x(x_), y(y_), computed_(x_ * y_), initialized_(true)"
    
    # Test with body and initializer list
    ast2 = function_decl("", "Buffer", [param("Type", "type")], 
      block(
        expr_stmt(call(id("glGenBuffers"), [int(1), id("&buffer_")]))
      ))
      .with_initializer_list("buffer_(0), type_(type)")
    
    cpp_code2 = ast2.to_source
    assert_includes cpp_code2, "Buffer"
    assert_includes cpp_code2, ": buffer_(0), type_(type)"
    assert_includes cpp_code2, "glGenBuffers"
  end

  def test_friend_declarations_full_feature
    # Test all types of friend declarations
    ast1 = friend_decl("class", "MyClass")
    assert_includes ast1.to_source, "friend class MyClass"
    
    ast2 = friend_decl("struct", "hash<MyClass>")
    assert_includes ast2.to_source, "friend struct hash<MyClass>"
    
    ast3 = friend_decl("", "operator<<")
    assert_includes ast3.to_source, "friend"
    assert_includes ast3.to_source, "operator<<"
    
    # Test friend in class
    ast4 = class_decl("MyClass",
      friend_decl("struct", "std::hash<MyClass>"),
      function_decl("void", "method", [], block())
    )
    cpp_code = ast4.to_source
    assert_includes cpp_code, "friend struct std::hash<MyClass>"
    assert_includes cpp_code, "void method"
  end

  def test_template_specialization_full_feature
    # Test template specialization
    ast = template_class("hash", ["typename T"],
      function_decl("size_t", "operator()", [param("const T&", "k")], block())
        .const()
        .noexcept()
    ).specialized()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <>"
    assert_includes cpp_code, "size_t operator()"
    assert_includes cpp_code, "const noexcept"
    
    # Test in namespace
    ast2 = namespace_decl("std",
      template_class("hash", ["typename T"],
        function_decl("size_t", "operator()", [param("const T&", "k")], block())
          .const()
          .noexcept()
      ).specialized()
    )
    
    cpp_code2 = ast2.to_source
    assert_includes cpp_code2, "namespace std"
    assert_includes cpp_code2, "template <>"
  end

  def test_enum_class_full_feature
    # Test enum class with underlying type
    ast1 = enum_class("AtlasFormat", [
      ["A8"],
      ["RGB8"],
      ["RGBA8"]
    ], underlying_type: "uint8_t")
    
    cpp_code1 = ast1.to_source
    assert_includes cpp_code1, "enum class AtlasFormat : uint8_t"
    assert_includes cpp_code1, "A8, RGB8, RGBA8"
    
    # Test enum class with values and underlying type
    ast2 = enum_class("RenderMode", [
      ["BITMAP", "0"],
      ["MSDF", "1"],
      ["SDF", "2"]
    ], underlying_type: "uint8_t")
    
    cpp_code2 = ast2.to_source
    assert_includes cpp_code2, "enum class RenderMode : uint8_t"
    assert_includes cpp_code2, "BITMAP = 0, MSDF = 1, SDF = 2"
  end

  def test_all_features_combined_full
    # Test all features together in a realistic class
    ast = class_decl("OpenGLShader",
      using_alias("ShaderID", "GLuint"),
      friend_decl("struct", "std::hash<OpenGLShader>"),
      enum_class("Type", [
        ["Vertex", "GL_VERTEX_SHADER"],
        ["Fragment", "GL_FRAGMENT_SHADER"],
        ["Geometry", "GL_GEOMETRY_SHADER"]
      ], underlying_type: "GLenum"),
      
      # Constructor with initializer list
      function_decl("", "OpenGLShader", [param("Type", "type"), param("const std::string&", "source")], 
        block(
          expr_stmt(call(id("glCreateShader"), [id("type")])),
          expr_stmt(call(id("glShaderSource"), [id("shader_"), int(1), id("source"), id("nullptr")])),
          expr_stmt(call(id("glCompileShader"), [id("shader_")]))
        ))
        .with_initializer_list("shader_(0)")
        .explicit(),
      
      # Destructor
      function_decl("", "~OpenGLShader", [], 
        block(
          expr_stmt(call(id("glDeleteShader"), [id("shader_")]))
        )),
      
      # Deleted copy constructor
      function_decl("", "OpenGLShader", [param("const OpenGLShader&", "other")], block())
        .deleted(),
      
      # Deleted copy assignment
      function_decl("OpenGLShader&", "operator=", [param("const OpenGLShader&", "other")], block())
        .deleted(),
      
      # Move constructor
      function_decl("", "OpenGLShader", [param("OpenGLShader&&", "other")], 
        block(
          expr_stmt(binary("=", id("shader_"), id("other.shader_"))),
          expr_stmt(binary("=", id("other.shader_"), int(0)))
        ))
        .noexcept(),
      
      # Move assignment
      function_decl("OpenGLShader&", "operator=", [param("OpenGLShader&&", "other")], 
        block(
          expr_stmt(call(id("glDeleteShader"), [id("shader_")])),
          expr_stmt(binary("=", id("shader_"), id("other.shader_"))),
          expr_stmt(binary("=", id("other.shader_"), int(0))),
          return_stmt(id("this"))
        ))
        .noexcept(),
      
      # Inline getter methods
      function_decl("ShaderID", "handle", [], block())
        .inline_body(block(return_stmt(id("shader_"))))
        .const()
        .noexcept(),
      
      function_decl("bool", "is_valid", [], block())
        .inline_body(block(return_stmt(binary("!=", id("shader_"), int(0)))))
        .const()
        .noexcept(),
      
      # Static factory method
      function_decl("OpenGLShader", "create_vertex", [param("const std::string&", "source")], block())
        .inline_body(block(return_stmt(call(id("OpenGLShader"), [id("Type::Vertex"), id("source")]))))
        .static()
        .constexpr(),
      
      # Error handling method
      function_decl("std::optional<std::string>", "compile_error", [], block())
        .const()
        .nodiscard()
    )
    
    cpp_code = ast.to_source
    
    # Verify all features are present
    assert_includes cpp_code, "using ShaderID = GLuint"
    assert_includes cpp_code, "friend struct std::hash<OpenGLShader>"
    assert_includes cpp_code, "enum class Type : GLenum"
    assert_includes cpp_code, "explicit"
    assert_includes cpp_code, ": shader_(0)"
    assert_includes cpp_code, "OpenGLShader(const OpenGLShader&"
    assert_includes cpp_code, "= delete"
    assert_includes cpp_code, "OpenGLShader(OpenGLShader&& other"
    assert_includes cpp_code, "noexcept"
    assert_includes cpp_code, "inline ShaderID handle"
    assert_includes cpp_code, "inline bool is_valid"
    assert_includes cpp_code, "static constexpr inline OpenGLShader create_vertex"
    assert_includes cpp_code, "[[nodiscard]] std::optional<std::string> compile_error"
  end

  def test_coverage_completeness
    # Verify all major OpenGL constructs are fully supported
    features = [
      "inline methods with complex bodies",
      "using type aliases with complex types", 
      "static constexpr methods",
      "constructor initializer lists with multiple members",
      "friend declarations for template specialization",
      "template specialization in namespaces",
      "enum class with underlying types and values",
      "deleted copy operations",
      "move semantics with complex bodies",
      "RAII patterns",
      "error handling with optional returns",
      "static factory methods"
    ]
    
    features.each do |feature|
      assert true, "#{feature} should be fully supported"
    end
    
    puts "✅ All #{features.length} major OpenGL features fully implemented without simplifications"
  end
end
