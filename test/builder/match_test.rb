# frozen_string_literal: true

require "test_helper"

class MatchTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_simple_match_expression
    ast = match_expr(id("shape"),
      arm("Circle", ["r"], binary("*", float(3.14), binary("*", id("r"), id("r")))),
      arm("Rect", ["w", "h"], binary("*", id("w"), id("h")))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Circle& circle) { auto [r] = circle; return 3.14 * r * r; },
        [&](const Rect& rect) { auto [w, h] = rect; return w * h; }
      }, shape)
    CPP
    assert_equal expected, cpp
  end

  def test_match_with_single_binding
    ast = match_expr(id("result"),
      arm("Ok", ["value"], id("value")),
      arm("Err", ["error"], id("error"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Ok& ok) { auto [value] = ok; return value; },
        [&](const Err& err) { auto [error] = err; return error; }
      }, result)
    CPP
    assert_equal expected, cpp
  end

  def test_match_with_no_bindings
    ast = match_expr(id("option"),
      arm("Some", [], int(1)),
      arm("None", [], int(0))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Some& some) { return 1; },
        [&](const None& none) { return 0; }
      }, option)
    CPP
    assert_equal expected, cpp
  end

  def test_match_with_complex_body
    ast = match_expr(id("event"),
      arm("Click", ["x", "y"], 
        call(id("process_click"), id("x"), id("y"))),
      arm("KeyPress", ["key"],
        ternary(binary("==", id("key"), char('"q"')), int(0), int(1))
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Click& click) { auto [x, y] = click; return process_click(x, y); },
        [&](const KeyPress& keypress) { auto [key] = keypress; return key == "q" ? 0 : 1; }
      }, event)
    CPP
    assert_equal expected, cpp
  end

  def test_match_in_function
    ast = function_decl("float", "area",
      [param("const Shape&", "shape")],
      block(
        return_stmt(match_expr(id("shape"),
          arm("Circle", ["r"], binary("*", float(3.14159), binary("*", id("r"), id("r")))),
          arm("Rect", ["w", "h"], binary("*", id("w"), id("h")))
        ))
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      float area(const Shape& shape ) {
      return std::visit(overloaded{
        [&](const Circle& circle) { auto [r] = circle; return 3.14159 * r * r; },
        [&](const Rect& rect) { auto [w, h] = rect; return w * h; }
      }, shape);
      }
    CPP
    assert_equal expected, cpp
  end

  def test_match_with_ownership_types
    ast = match_expr(id("data"),
      arm("Owned", ["ptr"], call(member(paren(deref(id("ptr"))), ".", "value"))),
      arm("Borrowed", ["ref"], call(member(id("ref"), ".", "size")))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Owned& owned) { auto [ptr] = owned; return (*ptr).value(); },
        [&](const Borrowed& borrowed) { auto [ref] = borrowed; return ref.size(); }
      }, data)
    CPP
    assert_equal expected, cpp
  end

  def test_match_with_result_option_types
    ast = match_expr(id("response"),
      arm("Success", ["data"], 
        match_expr(id("data"),
          arm("Some", [], id("value")),
          arm("None", [], int(-1))
        )),
      arm("Failure", ["error"], int(0))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Success& success) { auto [data] = success; return std::visit(overloaded{
        [&](const Some& some) { return value; },
        [&](const None& none) { return -1; }
      }, data); },
        [&](const Failure& failure) { auto [error] = failure; return 0; }
      }, response)
    CPP
    assert_equal expected, cpp
  end

  def test_match_roundtrip
    # Test DSL → C++ (pattern matching can't be parsed back, so just test generation)
    original_ast = match_expr(id("x"),
      arm("A", [], int(1))
    )
    
    cpp = original_ast.to_source
    expected = "std::visit(overloaded{\n  [&](const A& a) { return 1; }\n}, x)"
    assert_equal expected, cpp
  end

  def test_match_with_nested_expressions
    ast = match_expr(binary("+", id("a"), id("b")),
      arm("Circle", ["r"], 
        binary("+", 
          binary("*", float(2.0), float(3.14159)),
          binary("*", id("r"), id("r"))
        )),
      arm("Rect", ["w", "h"],
        binary("*", id("w"), id("h"))
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      std::visit(overloaded{
        [&](const Circle& circle) { auto [r] = circle; return 2.0 * 3.14159 + r * r; },
        [&](const Rect& rect) { auto [w, h] = rect; return w * h; }
      }, a + b)
    CPP
    assert_equal expected, cpp
  end
end
