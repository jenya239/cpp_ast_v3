# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'tmpdir'

class GenericsE2ETest < Minitest::Test
  tag :slow  # Requires C++ compilation

  CLI = File.expand_path("../../bin/mlc", __dir__)

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

  # Test 1: Basic generic identity function
  def test_generic_identity_function
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn identity<T>(x: T) -> T = x

      fn main() -> i32 = do
        let a = identity(42)
        let b = identity(100)
        a + b
      end
    AUR
      assert_equal 142, status.exitstatus
    end
  end

  # Test 2: Generic pair type with accessors
  def test_generic_pair_type
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Pair<T, U> = {first: T, second: U}

      fn make_pair<T, U>(x: T, y: U) -> Pair<T, U> =
        {first: x, second: y}

      fn first<T, U>(p: Pair<T, U>) -> T = p.first
      fn second<T, U>(p: Pair<T, U>) -> U = p.second

      fn main() -> i32 = do
        let p = make_pair(10, 20)
        let a = first(p)
        let b = second(p)
        a + b
      end
    AUR
      assert_equal 30, status.exitstatus
    end
  end

  # Test 3: Generic swap function
  def test_generic_swap
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Pair<T, U> = {first: T, second: U}

      fn swap<T, U>(p: Pair<T, U>) -> Pair<U, T> =
        {first: p.second, second: p.first}

      fn main() -> i32 = do
        let p1 = {first: 5, second: 10}
        let p2 = swap(p1)
        p2.first + p2.second
      end
    AUR
      assert_equal 15, status.exitstatus
    end
  end

  # Test 4: Multiple type parameters
  def test_multiple_type_params
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn add_three<T, U, V>(a: T, b: U, c: V) -> i32 =
        a + b + c

      fn main() -> i32 = do
        add_three(10, 20, 30)
      end
    AUR
      assert_equal 60, status.exitstatus
    end
  end

  # Test 5: Generic array operations
  def test_generic_array_operations
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn first<T>(arr: T[]) -> T = arr[0]
      fn second<T>(arr: T[]) -> T = arr[1]

      fn main() -> i32 = do
        let numbers = [10, 20, 30]
        let a = first(numbers)
        let b = second(numbers)
        a + b
      end
    AUR
      assert_equal 30, status.exitstatus
    end
  end

  # Test 6: Nested generic types
  def test_nested_generic_types
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Box<T> = {value: T}
      type Pair<T, U> = {first: T, second: U}

      fn make_boxed_pair<T, U>(x: T, y: U) -> Pair<Box<T>, Box<U>> =
        {first: {value: x}, second: {value: y}}

      fn main() -> i32 = do
        let p = make_boxed_pair(100, 50)
        p.first.value + p.second.value
      end
    AUR
      assert_equal 150, status.exitstatus
    end
  end

  # Test 7: Generic with arrays of pairs
  def test_generic_array_of_pairs
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Pair<T, U> = {first: T, second: U}

      fn sum_pairs(pairs: Pair<i32, i32>[]) -> i32 =
        pairs[0].first + pairs[0].second + pairs[1].first + pairs[1].second

      fn main() -> i32 = do
        let pairs = [{first: 10, second: 20}, {first: 30, second: 40}]
        sum_pairs(pairs)
      end
    AUR
      assert_equal 100, status.exitstatus
    end
  end

  # Test 8: Generic triple type
  def test_generic_triple
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Triple<T, U, V> = {first: T, second: U, third: V}

      fn make_triple<T, U, V>(x: T, y: U, z: V) -> Triple<T, U, V> =
        {first: x, second: y, third: z}

      fn sum_triple(t: Triple<i32, i32, i32>) -> i32 =
        t.first + t.second + t.third

      fn main() -> i32 = do
        let t = make_triple(10, 20, 30)
        sum_triple(t)
      end
    AUR
      assert_equal 60, status.exitstatus
    end
  end

  # Test 9: Generic with conditionals
  def test_generic_with_conditionals
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn max<T>(a: T, b: T) -> T =
        if a > b then a else b

      fn main() -> i32 = do
        let result1 = max(10, 20)
        let result2 = max(50, 30)
        result1 + result2
      end
    AUR
      assert_equal 70, status.exitstatus
    end
  end

  # Test 10: Generic with let expressions
  def test_generic_with_let_expressions
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn compute<T>(x: T, y: T) -> T =
        let a = x + y
        let b = a + x
        b

      fn main() -> i32 = do
        compute(10, 20)
      end
    AUR
      assert_equal 40, status.exitstatus
    end
  end

  # Test 11: Deeply nested generics
  def test_deeply_nested_generics
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Box<T> = {value: T}

      fn triple_box<T>(x: T) -> Box<Box<Box<T>>> =
        {value: {value: {value: x}}}

      fn main() -> i32 = do
        let b = triple_box(42)
        b.value.value.value
      end
    AUR
      assert_equal 42, status.exitstatus
    end
  end

  # Test 12: Generic with array construction
  def test_generic_array_construction
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Pair<T, U> = {first: T, second: U}

      fn main() -> i32 = do
        let pairs: Pair<i32, i32>[] = [
          {first: 1, second: 2},
          {first: 3, second: 4},
          {first: 5, second: 6}
        ]
        pairs[0].first + pairs[1].second + pairs[2].first
      end
    AUR
      assert_equal 10, status.exitstatus
    end
  end

  # Test 13: Multiple generic functions chained
  def test_chained_generic_functions
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn double<T>(x: T) -> T = x + x
      fn triple<T>(x: T) -> T = x + x + x

      fn main() -> i32 = do
        let a = double(5)
        let b = triple(a)
        b
      end
    AUR
      assert_equal 30, status.exitstatus
    end
  end

  # Test 14: Generic with same type parameter used multiple times
  def test_same_type_param_multiple_uses
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Quad<T> = {a: T, b: T, c: T, d: T}

      fn sum_quad(q: Quad<i32>) -> i32 =
        q.a + q.b + q.c + q.d

      fn main() -> i32 = do
        let q = {a: 10, b: 20, c: 30, d: 40}
        sum_quad(q)
      end
    AUR
      assert_equal 100, status.exitstatus
    end
  end

  # Test 15: Generic array sum
  def test_generic_array_sum
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn get_sum<T>(arr: T[]) -> T =
        arr[0] + arr[1] + arr[2]

      fn main() -> i32 = do
        let nums = [10, 20, 30]
        get_sum(nums)
      end
    AUR
      assert_equal 60, status.exitstatus
    end
  end

  # Test 16: Generic wrapper type with println
  def test_generic_wrapper_with_output
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      import { to_string_i32 } from "Conv"

      type Wrapper<T> = {inner: T, metadata: i32}

      fn unwrap<T>(w: Wrapper<T>) -> T = w.inner

      fn main() -> i32 = do
        let w = {inner: 99, metadata: 42}
        let result = unwrap(w)
        println("Result: " + to_string_i32(result))
        result
      end
    AUR
      assert_match /Result: 99/, stdout
      assert_equal 99, status.exitstatus
    end
  end

  # Test 17: Complex nested structure
  def test_complex_nested_structure
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Inner<T> = {value: T}
      type Outer<T, U> = {left: Inner<T>, right: Inner<U>}

      fn extract<T, U>(o: Outer<T, U>) -> i32 =
        o.left.value + o.right.value

      fn main() -> i32 = do
        let o = {
          left: {value: 25},
          right: {value: 75}
        }
        extract(o)
      end
    AUR
      assert_equal 100, status.exitstatus
    end
  end

  # Test 18: Generic with boolean conditions
  def test_generic_boolean_select
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn select<T>(flag: bool, a: T, b: T) -> T =
        if flag then a else b

      fn main() -> i32 = do
        let r1 = select(true, 10, 20)
        let r2 = select(false, 30, 40)
        r1 + r2
      end
    AUR
      assert_equal 50, status.exitstatus
    end
  end

  # Test 19: Array of generic boxes
  def test_array_of_boxes
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      type Box<T> = {value: T}

      fn main() -> i32 = do
        let boxes: Box<i32>[] = [
          {value: 10},
          {value: 20},
          {value: 30}
        ]
        boxes[0].value + boxes[1].value + boxes[2].value
      end
    AUR
      assert_equal 60, status.exitstatus
    end
  end

  # Test 20: Generic with comparison
  def test_generic_comparison
    skip_unless_compiler_available

    run_aurora(<<~AUR) do |stdout, stderr, status|
      fn is_greater<T>(a: T, b: T) -> bool = a > b

      fn main() -> i32 = do
        let r1 = is_greater(10, 5)
        let r2 = is_greater(3, 8)
        let result = if r1 then 100 else 0
        let result2 = if r2 then 0 else 50
        result + result2
      end
    AUR
      assert_equal 150, status.exitstatus
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
