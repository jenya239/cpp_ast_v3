# frozen_string_literal: true

require_relative "../test_helper"

class StdlibConvTest < Minitest::Test
  def test_conv_module_parses
    source = <<~AURORA
      import { to_string_i32, parse_i32 } from "Conv"

      fn test() -> str =
        to_string_i32(42)
    AURORA

    ast = MLC.parse(source)
    assert_equal 1, ast.imports.length
    assert_equal "Conv", ast.imports.first.path
  end

  def test_to_string_i32
    source = <<~AURORA
      import { to_string_i32 } from "Conv"

      fn test() -> str =
        to_string_i32(42)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "to_string_i32"
  end

  def test_to_string_f32
    source = <<~AURORA
      import { to_string_f32 } from "Conv"

      fn test() -> str =
        to_string_f32(3.14)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "to_string_f32"
  end

  def test_to_string_bool
    source = <<~AURORA
      import { to_string_bool } from "Conv"

      fn test() -> str =
        to_string_bool(true)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "to_string_bool"
  end

  def test_parse_i32
    source = <<~AURORA
      import { parse_i32 } from "Conv"

      fn test() -> i32 =
        parse_i32("42")
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "parse_i32"
  end

  def test_parse_f32
    source = <<~AURORA
      import { parse_f32 } from "Conv"

      fn test() -> f32 =
        parse_f32("3.14")
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "parse_f32"
  end

  def test_parse_bool
    source = <<~AURORA
      import { parse_bool } from "Conv"

      fn test() -> bool =
        parse_bool("true")
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "parse_bool"
  end

  def test_helper_functions
    source = <<~AURORA
      import { int_to_str, str_to_int } from "Conv"

      fn test() -> str =
        int_to_str(str_to_int("123"))
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "int_to_str"
    assert_includes cpp, "str_to_int"
  end

  def test_with_do_blocks
    source = <<~AURORA
      import { parse_i32, to_string_i32 } from "Conv"

      fn process(s: str) -> str = do
        let num = parse_i32(s);
        let doubled = num * 2;
        to_string_i32(doubled)
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "parse_i32"
    assert_includes cpp, "to_string_i32"
  end

  def test_combined_with_string_module
    source = <<~AURORA
      import { trim } from "String"
      import { parse_i32, to_string_i32 } from "Conv"

      fn parse_and_format(s: str) -> str = do
        let cleaned = trim(s);
        let num = parse_i32(cleaned);
        to_string_i32(num + 1)
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "trim"
    assert_includes cpp, "parse_i32"
    assert_includes cpp, "to_string_i32"
  end
end
