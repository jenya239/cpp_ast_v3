# frozen_string_literal: true

require "test_helper"

class AuroraFullTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_aurora_full_example
    # Comprehensive example using all Aurora DSL features
    ast = program(
      # Product type
      product_type("Point",
        field_def("x", "float"),
        field_def("y", "float")
      ),
      
      # Sum type
      sum_type("Shape",
        case_struct("Circle", field_def("center", "Point"), field_def("radius", "float")),
        case_struct("Rect", field_def("top_left", "Point"), field_def("width", "float"), field_def("height", "float"))
      ),
      
      # Function with ownership and Result types
      function_decl(result_of("float", "std::string"), "calculate_area",
        [param(borrowed("Shape"), "shape")],
        block(
          return_stmt(match_expr(id("shape"),
            arm("Circle", ["center", "radius"], 
              binary("*", float(3.14159), binary("*", id("radius"), id("radius")))),
            arm("Rect", ["top_left", "width", "height"],
              binary("*", id("width"), id("height")))
          ))
        )
      ),
      
      # Function with Option type
      function_decl(option_of("Point"), "find_center",
        [param(borrowed("Shape"), "shape")],
        block(
          return_stmt(match_expr(id("shape"),
            arm("Circle", ["center"], some(id("center"))),
            arm("Rect", ["top_left", "width", "height"],
              some(call(id("Point"), 
                binary("+", member(id("top_left"), ".", "x"), binary("/", id("width"), float(2.0))),
                binary("+", member(id("top_left"), ".", "y"), binary("/", id("height"), float(2.0)))
              )))
          ))
        )
      ),
      
      # Function with ownership types
      function_decl("void", "process_shapes",
        [param("std::span<std::unique_ptr<Shape>>", "shapes")],
        block(
          for_stmt(
            "auto it = shapes.begin()",
            binary("!=", id("it"), call(member(id("shapes"), ".", "end"))),
            unary_post("++", id("it")),
            block(
              expr_stmt(call(id("process_shape"), deref(id("it"))))
            )
          )
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP
      struct Point {
      float x;
      float y;
      };
      struct Circle {
      Point center;
      float radius;

      };
      struct Rect {
      Point top_left;
      float width;
      float height;

      };
      using Shape = std::variant<Circle, Rect>;
      std::expected<float, std::string> calculate_area(const Shape& shape) {
      return std::visit(overloaded{
        [&](const Circle& circle) { auto [center, radius] = circle; return 3.14159 * radius * radius; },
        [&](const Rect& rect) { auto [top_left, width, height] = rect; return width * height; }
      }, shape);
      }
      std::optional<Point> find_center(const Shape& shape) {
      return std::visit(overloaded{
        [&](const Circle& circle) { auto [center] = circle; return Some(center); },
        [&](const Rect& rect) { auto [top_left, width, height] = rect; return Some(Point(top_left.x + width / 2.0, top_left.y + height / 2.0)); }
      }, shape);
      }
      void process_shapes(std::span<std::unique_ptr<Shape>> shapes) {
      for (auto it = shapes.begin(); it != shapes.end(); it++) {
      process_shape(*it);
      }
      }
    CPP
    assert_equal expected, cpp
  end

  def test_aurora_with_nested_types
    # Example with nested Result/Option types
    ast = program(
      sum_type("Response",
        case_struct("Success", field_def("data", "std::optional<int>")),
        case_struct("Error", field_def("message", "std::string"))
      ),
      
      function_decl("int", "handle_response",
        [param(borrowed("Response"), "response")],
        block(
          return_stmt(match_expr(id("response"),
            arm("Success", ["data"],
              match_expr(id("data"),
                arm("Some", [], id("value")),
                arm("None", [], int(-1))
              )),
            arm("Error", ["message"], int(0))
          ))
        )
      )
    )
    
    cpp = ast.to_source
    expected = <<~CPP
      struct Success {
      std::optional<int> data;

      };
      struct Error {
      std::string message;

      };
      using Response = std::variant<Success, Error>;
      int handle_response(const Response& response) {
      return std::visit(overloaded{
        [&](const Success& success) { auto [data] = success; return std::visit(overloaded{
        [&](const Some& some) { return value; },
        [&](const None& none) { return -1; }
      }, data); },
        [&](const Error& error) { auto [message] = error; return 0; }
      }, response);
      }
    CPP
    assert_equal expected, cpp
  end

  def test_aurora_roundtrip_compatibility
    # Test that generated C++ can be parsed back (where possible)
    ast = program(
      product_type("Simple",
        field_def("value", "int")
      ),
      
      function_decl("int", "get_value",
        [param(borrowed("Simple"), "s")],
        block(
          return_stmt(member(id("s"), ".", "value"))
        )
      )
    )
    
    cpp = ast.to_source
    parsed_ast = CppAst.parse(cpp)
    
    # Should be able to parse back
    assert_equal cpp, parsed_ast.to_source
  end
end
