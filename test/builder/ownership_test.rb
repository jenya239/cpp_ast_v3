# frozen_string_literal: true

require "test_helper"

class OwnershipTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_owned_type
    ast = owned("Vec2")
    cpp = ast.to_source
    assert_equal "std::unique_ptr<Vec2>", cpp
  end

  def test_borrowed_type
    ast = borrowed("Vec2")
    cpp = ast.to_source
    assert_equal "const Vec2&", cpp
  end

  def test_mut_borrowed_type
    ast = mut_borrowed("Vec2")
    cpp = ast.to_source
    assert_equal "Vec2&", cpp
  end

  def test_span_type
    ast = span_of("int")
    cpp = ast.to_source
    assert_equal "std::span<int>", cpp
  end

  def test_function_with_ownership_parameters
    ast = function_decl("void", "process",
      [param(borrowed("Vec2"), "v")],
      block(expr_stmt(call(member(id("v"), ".", "method"))))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      void process(const Vec2& v ){
      v.method();
      }
    CPP
    assert_equal expected, cpp
  end

  def test_function_with_multiple_ownership_types
    ast = function_decl("void", "process_all",
      [
        param(owned("Vec2"), "owned_vec"),
        param(borrowed("Vec2"), "borrowed_vec"),
        param(mut_borrowed("Vec2"), "mut_vec"),
        param(span_of("int"), "numbers")
      ],
      block(
        expr_stmt(call(member(id("owned_vec"), ".", "method"))),
        expr_stmt(call(member(id("borrowed_vec"), ".", "method"))),
        expr_stmt(call(member(id("mut_vec"), ".", "method"))),
        expr_stmt(call(member(id("numbers"), ".", "size")))
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      void process_all(std::unique_ptr<Vec2> owned_vec, const Vec2& borrowed_vec, Vec2& mut_vec, std::span<int> numbers ){
      owned_vec.method();
      borrowed_vec.method();
      mut_vec.method();
      numbers.size();
      }
    CPP
    assert_equal expected, cpp
  end

  def test_variable_declaration_with_ownership
    ast = program(
      var_decl(owned("Vec2"), "vec_ptr"),
      var_decl(borrowed("Vec2"), "vec_ref"),
      var_decl(mut_borrowed("Vec2"), "vec_mut_ref"),
      var_decl(span_of("int"), "numbers")
    )
    
    cpp = ast.to_source
    expected = <<~CPP
      std::unique_ptr<Vec2> vec_ptr;
      const Vec2& vec_ref;
      Vec2& vec_mut_ref;
      std::span<int> numbers;
    CPP
    assert_equal expected, cpp
  end

  def test_ownership_roundtrip
    # Test DSL → C++ (ownership types can't be parsed back, so just test generation)
    original_ast = function_decl("void", "test",
      [param(borrowed("int"), "x")],
      block(return_stmt(id("x")))
    )
    
    cpp = original_ast.to_source
    expected = "void test(const int& x ){\nreturn x;\n}"
    assert_equal expected, cpp
  end

  def test_nested_ownership_types
    ast = function_decl("void", "process_vectors",
      [param(span_of("std::unique_ptr<Vec2>"), "vectors")],
      block(
        for_stmt(
          "auto it = vectors.begin()",
          binary("!=", id("it"), call(member(id("vectors"), ".", "end"))),
          unary_post("++", id("it")),
          block(
            expr_stmt(call(member(paren(deref(id("it"))), ".", "method")))
          )
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      void process_vectors(std::span<std::unique_ptr<Vec2>> vectors ){
      for (auto it = vectors.begin(); it != vectors.end(); it++){
      (*it).method();
      }
      }
    CPP
    assert_equal expected, cpp
  end
end
