# frozen_string_literal: true

require_relative "../test_helper"

class RoundtripTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def setup
    CppAst.formatting_mode = :lossless
  end
  
  def teardown
    CppAst.formatting_mode = :pretty
  end
  
  def assert_roundtrip_ast(ast1)
    cpp = ast1.to_source
    ast2 = CppAst.parse(cpp)
    
    # Сравниваем через to_source, так как trivia может отличаться
    assert_equal cpp, ast2.to_source,
      "Roundtrip failed:\nOriginal AST: #{cpp.inspect}\nRe-parsed:    #{ast2.to_source.inspect}"
  end
  
  # Literals
  def test_int_literal
    ast = program(
      expr_stmt(int(42))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_float_literal
    ast = program(
      expr_stmt(float(3.14))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_string_literal
    ast = program(
      expr_stmt(string('"hello"'))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_char_literal
    ast = program(
      expr_stmt(char("'a'"))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Identifiers
  def test_identifier
    ast = program(
      expr_stmt(id("x"))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Binary expressions
  def test_binary_addition
    ast = program(
      expr_stmt(binary("+", int(1), int(2)))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_binary_multiplication
    ast = program(
      expr_stmt(binary("*", id("x"), id("y")))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_binary_assignment
    ast = program(
      expr_stmt(binary("=", id("x"), int(42)))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_nested_binary
    ast = program(
      expr_stmt(
        binary("+",
          binary("*", int(2), int(3)),
          int(4)
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Unary expressions
  def test_unary_minus
    ast = program(
      expr_stmt(unary("-", id("x")))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_unary_not
    ast = program(
      expr_stmt(unary("!", id("flag")))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_unary_postfix
    ast = program(
      expr_stmt(unary_post("++", id("i")))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Parenthesized expressions
  def test_parenthesized
    ast = program(
      expr_stmt(
        binary("*", paren(binary("+", int(1), int(2))), int(3))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Function calls
  def test_function_call_no_args
    ast = program(
      expr_stmt(call(id("foo")))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_function_call_one_arg
    ast = program(
      expr_stmt(call(id("bar"), int(42)))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_function_call_multiple_args
    ast = program(
      expr_stmt(call(id("baz"), int(1), int(2), int(3)))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Member access
  def test_member_access_dot
    ast = program(
      expr_stmt(member(id("obj"), ".", "field"))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_member_access_arrow
    ast = program(
      expr_stmt(member(id("ptr"), "->", "member"))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_member_access_scope
    ast = program(
      expr_stmt(member(id("Class"), "::", "static_member"))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_chained_member_access
    ast = program(
      expr_stmt(
        member(
          member(id("obj"), ".", "inner"),
          ".",
          "field"
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Array subscript
  def test_array_subscript
    ast = program(
      expr_stmt(subscript(id("arr"), int(0)))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_nested_subscript
    ast = program(
      expr_stmt(subscript(subscript(id("matrix"), int(0)), int(1)))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Ternary operator
  def test_ternary
    ast = program(
      expr_stmt(
        ternary(
          binary(">", id("x"), int(0)),
          id("x"),
          unary("-", id("x"))
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Return statement
  def test_return_statement
    ast = program(
      return_stmt(int(42))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_return_expression
    ast = program(
      return_stmt(binary("+", id("x"), id("y")))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Variable declaration
  def test_variable_declaration_simple
    ast = program(
      var_decl("int", "x = 42")
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_variable_declaration_multiple
    ast = program(
      var_decl("int", "x = 1", "y = 2")
    )
    assert_roundtrip_ast(ast)
  end
  
  # Block statement
  def test_block_empty
    ast = program(
      block()
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_block_single_statement
    ast = program(
      block(
        return_stmt(int(0))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_block_multiple_statements
    ast = program(
      block(
        expr_stmt(binary("=", id("x"), int(10))),
        expr_stmt(binary("=", id("y"), int(20))),
        return_stmt(binary("+", id("x"), id("y")))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # If statement
  def test_if_statement_simple
    ast = program(
      if_stmt(
        id("flag"),
        block(return_stmt(int(1)))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_if_else_statement
    ast = program(
      if_stmt(
        binary(">", id("x"), int(0)),
        block(return_stmt(int(1))),
        block(return_stmt(int(0)))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # While statement
  def test_while_statement
    ast = program(
      while_stmt(
        binary("<", id("i"), int(10)),
        block(expr_stmt(unary_post("++", id("i"))))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # For statement
  def test_for_statement
    ast = program(
      for_stmt(
        binary("=", id("i"), int(0)),
        binary("<", id("i"), int(10)),
        unary_post("++", id("i")),
        block(expr_stmt(call(id("foo"))))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Function declaration
  def test_function_declaration_no_body
    ast = program(
      function_decl("void", "foo", [])
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_function_declaration_with_body
    ast = program(
      function_decl(
        "int",
        "main",
        [],
        block(return_stmt(int(0)))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_function_declaration_with_params
    ast = program(
      function_decl(
        "int",
        "add",
        ["int a", "int b"],
        block(return_stmt(binary("+", id("a"), id("b"))))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Complex example: complete function
  def test_complex_function
    ast = program(
      function_decl(
        "int",
        "factorial",
        ["int n"],
        block(
          if_stmt(
            binary("<=", id("n"), int(1)),
            block(return_stmt(int(1))),
            block(
              return_stmt(
                binary("*",
                  id("n"),
                  call(id("factorial"), binary("-", id("n"), int(1)))
                )
              )
            )
          )
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Array subscript
  def test_array_subscript
    ast = program(
      expr_stmt(subscript(id("arr"), int(0)))
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_nested_array_subscript
    ast = program(
      expr_stmt(subscript(subscript(id("matrix"), int(0)), int(1)))
    )
    assert_roundtrip_ast(ast)
  end
  
  # Ternary operator  
  def test_ternary_operator
    ast = program(
      expr_stmt(
        ternary(
          binary(">", id("x"), int(0)),
          id("x"),
          unary("-", id("x"))
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Do-while loop
  def test_do_while_loop
    ast = program(
      do_while_stmt(
        block(expr_stmt(unary_post("++", id("i")))),
        binary("<", id("i"), int(10))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Switch statement
  def test_switch_statement
    ast1 = program(
      switch_stmt(
        id("x"),
        case_clause(int(1), expr_stmt(call(id("foo"))), break_stmt),
        case_clause(int(2), expr_stmt(call(id("bar"))), break_stmt),
        default_clause(expr_stmt(call(id("baz"))))
      )
    ).with_statement_trailings([""])
    cpp1 = ast1.to_source
    ast2 = CppAst.parse(cpp1)
    cpp2 = ast2.to_source
    
    # Roundtrip test - both should produce same C++
    assert_equal cpp1, cpp2,
      "Roundtrip failed:\nOriginal: #{cpp1.inspect}\nAfter parse: #{cpp2.inspect}"
  end
  
  # Enum declaration
  def test_enum_declaration
    ast = program(
      enum_decl("Color", "Red, Green, Blue")
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_enum_class_declaration
    ast = program(
      enum_decl("Color", "Red = 0, Green = 1", class_keyword: "class")
    )
    assert_roundtrip_ast(ast)
  end
  
  # Using declarations
  def test_using_namespace
    ast = program(
      using_namespace("std")
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_using_alias
    ast = program(
      using_alias("MyInt", "int")
    )
    assert_roundtrip_ast(ast)
  end
  
  # Access specifier
  def test_access_specifier
    ast = program(
      class_decl("Foo",
        access_spec("public"),
        var_decl("int", "x")
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Brace initializer
  def test_brace_initializer
    ast = program(
      expr_stmt(
        binary("=", id("v"), brace_init(id("Vec"), int(1), int(2), int(3)))
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Namespace
  def test_namespace
    ast = program(
      namespace_decl("test",
        block(
          function_decl("void", "foo", [], block(return_stmt(int(0))))
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Simple class
  def test_simple_class
    ast = program(
      class_decl("Point",
        var_decl("int", "x"),
        var_decl("int", "y")
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Simple struct
  def test_simple_struct
    ast = program(
      struct_decl("Vec2",
        var_decl("float", "x"),
        var_decl("float", "y")
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  # Lambda expression
  # Note: Lambda body/params stored as text by parser, trivia not preserved perfectly
  # Roundtrip tests for lambda are in dsl_generator_test (C++ → DSL → C++)
  
  # Template declaration
  def test_template_function
    ast = program(
      template_decl("typename T",
        function_decl("T", "max", ["T a", "T b"],
          block(
            return_stmt(
              ternary(binary(">", id("a"), id("b")), id("a"), id("b"))
            )
          )
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
  
  def test_template_class
    ast = program(
      template_decl("typename T",
        class_decl("Array",
          var_decl("T*", "data")
        )
      )
    )
    assert_roundtrip_ast(ast)
  end
end

