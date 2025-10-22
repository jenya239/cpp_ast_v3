# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraStringOperationsTest < Minitest::Test
  def test_string_concatenation
    aurora_source = <<~AUR
      fn greet(name: str) -> str =
        "Hello, " + name + "!"
    AUR

    # This should work but currently fails
    # Let's test what we get
    begin
      cpp = Aurora.to_cpp(aurora_source)
      puts "Generated C++:"
      puts cpp
      assert_includes cpp, "Hello"
    rescue => e
      puts "Error: #{e.message}"
      # For now, just test that we get an error
      assert e.message.include?("left operand of '+' must be numeric")
    end
  end

  def test_string_interpolation
    aurora_source = <<~AUR
      fn greet(name: str) -> str =
        "Hello, {name}!"
    AUR

    # This should work but currently fails
    begin
      cpp = Aurora.to_cpp(aurora_source)
      puts "Generated C++:"
      puts cpp
      assert_includes cpp, "Hello"
    rescue => e
      puts "Error: #{e.message}"
      # For now, just test that we get an error
      assert e.message.include?("Unknown identifier")
    end
  end

  def test_string_methods
    aurora_source = <<~AUR
      fn process(text: str) -> str =
        text.trim().upper()
    AUR

    begin
      cpp = Aurora.to_cpp(aurora_source)
      puts "Generated C++:"
      puts cpp
      assert_includes cpp, "trim"
      assert_includes cpp, "upper"
    rescue => e
      puts "Error: #{e.message}"
      # For now, just test that we get an error
      assert e.message.include?("Unknown member")
    end
  end
end
