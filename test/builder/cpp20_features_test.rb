# frozen_string_literal: true

require_relative "../test_helper"

class Cpp20FeaturesTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_concept_declaration
    concept = concept_decl("Drawable", ["typename T"], "requires(T t) { t.draw(); }")
    assert_equal "template <typename T>\nconcept Drawable = requires(T t) { t.draw(); };", concept.to_source
  end
  
  def test_module_declaration
    module_decl = module_decl("math",
      var_decl("int", "pi", "3"),
      function_decl("int", "add", [param("int", "a"), param("int", "b")], block(
        return_stmt(binary("+", id("a"), id("b")))
      ))
    )
    
    assert_includes module_decl.to_source, "export module math"
    assert_includes module_decl.to_source, "int pi"
    assert_includes module_decl.to_source, "int add"
  end
  
  def test_import_declaration
    import = import_decl("std.core")
    assert_equal "import std.core;", import.to_source
  end
  
  def test_export_declaration
    export = export_decl(
      var_decl("int", "version", "1"),
      function_decl("void", "init", [], nil)
    )
    
    assert_includes export.to_source, "export {"
    assert_includes export.to_source, "int version"
    assert_includes export.to_source, "void init"
  end
  
  def test_coroutine_function
    coroutine = coroutine_function("int", "generator", [param("int", "max")], block(
      co_yield(int(1)),
      co_yield(int(2)),
      co_return(int(3))
    ))
    
    assert_includes coroutine.to_source, "coroutine int generator"
    assert_includes coroutine.to_source, "co_yield"
    assert_includes coroutine.to_source, "co_return"
  end
  
  def test_co_await_expression
    await_expr = co_await(call(id("future"), "get", []))
    assert_includes await_expr.to_source, "co_await"
    assert_includes await_expr.to_source, "future"
  end
  
  def test_co_yield_expression
    yield_expr = co_yield(int(42))
    assert_equal "co_yield 42", yield_expr.to_source
  end
  
  def test_co_return_statement
    co_return_stmt = co_return(int(100))
    assert_equal "co_return 100;", co_return_stmt.to_source
    
    co_return_empty = co_return()
    assert_equal "co_return;", co_return_empty.to_source
  end
  
  def test_complex_cpp20_example
    program = program(
      # Module declaration
      module_decl("async_utils",
        # Import other modules
        import_decl("std.core"),
        import_decl("std.threading"),
        
        # Concept definition
        concept_decl("Awaitable", ["typename T"], "requires(T t) { t.await_ready(); }"),
        
        # Coroutine function
        coroutine_function("int", "async_generator", [param("int", "count")], block(
          co_yield(int(1)),
          co_yield(int(2)),
          co_return(int(0))
        )),
        
        # Export declarations
        export_decl(
          function_decl("int", "async_generator", [param("int", "count")], nil)
        )
      )
    )
    
    assert_includes program.to_source, "export module async_utils"
    assert_includes program.to_source, "import std.core"
    assert_includes program.to_source, "concept Awaitable"
    assert_includes program.to_source, "coroutine int async_generator"
    assert_includes program.to_source, "co_yield"
    assert_includes program.to_source, "co_return"
    assert_includes program.to_source, "export {"
  end
  
  def test_concept_with_template_constraints
    concept = concept_decl("Serializable", 
      ["typename T"], 
      "requires(T t) { t.serialize(); t.deserialize(); }"
    )
    
    expected = "template <typename T>\nconcept Serializable = requires(T t) { t.serialize(); t.deserialize(); };"
    assert_equal expected, concept.to_source
  end
  
  def test_module_with_multiple_imports
    module_decl = module_decl("graphics",
      import_decl("std.core"),
      import_decl("std.memory"),
      import_decl("math"),
      var_decl("int", "screen_width", "1920"),
      var_decl("int", "screen_height", "1080")
    )
    
    assert_includes module_decl.to_source, "export module graphics"
    assert_includes module_decl.to_source, "import std.core"
    assert_includes module_decl.to_source, "import std.memory"
    assert_includes module_decl.to_source, "import math"
    assert_includes module_decl.to_source, "int screen_width"
    assert_includes module_decl.to_source, "int screen_height"
  end
  
  def test_coroutine_with_await
    coroutine = coroutine_function("int", "async_task", [], block(
      co_await(call(id("async_operation"), "get", [])),
      co_return(int(42))
    ))
    
    assert_includes coroutine.to_source, "coroutine int async_task"
    assert_includes coroutine.to_source, "co_await"
    assert_includes coroutine.to_source, "co_return"
  end
end
