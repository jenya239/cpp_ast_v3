# frozen_string_literal: true

require "test_helper"

class ResultOptionTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_result_type
    ast = result_of("int", "std::string")
    cpp = ast.to_source
    assert_equal "std::expected<int, std::string>", cpp
  end

  def test_option_type
    ast = option_of("int")
    cpp = ast.to_source
    assert_equal "std::optional<int>", cpp
  end

  def test_ok_constructor
    ast = ok(int(42))
    cpp = ast.to_source
    assert_equal "Ok(42)", cpp
  end

  def test_err_constructor
    ast = err(string('"division by zero"'))
    cpp = ast.to_source
    assert_equal 'Err("division by zero")', cpp
  end

  def test_some_constructor
    ast = some(int(42))
    cpp = ast.to_source
    assert_equal "Some(42)", cpp
  end

  def test_none_constructor
    ast = none
    cpp = ast.to_source
    assert_equal "None", cpp
  end

  def test_function_returning_result
    ast = function_decl(result_of("int", "std::string"), "divide",
      ["int a", "int b"],
      block(
        if_stmt(binary("==", id("b"), int(0)),
          block(return_stmt(err(string('"division by zero"')))),
          block(return_stmt(ok(binary("/", id("a"), id("b")))))
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::expected<int, std::string> divide(int a, int b ){
      if (b == 0){
      return Err("division by zero");
      } else {
      return Ok(a / b);
      }
      }
    CPP
    assert_equal expected, cpp
  end

  def test_function_returning_option
    ast = function_decl(option_of("int"), "safe_divide",
      ["int a", "int b"],
      block(
        if_stmt(binary("==", id("b"), int(0)),
          block(return_stmt(none)),
          block(return_stmt(some(binary("/", id("a"), id("b")))))
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::optional<int> safe_divide(int a, int b ){
      if (b == 0){
      return None;
      } else {
      return Some(a / b);
      }
      }
    CPP
    assert_equal expected, cpp
  end

  def test_variable_declaration_with_result_option
    ast = program(
      var_decl(result_of("int", "std::string"), "result"),
      var_decl(option_of("int"), "value"),
      var_decl(result_of("std::string", "int"), "text_result")
    )
    
    cpp = ast.to_source
    expected = <<~CPP
      std::expected<int, std::string> result;
      std::optional<int> value;
      std::expected<std::string, int> text_result;
    CPP
    assert_equal expected, cpp
  end

  def test_nested_result_option_types
    ast = function_decl("std::optional<std::expected<int, std::string>>", "complex_function",
      ["int x"],
      block(
        if_stmt(binary(">", id("x"), int(0)),
          block(return_stmt(some(ok(id("x"))))),
          block(return_stmt(some(err(string('"negative value"')))))
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::optional<std::expected<int, std::string>> complex_function(int x ){
      if (x > 0){
      return Some(Ok(x));
      } else {
      return Some(Err("negative value"));
      }
      }
    CPP
    assert_equal expected, cpp
  end

  def test_result_option_with_ownership
    ast = function_decl("std::expected<std::unique_ptr<Vec2>, std::string>", "create_vector",
      ["float x", "float y"],
      block(
        if_stmt(binary("||", binary("<", id("x"), float(0)), binary("<", id("y"), float(0))),
          block(return_stmt(err(string('"negative coordinates"')))),
          block(return_stmt(ok(call(id("Vec2"), id("x"), id("y")))))
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::expected<std::unique_ptr<Vec2>, std::string> create_vector(float x, float y){
      if (x < 0 || y < 0){
      return Err("negative coordinates");
      } else {
      return Ok(Vec2(x, y));
      }
      }
    CPP
    assert_equal expected, cpp
  end

  def test_result_option_roundtrip
    # Test DSL → C++ (Result/Option types can't be parsed back, so just test generation)
    original_ast = function_decl(result_of("int", "str"), "test",
      [],
      block(return_stmt(ok(int(42))))
    )
    
    cpp = original_ast.to_source
    expected = "std::expected<int, str> test( ){\nreturn Ok(42);\n}"
    assert_equal expected, cpp
  end
end
