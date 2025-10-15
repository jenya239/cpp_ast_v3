# frozen_string_literal: true

require "test_helper"

class SumTypeTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_simple_sum_type
    ast = sum_type("Shape",
      case_struct("Circle", field_def("float", "r")),
      case_struct("Rect", field_def("float", "w"), field_def("float", "h"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Circle {
      float r;

      };
      struct Rect {
      float w;
      float h;

      };
      using Shape = std::variant<Circle, Rect>;
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_with_single_field_cases
    ast = sum_type("Result",
      case_struct("Ok", field_def("int", "value")),
      case_struct("Err", field_def("std::string", "msg"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Ok {
      int value;

      };
      struct Err {
      std::string msg;

      };
      using Result = std::variant<Ok, Err>;
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_with_multiple_fields
    ast = sum_type("Event",
      case_struct("Click", field_def("int", "x"), field_def("int", "y")),
      case_struct("KeyPress", field_def("char", "key")),
      case_struct("Resize", field_def("int", "width"), field_def("int", "height"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Click {
      int x;
      int y;

      };
      struct KeyPress {
      char key;

      };
      struct Resize {
      int width;
      int height;

      };
      using Event = std::variant<Click, KeyPress, Resize>;
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_with_ownership_types
    ast = sum_type("Data",
      case_struct("Owned", field_def("std::unique_ptr<int>", "ptr")),
      case_struct("Borrowed", field_def("const std::string&", "ref"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Owned {
      std::unique_ptr<int> ptr;

      };
      struct Borrowed {
      const std::string& ref;

      };
      using Data = std::variant<Owned, Borrowed>;
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_with_result_option_types
    ast = sum_type("Response",
      case_struct("Success", field_def("std::optional<int>", "data")),
      case_struct("Failure", field_def("std::expected<std::string, int>", "error"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Success {
      std::optional<int> data;

      };
      struct Failure {
      std::expected<std::string, int> error;

      };
      using Response = std::variant<Success, Failure>;
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_with_simple_fields
    ast = sum_type("Color",
      case_struct("RGB", "int r;", "int g;", "int b;"),
      case_struct("HSV", "float h;", "float s;", "float v;")
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct RGB {
      int r;
      int g;
      int b;

      };
      struct HSV {
      float h;
      float s;
      float v;

      };
      using Color = std::variant<RGB, HSV>;
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_roundtrip
    # Test DSL → C++ → Parser → AST
    original_ast = sum_type("Test",
      case_struct("A", field_def("int", "x"))
    )
    
    cpp = original_ast.to_source
    parsed_ast = CppAst.parse(cpp)
    
    # Should be able to parse back
    assert_equal cpp, parsed_ast.to_source
  end

  def test_sum_type_in_function
    ast = program(
      sum_type("Shape",
        case_struct("Circle", field_def("float", "r")),
        case_struct("Rect", field_def("float", "w"), field_def("float", "h"))
      ),
      function_decl("float", "area",
        [param("const Shape&", "shape")],
        block(
          # This would need pattern matching to be complete
          return_stmt(float(0.0))
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP
      struct Circle {
      float r;

      };
      struct Rect {
      float w;
      float h;

      };
      using Shape = std::variant<Circle, Rect>;
      float area(const Shape& shape ){
      return 0.0;
      }
    CPP
    assert_equal expected, cpp
  end

  def test_sum_type_with_nested_types
    ast = sum_type("ComplexShape",
      case_struct("Circle", field_def("std::pair<float, float>", "center"), field_def("float", "radius")),
      case_struct("Polygon", field_def("std::vector<std::pair<float, float>>", "points"))
    )
    
    cpp = ast.to_source
    expected = <<~CPP.strip
      struct Circle {
      std::pair<float, float> center;
      float radius;

      };
      struct Polygon {
      std::vector<std::pair<float, float>> points;

      };
      using ComplexShape = std::variant<Circle, Polygon>;
    CPP
    assert_equal expected, cpp
  end
end
