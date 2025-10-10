# frozen_string_literal: true

require_relative "../test_helper"

class ControlFlowRoundtripTest < Minitest::Test
  # If statements
  def test_if_simple
    assert_roundtrip "if (x) y;"
  end
  
  def test_if_with_block
    assert_roundtrip "if (x) { y; }"
  end
  
  def test_if_else
    assert_roundtrip "if (x) y; else z;"
  end
  
  def test_if_else_with_blocks
    assert_roundtrip "if (x) { y; } else { z; }"
  end
  
  def test_if_with_whitespace
    assert_roundtrip "if (x) {\n  y;\n}\n"
  end
  
  def test_nested_if
    assert_roundtrip "if (x) if (y) z;"
  end
  
  # While loops
  def test_while_simple
    assert_roundtrip "while (x) y;"
  end
  
  def test_while_with_block
    assert_roundtrip "while (x) { y; }"
  end
  
  def test_while_with_whitespace
    assert_roundtrip "while (x) {\n  y;\n}\n"
  end
  
  # Do-while loops
  def test_do_while_simple
    assert_roundtrip "do x; while (y);"
  end
  
  def test_do_while_with_block
    assert_roundtrip "do { x; } while (y);"
  end
  
  # For loops
  def test_for_simple
    assert_roundtrip "for (i = 0; i < 10; i++) x;"
  end
  
  def test_for_with_block
    assert_roundtrip "for (i = 0; i < 10; i++) { x; }"
  end
  
  def test_for_empty_parts
    assert_roundtrip "for (;;) x;"
  end
  
  def test_for_some_empty
    assert_roundtrip "for (; i < 10; i++) x;"
  end
  
  # Break/Continue
  def test_break
    assert_roundtrip "break;"
  end
  
  def test_continue
    assert_roundtrip "continue;"
  end
  
  def test_while_with_break
    assert_roundtrip "while (x) { if (y) break; }"
  end
  
  # Switch statements
  def test_switch_simple
    assert_roundtrip "switch (x) { case 1: y; break; }"
  end
  
  def test_switch_with_default
    assert_roundtrip "switch (x) { case 1: y; break; default: z; break; }"
  end
  
  def test_switch_multiple_cases
    assert_roundtrip "switch (x) { case 1: a; break; case 2: b; break; }"
  end
  
  # Complex combinations
  def test_if_with_for
    assert_roundtrip "if (x) for (i = 0; i < 10; i++) y;"
  end
  
  def test_nested_while
    assert_roundtrip "while (x) while (y) z;"
  end
  
  def test_for_with_nested_if
    assert_roundtrip "for (i = 0; i < 10; i++) if (x) y;"
  end
end

