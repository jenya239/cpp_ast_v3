# frozen_string_literal: true

require_relative "../test_helper"

class StaticMembersTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_static_constexpr
    member = static_constexpr("int", "VERSION", "1")
    assert_equal "constexpr static int VERSION = 1;", member.to_source
  end
  
  def test_static_const
    member = static_const("double", "PI", "3.14159")
    assert_equal "const static double PI = 3.14159;", member.to_source
  end
  
  def test_inline_var
    member = inline_var("int", "counter", "0")
    assert_equal "inline int counter = 0;", member.to_source
  end
  
  def test_static_inline_var
    member = static_inline_var("int", "instance_count", "0")
    assert_equal "inline static int instance_count = 0;", member.to_source
  end
  
  def test_static_constexpr_with_string
    member = static_constexpr("const char*", "NAME", "\"MyClass\"")
    assert_equal "constexpr static const char* NAME = \"MyClass\";", member.to_source
  end
  
  def test_static_constexpr_with_expression
    member = static_constexpr("int", "MAX_SIZE", "1024 * 2")
    assert_equal "constexpr static int MAX_SIZE = 1024 * 2;", member.to_source
  end
  
  def test_static_members_in_class
    klass = class_decl("MyClass",
      public_section(
        static_constexpr("int", "VERSION", "1"),
        static_const("double", "PI", "3.14159"),
        inline_var("int", "counter", "0")
      ),
      private_section(
        static_inline_var("int", "instance_count", "0")
      )
    )
    
    assert_includes klass.to_source, "class MyClass"
    assert_includes klass.to_source, "constexpr static int VERSION"
    assert_includes klass.to_source, "const static double PI"
    assert_includes klass.to_source, "inline int counter"
    assert_includes klass.to_source, "inline static int instance_count"
  end
  
  def test_static_members_with_comments
    klass = class_decl("Config",
      doc_comment("Configuration class with static constants"),
      public_section(
        inline_comment("Version information"),
        static_constexpr("int", "MAJOR_VERSION", "1"),
        static_constexpr("int", "MINOR_VERSION", "0"),
        static_constexpr("int", "PATCH_VERSION", "0"),
        inline_comment("Build configuration"),
        static_constexpr("bool", "DEBUG_BUILD", "false"),
        static_constexpr("const char*", "BUILD_DATE", "\"2024-01-01\"")
      )
    )
    
    assert_includes klass.to_source, "class Config"
    assert_includes klass.to_source, "Configuration class with static constants"
    assert_includes klass.to_source, "Version information"
    assert_includes klass.to_source, "constexpr static int MAJOR_VERSION"
    assert_includes klass.to_source, "constexpr static int MINOR_VERSION"
    assert_includes klass.to_source, "constexpr static int PATCH_VERSION"
    assert_includes klass.to_source, "Build configuration"
    assert_includes klass.to_source, "constexpr static bool DEBUG_BUILD"
    assert_includes klass.to_source, "constexpr static const char* BUILD_DATE"
  end
  
  def test_static_members_with_methods
    klass = class_decl("Singleton",
      public_section(
        static_constexpr("int", "MAX_INSTANCES", "1"),
        static_inline_var("int", "instance_count", "0"),
        function_decl("Singleton*", "get_instance", [], block(
          return_stmt(id("instance"))
        )).with_prefix_modifiers("static ")
      ),
      private_section(
        static_inline_var("Singleton*", "instance", "nullptr")
      )
    )
    
    assert_includes klass.to_source, "class Singleton"
    assert_includes klass.to_source, "constexpr static int MAX_INSTANCES"
    assert_includes klass.to_source, "inline static int instance_count"
    assert_includes klass.to_source, "static Singleton* get_instance"
    assert_includes klass.to_source, "return instance"
    assert_includes klass.to_source, "inline static Singleton* instance"
  end
end
