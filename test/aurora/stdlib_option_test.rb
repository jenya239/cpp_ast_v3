# frozen_string_literal: true

require_relative "../test_helper"

class StdlibOptionTest < Minitest::Test
  def test_option_module_parses
    source = <<~AURORA
      import { Option, some, none, is_some } from "Option"

      fn test() -> bool =
        is_some(some(42))
    AURORA

    ast = Aurora.parse(source)
    assert_equal 1, ast.imports.length
    assert_equal "Option", ast.imports.first.path
  end

  def test_option_type_definition
    source = <<~AURORA
      import { Option } from "Option"

      fn test() -> Option<i32> =
        Some(42)
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "Some"
  end

  def test_option_is_some_is_none
    source = <<~AURORA
      import { is_some, is_none, some, none } from "Option"

      fn test_some() -> bool =
        is_some(some(42))

      fn test_none() -> bool =
        is_none(none())
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "is_some"
    assert_includes cpp, "is_none"
  end

  def test_option_unwrap
    source = <<~AURORA
      import { unwrap, some, none } from "Option"

      fn test_unwrap_some() -> i32 =
        unwrap(some(42), 0)

      fn test_unwrap_none() -> i32 =
        unwrap(none(), 99)
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "unwrap"
  end

  def test_option_map
    source = <<~AURORA
      import { map, some } from "Option"

      fn double(x: i32) -> i32 = x * 2

      fn test_map() -> Option<i32> =
        map(some(21), double)
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "map"
  end

  def test_option_and_then
    source = <<~AURORA
      import { and_then, some, none } from "Option"

      fn safe_div(x: i32) -> Option<i32> =
        if x == 0 then none() else some(100 / x)

      fn test() -> Option<i32> =
        and_then(some(10), safe_div)
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "and_then"
  end

  def test_option_or_else
    source = <<~AURORA
      import { or_else, some, none } from "Option"

      fn test() -> Option<i32> =
        or_else(none(), some(42))
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "or_else"
  end
end
