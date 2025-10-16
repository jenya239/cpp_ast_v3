# frozen_string_literal: true

require_relative "../test_helper"

class DSLGeneratorTest < Minitest::Test
  include CppAst::Builder::DSL
  
  # Helper: C++ → AST → DSL code → eval → AST → C++ (roundtrip)
  def assert_cpp_to_dsl_roundtrip(cpp_source)
    # Parse C++ to AST
    ast1 = CppAst.parse(cpp_source)

    # Generate DSL code
    dsl_code = CppAst.to_dsl(ast1)

    # Eval DSL code to get new AST
    ast2 = eval(dsl_code)

    # Compare C++ outputs (normalize whitespace for comparison)
    cpp_output1 = ast1.to_source
    cpp_output2 = ast2.to_source

    # Normalize: ") {" vs "){" - both are valid
    normalized1 = cpp_output1.gsub(/\)\s*\{/, '){')
    normalized2 = cpp_output2.gsub(/\)\s*\{/, '){')

    assert_equal normalized1, normalized2,
      "Roundtrip failed:\nOriginal: #{cpp_output1.inspect}\nAfter DSL: #{cpp_output2.inspect}\n\nDSL Code:\n#{dsl_code}"
  end
  
  # Literals
  def test_int_literal
    assert_cpp_to_dsl_roundtrip("42;")
  end
  
  def test_string_literal
    assert_cpp_to_dsl_roundtrip("\"hello\";")
  end
  
  def test_char_literal
    assert_cpp_to_dsl_roundtrip("'a';")
  end
  
  # Identifiers
  def test_identifier
    assert_cpp_to_dsl_roundtrip("x;")
  end
  
  # Binary expressions
  def test_binary_addition
    assert_cpp_to_dsl_roundtrip("1 + 2;")
  end
  
  def test_binary_multiplication
    assert_cpp_to_dsl_roundtrip("x * y;")
  end
  
  def test_binary_assignment
    assert_cpp_to_dsl_roundtrip("x = 42;")
  end
  
  def test_nested_binary
    assert_cpp_to_dsl_roundtrip("2 * 3 + 4;")
  end
  
  # Unary expressions
  def test_unary_minus
    assert_cpp_to_dsl_roundtrip("-x;")
  end
  
  def test_unary_not
    assert_cpp_to_dsl_roundtrip("!flag;")
  end
  
  def test_unary_postfix
    assert_cpp_to_dsl_roundtrip("i++;")
  end
  
  # Parenthesized
  def test_parenthesized
    assert_cpp_to_dsl_roundtrip("(1 + 2) * 3;")
  end
  
  # Function calls
  def test_function_call_no_args
    assert_cpp_to_dsl_roundtrip("foo();")
  end
  
  def test_function_call_one_arg
    assert_cpp_to_dsl_roundtrip("bar(42);")
  end
  
  def test_function_call_multiple_args
    assert_cpp_to_dsl_roundtrip("baz(1, 2, 3);")
  end
  
  # Member access
  def test_member_access_dot
    assert_cpp_to_dsl_roundtrip("obj.field;")
  end
  
  def test_member_access_arrow
    assert_cpp_to_dsl_roundtrip("ptr->member;")
  end
  
  def test_member_access_scope
    assert_cpp_to_dsl_roundtrip("Class::static_member;")
  end
  
  # Return statement
  def test_return_statement
    assert_cpp_to_dsl_roundtrip("return 42;")
  end
  
  # Variable declaration
  def test_variable_declaration_simple
    assert_cpp_to_dsl_roundtrip("int x = 42;")
  end
  
  def test_variable_declaration_multiple
    assert_cpp_to_dsl_roundtrip("int x = 1, y = 2;")
  end
  
  # Block statement
  def test_block_empty
    assert_cpp_to_dsl_roundtrip("{\n}")
  end
  
  def test_block_single_statement
    assert_cpp_to_dsl_roundtrip("{\nreturn 0;\n}")
  end
  
  def test_block_multiple_statements
    assert_cpp_to_dsl_roundtrip("{\nx = 10;\ny = 20;\nreturn x + y;\n}")
  end
  
  # If statement
  def test_if_statement_simple
    assert_cpp_to_dsl_roundtrip("if (flag){\nreturn 1;\n}")
  end
  
  def test_if_else_statement
    assert_cpp_to_dsl_roundtrip("if (x > 0){\nreturn 1;\n} else {\nreturn 0;\n}")
  end
  
  # Function declaration
  def test_function_declaration_no_body
    assert_cpp_to_dsl_roundtrip("void foo();")
  end
  
  def test_function_declaration_with_body
    assert_cpp_to_dsl_roundtrip("int main(){\nreturn 0;\n}")
  end
  
  def test_function_declaration_with_params
    assert_cpp_to_dsl_roundtrip("int add(int a, int b){\nreturn a + b;\n}")
  end
  
  # Complex example
  def test_complex_function
    cpp = <<~CPP.chomp
      int factorial(int n){
      if (n <= 1){
      return 1;
      } else {
      return n * factorial(n - 1);
      }
      }
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  # Test DSL code generation output
  def test_generated_dsl_code_format
    cpp = "int main(){\nreturn 0;\n}\n"
    ast = CppAst.parse(cpp)
    dsl_code = CppAst.to_dsl(ast)
    
    # Check that DSL code is formatted
    assert_match(/program\(/, dsl_code)
    assert_match(/function_decl/, dsl_code)
    assert_match(/return_stmt/, dsl_code)
    assert_match(/\n/, dsl_code) # Has newlines
  end
  
  # Test fluent API directly
  def test_fluent_api_with_leading
    stmt = return_stmt(int(0)).with_leading("  ")
    assert_equal "  return 0;", stmt.to_source
  end
  
  def test_fluent_api_binary_operator_spacing
    expr = binary("+", int(1), int(2))
      .with_operator_prefix("")
      .with_operator_suffix("")
    
    ast = program(expr_stmt(expr))
    assert_equal "1+2;\n", ast.to_source
  end
  
  def test_fluent_api_block_trailing
    block_stmt = block(
      return_stmt(int(0))
    ).with_statement_trailings(["\n\n"]) # Double newline
    
    ast = program(block_stmt)
    assert_equal "{\nreturn 0;\n\n}\n", ast.to_source
  end
  
  # New constructs roundtrip tests
  def test_while_loop
    assert_cpp_to_dsl_roundtrip("while (x > 0){\nx--;\n}")
  end
  
  def test_do_while_loop
    assert_cpp_to_dsl_roundtrip("do {\ni++;\n} while (i < 10);")
  end
  
  def test_for_loop_classic
    assert_cpp_to_dsl_roundtrip("for (i = 0; i < 10; i++){\nfoo();\n}")
  end
  
  def test_for_loop_range_based
    assert_cpp_to_dsl_roundtrip("for (int x : vec){\nuse(x);\n}")
  end
  
  def test_array_subscript
    assert_cpp_to_dsl_roundtrip("arr[0];")
  end
  
  def test_ternary_operator
    assert_cpp_to_dsl_roundtrip("x > 0 ? x : -x;")
  end
  
  def test_break_statement
    assert_cpp_to_dsl_roundtrip("while (true){\nbreak;\n}")
  end
  
  def test_continue_statement
    assert_cpp_to_dsl_roundtrip("while (true){\ncontinue;\n}")
  end
  
  def test_switch_statement
    cpp = <<~CPP.chomp
      switch (x){
      case 1:
      foo();
      break;
      case 2:
      bar();
      break;
      default:
      baz();
      }
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  def test_enum_declaration
    assert_cpp_to_dsl_roundtrip("enum Color {Red, Green, Blue};")
  end
  
  def test_enum_class_declaration
    assert_cpp_to_dsl_roundtrip("enum class Status {OK, Error};")
  end
  
  def test_using_namespace
    assert_cpp_to_dsl_roundtrip("using namespace std;")
  end
  
  def test_using_alias
    assert_cpp_to_dsl_roundtrip("using MyInt = int;")
  end
  
  def test_brace_initializer
    assert_cpp_to_dsl_roundtrip("v = Vec{1, 2, 3};")
  end
  
  def test_namespace
    cpp = <<~CPP.chomp
      namespace test {
      void foo(){
      return 0;
      }
      }
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  def test_class_declaration
    cpp = <<~CPP.chomp
      class Point {
      int x;
      int y;
      };
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  def test_struct_declaration
    cpp = <<~CPP.chomp
      struct Vec2 {
      float x;
      float y;
      };
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  def test_access_specifier
    cpp = <<~CPP.chomp
      class Foo {
      public:
      int x;
      };
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  def test_lambda_expression
    assert_cpp_to_dsl_roundtrip("f = []() { x++; };")
  end
  
  def test_lambda_with_capture
    assert_cpp_to_dsl_roundtrip("f = [&x](int y) { return x + y; };")
  end
  
  def test_template_function
    cpp = <<~CPP.chomp
      template <typename T> T max(T a, T b){
      return a > b ? a : b;
      }
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
  
  def test_template_class
    cpp = <<~CPP.chomp
      template <typename T> class Array {
      T* data;
      };
    CPP
    assert_cpp_to_dsl_roundtrip(cpp)
  end
end

