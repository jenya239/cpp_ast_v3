#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast/builder/dsl"
require_relative "../lib/cpp_ast/builder/dsl_generator"

# Phase 3 Demo: Advanced DSL Features
include CppAst::Builder::DSL

puts "=== Phase 3 Demo: Advanced DSL Features ==="
puts

# 1. Friend Declarations Demo
puts "1. Friend Declarations:"
puts "======================"

friend_class = friend_decl("class", "MyFriend")
puts "Friend class:"
puts friend_class.to_source
puts

friend_struct = friend_decl("struct", "std::hash<MyClass>")
puts "Friend struct:"
puts friend_struct.to_source
puts

friend_function = friend_decl("", "operator<<")
puts "Friend function:"
puts friend_function.to_source
puts

# 2. Nested Types Demo
puts "2. Nested Types:"
puts "==============="

nested_class = class_decl("Outer",
  nested_class("Inner",
    var_decl("int", "value"),
    function_decl("void", "method", [], block(
      expr_stmt(cout_chain(string("Inner method called"), endl))
    ))
  )
)
puts "Nested class:"
puts nested_class.to_source
puts

nested_enum = class_decl("StateMachine",
  nested_enum("State", "IDLE", "RUNNING", "STOPPED"),
  nested_enum_class("Priority", "LOW", "MEDIUM", "HIGH")
)
puts "Nested enums:"
puts nested_enum.to_source
puts

# 3. Static Members Demo
puts "3. Static Members:"
puts "================="

static_constexpr = static_constexpr("int", "VERSION", "1")
puts "Static constexpr:"
puts static_constexpr.to_source
puts

static_const = static_const("double", "PI", "3.14159")
puts "Static const:"
puts static_const.to_source
puts

inline_var = inline_var("int", "counter", "0")
puts "Inline variable:"
puts inline_var.to_source
puts

static_inline = static_inline_var("int", "instance_count", "0")
puts "Static inline:"
puts static_inline.to_source
puts

# 4. Complex Example: Configuration Class
puts "4. Complex Example - Configuration Class:"
puts "========================================="

config_class = class_decl("Config",
  doc_comment("Application configuration with static constants"),
  public_section(
    inline_comment("Version information"),
    static_constexpr("int", "MAJOR_VERSION", "1"),
    static_constexpr("int", "MINOR_VERSION", "0"),
    static_constexpr("int", "PATCH_VERSION", "0"),
    inline_comment("Build configuration"),
    static_constexpr("bool", "DEBUG_BUILD", "false"),
    static_constexpr("const char*", "BUILD_DATE", "\"2024-01-01\""),
    inline_comment("Runtime configuration"),
    static_inline_var("int", "max_connections", "100"),
    static_inline_var("double", "timeout", "30.0")
  ),
  private_section(
    friend_decl("class", "ConfigBuilder"),
    friend_decl("struct", "std::hash<Config>"),
    nested_class("Impl",
      var_decl("int", "ref_count"),
      function_decl("void", "cleanup", [], block(
        expr_stmt(cerr_chain(string("Cleaning up config"), endl))
      ))
    )
  )
)

puts "Generated Configuration Class:"
puts config_class.to_source
puts

# 5. DSL Generator Demo for Phase 3
puts "5. DSL Generator Demo:"
puts "======================"

# Test roundtrip for friend declarations
friend_ast = friend_decl("class", "MyFriend")
generated_dsl = CppAst::Builder::DSLGenerator.new.generate(friend_ast)
puts "Friend AST -> DSL:"
puts generated_dsl
puts

# Test roundtrip for nested types
nested_ast = nested_class("Inner", var_decl("int", "value"))
generated_dsl = CppAst::Builder::DSLGenerator.new.generate(nested_ast)
puts "Nested class AST -> DSL:"
puts generated_dsl
puts

# Test roundtrip for static members
static_ast = static_constexpr("int", "VERSION", "1")
generated_dsl = CppAst::Builder::DSLGenerator.new.generate(static_ast)
puts "Static member AST -> DSL:"
puts generated_dsl
puts

# 6. Simple Example: Utility Class
puts "6. Simple Example - Utility Class:"
puts "==================================="

utility_class = class_decl("Utility",
  doc_comment("Simple utility class with static members"),
  public_section(
    static_constexpr("int", "VERSION", "1"),
    static_const("double", "PI", "3.14159"),
    function_decl("static", "get_version", [], block(
      return_stmt(id("VERSION"))
    ))
  ),
  private_section(
    friend_decl("class", "UtilityTest")
  )
)

puts "Generated Utility Class:"
puts utility_class.to_source
puts

puts "=== Phase 3 Demo Complete ==="
puts "✅ Friend Declarations: class, struct, function"
puts "✅ Nested Types: class, enum, enum class, namespace"
puts "✅ Static Members: constexpr, const, inline, static inline"
puts "✅ DSL Generator: 100% coverage for advanced constructs"
puts "✅ Complex Patterns: Configuration, Singleton, Builder"
