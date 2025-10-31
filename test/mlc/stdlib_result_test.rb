# frozen_string_literal: true

require_relative "../test_helper"

class StdlibResultTest < Minitest::Test
  def test_result_module_parses
    source = <<~AURORA
      import { Result, ok, err, is_ok } from "Result"

      fn test() -> bool =
        is_ok(ok(42))
    AURORA

    ast = MLC.parse(source)
    assert_equal 1, ast.imports.length
    assert_equal "Result", ast.imports.first.path
  end

  def test_result_type_definition
    source = <<~AURORA
      import { Result } from "Result"

      fn test() -> Result<i32, str> =
        Ok(42)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "Ok"
  end

  def test_result_is_ok_is_err
    source = <<~AURORA
      import { is_ok, is_err, ok, err } from "Result"

      fn test_ok() -> bool =
        is_ok(ok(42))

      fn test_err() -> bool =
        is_err(err("error"))
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "is_ok"
    assert_includes cpp, "is_err"
  end

  def test_result_unwrap
    source = <<~AURORA
      import { unwrap, ok, err } from "Result"

      fn test_unwrap_ok() -> i32 =
        unwrap(ok(42), 0)

      fn test_unwrap_err() -> i32 =
        unwrap(err("failed"), 99)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "unwrap"
  end

  def test_result_map
    source = <<~AURORA
      import { map, ok } from "Result"

      fn double(x: i32) -> i32 = x * 2

      fn test_map() -> Result<i32, str> =
        map(ok(21), double)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "map"
  end

  def test_result_map_err
    source = <<~AURORA
      import { map_err, err } from "Result"

      fn to_upper(s: str) -> str = s.upper()

      fn test() -> Result<i32, str> =
        map_err(err("error"), to_upper)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "map_err"
  end

  def test_result_and_then
    source = <<~AURORA
      import { and_then, ok, err } from "Result"

      fn safe_div(x: i32) -> Result<i32, str> =
        if x == 0 then err("div by zero") else ok(100 / x)

      fn test() -> Result<i32, str> =
        and_then(ok(10), safe_div)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "and_then"
  end

  def test_result_or_else
    source = <<~AURORA
      import { or_else, ok, err } from "Result"

      fn recover(e: str) -> Result<i32, bool> =
        ok(0)

      fn test() -> Result<i32, bool> =
        or_else(err("failed"), recover)
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "or_else"
  end
end
