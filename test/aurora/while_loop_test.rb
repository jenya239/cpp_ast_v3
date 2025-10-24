# frozen_string_literal: true

require_relative '../test_helper'

class WhileLoopUnitTypeTest < Minitest::Test
  def test_while_loop_no_dummy_values
    source = <<~AURORA
      fn test() -> i32 = do
        let mut sum = 0;
        let mut i = 0;

        while i < 5 do
          sum = sum + i;
          i = i + 1
        end;

        sum
      end

      fn main() -> i32 = test()
    AURORA

    cpp = Aurora.compile(source).to_source

    # Verify clean while loop generation - no dummy values
    assert_includes cpp, "while (i < 5)"

    # Should not contain dummy values or ternary operators
    refute_includes cpp, "? (", "Should not use ternary operator for while"
    refute_includes cpp, ", 0)", "Should not have dummy values"
  end

  def test_while_loop_with_block_body
    source = <<~AURORA
      fn test() -> i32 = do
        let mut count = 0;

        while count < 3 do
          count = count + 1;
          count = count + 1
        end;

        count
      end

      fn main() -> i32 = test()
    AURORA

    cpp = Aurora.compile(source).to_source

    # Verify block-style while loop
    assert_includes cpp, "while (count < 3)"
    assert_includes cpp, "count = count + 1;"
  end

  def test_while_loop_empty_body
    source = <<~AURORA
      fn test() -> i32 = do
        let mut x = 0;

        while x < 0 do
        end;

        42
      end

      fn main() -> i32 = test()
    AURORA

    cpp = Aurora.compile(source).to_source

    # Even empty while should compile cleanly
    assert_includes cpp, "while (x < 0)"
  end

  def test_while_loop_nested
    source = <<~AURORA
      fn test() -> i32 = do
        let mut x = 0;
        let mut y = 0;

        while x < 2 do
          y = 0;
          while y < 3 do
            y = y + 1
          end;
          x = x + 1
        end;

        x + y
      end

      fn main() -> i32 = test()
    AURORA

    cpp = Aurora.compile(source).to_source

    # Should have nested while loops
    assert_includes cpp, "while (x < 2)"
    assert_includes cpp, "while (y < 3)"

    # No dummy values in nested loops
    refute_includes cpp, ", 0)", "Should not have dummy values in nested loops"
  end
end
