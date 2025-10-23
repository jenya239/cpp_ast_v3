# frozen_string_literal: true

require_relative "../test_helper"

class StdlibArrayTest < Minitest::Test
  def test_array_module_parses
    source = <<~AURORA
      import { length, sum_i32 } from "Array"

      fn test() -> i32 = do
        let arr = [1, 2, 3]
        sum_i32(arr)
      end
    AURORA

    ast = Aurora.parse(source)
    assert_equal 1, ast.imports.length
    assert_equal "Array", ast.imports.first.path
  end

  def test_array_sum_i32
    source = <<~AURORA
      import { sum_i32 } from "Array"

      fn test() -> i32 = do
        let arr = [1, 2, 3, 4, 5]
        sum_i32(arr)
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "sum_i32"
  end

  def test_array_reverse_i32
    source = <<~AURORA
      import { reverse_i32 } from "Array"

      fn test() -> i32[] = do
        let arr = [1, 2, 3]
        reverse_i32(arr)
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "reverse_i32"
  end

  def test_array_contains_i32
    source = <<~AURORA
      import { contains_i32 } from "Array"

      fn test() -> bool = do
        let arr = [1, 2, 3]
        contains_i32(arr, 2)
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "contains_i32"
  end

  def test_array_take_drop_slice
    source = <<~AURORA
      import { take_i32, drop_i32, slice_i32 } from "Array"

      fn test() -> i32[] = do
        let arr = [1, 2, 3, 4, 5]
        let t = take_i32(arr, 3)
        let d = drop_i32(arr, 2)
        slice_i32(arr, 1, 4)
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "take_i32"
    assert_includes cpp, "drop_i32"
    assert_includes cpp, "slice_i32"
  end

  def test_array_min_max
    source = <<~AURORA
      import { min_i32, max_i32 } from "Array"

      fn test_int() -> i32 =
        min_i32([5, 2, 8, 1])

      fn test_int2() -> i32 =
        max_i32([5, 2, 8, 1])
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "min_i32"
    assert_includes cpp, "max_i32"
  end

  def test_array_min_max_f32
    source = <<~AURORA
      import { min_f32, max_f32 } from "Array"

      fn test_float() -> f32 =
        min_f32([5.5, 2.2, 8.8])

      fn test_float2() -> f32 =
        max_f32([5.5, 2.2, 8.8])
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "min_f32"
    assert_includes cpp, "max_f32"
  end

  def test_array_range
    source = <<~AURORA
      import { range } from "Array"

      fn test() -> i32[] =
        range(0, 10)
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "range"
  end

  def test_array_join_strings
    source = <<~AURORA
      import { join_strings } from "Array"

      fn test() -> str = do
        let words = ["hello", "world"]
        join_strings(words, " ")
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "join_strings"
  end

  def test_array_reverse_str
    source = <<~AURORA
      import { reverse_str } from "Array"

      fn test() -> str[] = do
        let words = ["a", "b", "c"]
        reverse_str(words)
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "reverse_str"
  end

  def test_array_contains_str
    source = <<~AURORA
      import { contains_str } from "Array"

      fn test() -> bool = do
        let words = ["foo", "bar", "baz"]
        contains_str(words, "bar")
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "contains_str"
  end
end
