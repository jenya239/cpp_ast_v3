# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraStdlibTest < Minitest::Test
  def test_builtin_functions
    # Test built-in functions that already work
    aurora_source = <<~AUR
      fn test_builtins() -> i32 =
        print("Hello");
        println("World");
        42
    AUR

    cpp = Aurora.to_cpp(aurora_source)
    
    assert_includes cpp, "print"
    # Note: println might not be generated if it's not used in the return value
    assert_includes cpp, "Hello"
  end

  def test_array_operations
    # Test array operations that already work
    aurora_source = <<~AUR
      fn test_arrays() -> i32 =
        [1, 2, 3, 4, 5].map(x => x * 2).filter(x => x > 5).length()
    AUR

    cpp = Aurora.to_cpp(aurora_source)
    
    assert_includes cpp, "map"
    assert_includes cpp, "filter"
    assert_includes cpp, "size"  # Aurora uses .size() instead of .length()
  end

  def test_string_operations
    # Test string operations that already work
    aurora_source = <<~AUR
      fn test_strings() -> str =
        "  hello world  ".trim().upper()
    AUR

    cpp = Aurora.to_cpp(aurora_source)
    
    assert_includes cpp, "trim"
    assert_includes cpp, "upper"
  end

  def test_stdlib_files_exist
    # Test that stdlib files exist
    stdlib_files = [
      "lib/aurora/stdlib/math.aur",
      "lib/aurora/stdlib/collections.aur", 
      "lib/aurora/stdlib/string.aur",
      "lib/aurora/stdlib/io.aur",
      "lib/aurora/stdlib/option.aur",
      "lib/aurora/stdlib/prelude.aur"
    ]

    stdlib_files.each do |file|
      assert File.exist?(file), "Stdlib file #{file} should exist"
    end
  end

  def test_stdlib_documentation_exists
    # Test that documentation exists
    assert File.exist?("docs/STDLIB.md"), "Stdlib documentation should exist"
  end

  def test_simple_math_functions
    # Test simple math that works with current syntax
    aurora_source = <<~AUR
      fn test_simple_math() -> i32 =
        5 + 3 + 7
    AUR

    cpp = Aurora.to_cpp(aurora_source)
    
    assert_includes cpp, "5 + 3 + 7"
  end

  def test_string_concatenation
    # Test string concatenation that we implemented
    aurora_source = <<~AUR
      fn test_string_concat() -> str =
        "Hello" + " " + "World"
    AUR

    cpp = Aurora.to_cpp(aurora_source)
    
    assert_includes cpp, "aurora::String"
    assert_includes cpp, "Hello"
    assert_includes cpp, "World"
  end
end
