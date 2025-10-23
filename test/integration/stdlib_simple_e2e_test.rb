# frozen_string_literal: true

require_relative "../test_helper"
require "open3"
require "tmpdir"

class StdlibSimpleE2ETest < Minitest::Test
  tag :slow  # Mark as slow test (requires C++ compilation)

  CLI = File.expand_path("../../bin/aurora", __dir__)

  # Helper to run Aurora program and check result
  def run_aurora(source_code, &block)
    Dir.mktmpdir do |dir|
      source = File.join(dir, "test.aur")
      File.write(source, source_code)
      stdout, stderr, status = Open3.capture3(CLI, source)

      refute_includes stderr, "error:", "Compilation failed: #{stderr}"
      yield stdout, stderr, status if block_given?
    end
  end

  # Array stdlib E2E tests

  def test_array_sum_i32
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { sum_i32 } from "Array"

      fn main() -> i32 = do
        let nums = [1, 2, 3, 4, 5]
        sum_i32(nums)
      end
    AUR
      assert_equal 15, status.exitstatus
    end
  end

  def test_array_range
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { range, sum_i32 } from "Array"

      fn main() -> i32 = do
        let nums = range(1, 11)
        sum_i32(nums)
      end
    AUR
      assert_equal 55, status.exitstatus  # 1+2+...+10 = 55
    end
  end

  def test_array_min_max
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { min_i32, max_i32 } from "Array"
      import { to_string_i32 } from "Conv"

      fn main() -> i32 = do
        let nums = [5, 2, 8, 1, 9]
        let min_val = min_i32(nums)
        let max_val = max_i32(nums)
        println("Min: " + to_string_i32(min_val))
        println("Max: " + to_string_i32(max_val))
        0
      end
    AUR
      assert_match /Min: 1/, stdout
      assert_match /Max: 9/, stdout
    end
  end

  # Conv stdlib E2E tests

  def test_conv_parse_i32
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { parse_i32 } from "Conv"

      fn main() -> i32 = do
        let num = parse_i32("42")
        num
      end
    AUR
      assert_equal 42, status.exitstatus
    end
  end

  def test_conv_to_string
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { to_string_i32, to_string_f32 } from "Conv"

      fn main() -> i32 = do
        let s1 = to_string_i32(42)
        let s2 = to_string_f32(3.14)
        println(s1)
        println(s2)
        0
      end
    AUR
      assert_match /42/, stdout
      assert_match /3.14/, stdout
    end
  end

  # Math stdlib E2E tests

  def test_math_abs
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { abs } from "Math"

      fn main() -> i32 = do
        let a = abs(-42)
        a
      end
    AUR
      assert_equal 42, status.exitstatus
    end
  end

  def test_math_min_max
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { min, max } from "Math"

      fn main() -> i32 = do
        let a = min(10, 20)
        let b = max(10, 20)
        a + b
      end
    AUR
      assert_equal 30, status.exitstatus  # 10 + 20
    end
  end

  # String operations (using String methods, not stdlib)

  def test_string_operations
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn main() -> i32 = do
        let text = "  Hello World  "
        let trimmed = text.trim()
        let upper = trimmed.upper()
        println(upper)
        0
      end
    AUR
      assert_match /HELLO WORLD/, stdout
    end
  end

  private

  def skip_unless_compiler_available
    return if @compiler_checked

    @compiler_checked = true
    compiler = ENV.fetch("CXX", "g++")
    available = system("#{compiler} --version > /dev/null 2>&1")
    skip "C++ compiler (#{compiler}) not available" unless available
  end
end
