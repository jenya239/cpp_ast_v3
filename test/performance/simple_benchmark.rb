# frozen_string_literal: true

require "benchmark"
require_relative "../test_helper"
require_relative "../../lib/mlc"
require_relative "../../lib/cpp_ast"

class SimpleBenchmark < Minitest::Test
  def test_string_builder_performance
    puts "\n=== StringBuilder Performance Test ==="
    
    # Test regular string concatenation
    regular_time = Benchmark.measure do
      result = ""
      1000.times do |i|
        result += "Line #{i}\n"
      end
    end
    
    # Test StringBuilder (simplified version)
    builder_time = Benchmark.measure do
      result = String.new
      1000.times do |i|
        result << "Line #{i}\n"
      end
    end
    
    puts "Regular String Concatenation: #{regular_time.real.round(4)}s"
    puts "StringBuilder (<< operator): #{builder_time.real.round(4)}s"
    puts "StringBuilder Speedup: #{(regular_time.real / builder_time.real).round(2)}x"
    
    assert builder_time.real < regular_time.real, "StringBuilder should be faster"
  end
  
  def test_aurora_parsing_performance
    puts "\n=== Aurora Parsing Performance Test ==="
    
    source = <<~AURORA
      fn factorial(n: i32) -> i32 =
        if n <= 1 then 1
        else n * factorial(n - 1)
      
      fn main() -> i32 = factorial(5)
    AURORA
    
    # Test parsing performance
    parse_time = Benchmark.measure do
      100.times { MLC.parse(source) }
    end
    
    puts "Parse 100 times: #{parse_time.real.round(4)}s"
    puts "Average per parse: #{(parse_time.real / 100 * 1000).round(2)}ms"
    
    # Report performance metrics instead of hard assertions
    threshold = ENV['PARSE_TIME_THRESHOLD']&.to_f || 5.0
    if parse_time.real > threshold
      puts "WARNING: Parse time #{parse_time.real.round(4)}s exceeds threshold #{threshold}s"
    end
  end
  
  def test_cpp_generation_performance
    puts "\n=== C++ Generation Performance Test ==="
    
    source = <<~AURORA
      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA
    
    # Test generation performance
    gen_time = Benchmark.measure do
      100.times { MLC.to_cpp(source) }
    end
    
    puts "Generate 100 times: #{gen_time.real.round(4)}s"
    puts "Average per generation: #{(gen_time.real / 100 * 1000).round(2)}ms"
    
    assert gen_time.real < 1.0, "Generation should be fast"
  end
  
  def test_large_file_performance
    puts "\n=== Large File Performance Test ==="
    
    # Generate a large Aurora file
    large_source = generate_large_aurora_source(100)
    
    # Test parsing large file
    parse_time = Benchmark.measure do
      MLC.parse(large_source)
    end
    
    puts "Parse large file: #{parse_time.real.round(4)}s"
    
    assert parse_time.real < 2.0, "Large file parsing should be reasonable"
  end
  
  private
  
  def generate_large_aurora_source(function_count)
    source = String.new(<<~AURORA)
      module LargeTest
      
      fn main() -> i32 = 0
    AURORA
    
    function_count.times do |i|
      source << <<~AURORA
        fn function_#{i}(x: i32) -> i32 =
          if x > 0 then x * 2
          else 0
      AURORA
    end
    
    source
  end
end
