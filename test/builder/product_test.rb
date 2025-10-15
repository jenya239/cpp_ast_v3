# frozen_string_literal: true

require "test_helper"

class ProductTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_simple_product_type
    ast = product_type("Vec2",
      field_def("x", "float"),
      field_def("y", "float")
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Vec2 {
      float x;
      float y;
      };
    CPP
    assert_equal expected, cpp
  end

  def test_product_type_with_different_types
    ast = product_type("Person",
      field_def("name", "std::string"),
      field_def("age", "int"),
      field_def("height", "float")
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Person {
      std::string name;
      int age;
      float height;
      };
    CPP
    assert_equal expected, cpp
  end

  def test_product_type_with_ownership_types
    ast = product_type("Container",
      field_def("data", "std::unique_ptr<int>"),
      field_def("size", "size_t"),
      field_def("ref", "const std::string&")
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Container {
      std::unique_ptr<int> data;
      size_t size;
      const std::string& ref;
      };
    CPP
    assert_equal expected, cpp
  end

  def test_product_type_with_result_option_types
    ast = product_type("Result",
      field_def("value", "std::optional<int>"),
      field_def("error", "std::expected<std::string, int>")
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Result {
      std::optional<int> value;
      std::expected<std::string, int> error;
      };
    CPP
    assert_equal expected, cpp
  end

  def test_product_type_with_nested_types
    ast = product_type("Complex",
      field_def("real", "float"),
      field_def("imag", "float"),
      field_def("metadata", "std::map<std::string, std::string>")
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Complex {
      float real;
      float imag;
      std::map<std::string, std::string> metadata;
      };
    CPP
    assert_equal expected, cpp
  end

  def test_product_type_with_simple_fields
    ast = product_type("Point",
      "int x;",
      "int y;"
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Point {
      int x;
      int y;
      };
    CPP
    assert_equal expected, cpp
  end

  def test_product_type_roundtrip
    # Test DSL → C++ → Parser → AST
    original_ast = product_type("Test",
      field_def("value", "int")
    )
    
    cpp = original_ast.to_source
    parsed_ast = CppAst.parse(cpp)
    
    # Should be able to parse back
    assert_equal cpp, parsed_ast.to_source
  end

  def test_product_type_in_function
    ast = program(
      product_type("Vec2",
        field_def("x", "float"),
        field_def("y", "float")
      ),
      function_decl("float", "length",
        [param("const Vec2&", "v")],
        block(
          return_stmt(
            call(id("sqrt"),
              binary("+",
                binary("*", member(id("v"), ".", "x"), member(id("v"), ".", "x")),
                binary("*", member(id("v"), ".", "y"), member(id("v"), ".", "y"))
              )
            )
          )
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP
      struct Vec2 {
      float x;
      float y;
      };
      float length(const Vec2& v ) {
      return sqrt(v.x * v.x + v.y * v.y);
      }
    CPP
    assert_equal expected, cpp
  end
end
