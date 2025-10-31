# frozen_string_literal: true

require "benchmark"
require "memory_profiler"
require_relative "../test_helper"
require_relative "../../lib/mlc"
require_relative "../../lib/cpp_ast"
require_relative "../../lib/mlc/parser/optimized_parser"
require_relative "../../lib/cpp_ast/builder/optimized_generator"

class PerformanceBenchmark < Minitest::Test
  def setup
    @large_aurora_source = generate_large_aurora_file(1000)
    @large_cpp_source = generate_large_cpp_file(1000)
  end
  
  def test_parser_performance
    puts "\n=== Parser Performance Benchmark ==="
    
    # Test original parser
    original_time = Benchmark.measure do
      10.times { MLC.parse(@large_aurora_source) }
    end
    
    # Test optimized parser
    optimized_time = Benchmark.measure do
      10.times { MLC::Parser::OptimizedParser.new(@large_aurora_source).parse }
    end
    
    puts "Original Parser: #{original_time.real.round(3)}s"
    puts "Optimized Parser: #{optimized_time.real.round(3)}s"
    puts "Speedup: #{(original_time.real / optimized_time.real).round(2)}x"
    
    assert optimized_time.real < original_time.real, "Optimized parser should be faster"
  end
  
  def test_code_generation_performance
    puts "\n=== Code Generation Performance Benchmark ==="
    
    ast = MLC.parse(@large_aurora_source)
    
    # Test original generator
    original_time = Benchmark.measure do
      10.times { CppAst::Builder::DSLGenerator.new.generate(ast) }
    end
    
    # Test optimized generator
    optimized_time = Benchmark.measure do
      10.times { CppAst::Builder::OptimizedGenerator.new.generate(ast) }
    end
    
    puts "Original Generator: #{original_time.real.round(3)}s"
    puts "Optimized Generator: #{optimized_time.real.round(3)}s"
    puts "Speedup: #{(original_time.real / optimized_time.real).round(2)}x"
    
    assert optimized_time.real < original_time.real, "Optimized generator should be faster"
  end
  
  def test_memory_usage
    puts "\n=== Memory Usage Benchmark ==="
    
    # Test memory usage of original parser
    original_memory = MemoryProfiler.report do
      MLC.parse(@large_aurora_source)
    end
    
    original_total = original_memory.total_allocated_memsize
    
    # Test memory usage of optimized parser
    optimized_memory = MemoryProfiler.report do
      MLC::Parser::OptimizedParser.new(@large_aurora_source).parse
    end
    optimized_total = optimized_memory.total_allocated_memsize
    
    puts "Original Parser Memory: #{format_bytes(original_total)}"
    puts "Optimized Parser Memory: #{format_bytes(optimized_total)}"
    
    reduction = original_total > 0 ? ((original_total - optimized_total) / original_total.to_f * 100).round(1) : 0
    puts "Memory Reduction: #{reduction}%"
    
    if original_total > 0
      assert optimized_total < original_total, "Optimized parser should use less memory"
    else
      puts "Warning: Original parser allocated zero memory, skipping memory comparison"
    end
  end
  
  def test_caching_effectiveness
    puts "\n=== Caching Effectiveness Test ==="
    
    # Test cache hit rate
    parser = MLC::Parser::OptimizedParser.new(@large_aurora_source)
    
    # First parse (cache miss)
    first_time = Benchmark.measure { parser.parse }
    
    # Second parse (cache hit)
    second_time = Benchmark.measure { parser.parse }
    
    puts "First Parse: #{first_time.real.round(4)}s"
    puts "Second Parse: #{second_time.real.round(4)}s"
    puts "Cache Speedup: #{(first_time.real / second_time.real).round(2)}x"
    
    assert second_time.real < first_time.real, "Cached parse should be faster"
  end
  
  def test_string_builder_performance
    puts "\n=== StringBuilder Performance Test ==="
    
    # Test regular string concatenation
    regular_time = Benchmark.measure do
      result = ""
      1000.times do |i|
        result += "Line #{i}\n"
      end
    end
    
    # Test StringBuilder
    builder_time = Benchmark.measure do
      builder = CppAst::Builder::StringBuilder.new
      1000.times do |i|
        builder.append("Line #{i}\n")
      end
      builder.to_s
    end
    
    puts "Regular String Concatenation: #{regular_time.real.round(4)}s"
    puts "StringBuilder: #{builder_time.real.round(4)}s"
    puts "StringBuilder Speedup: #{(regular_time.real / builder_time.real).round(2)}x"
    
    assert builder_time.real < regular_time.real, "StringBuilder should be faster"
  end
  
  private
  
  def generate_large_aurora_file(size)
    source = <<~AURORA
      module PerformanceTest
      
      fn main() -> i32 = 0
    AURORA
    
    # Add many functions
    size.times do |i|
      source += <<~AURORA
        fn function_#{i}(x: i32) -> i32 =
          if x > 0 then x * 2
          else 0
      AURORA
    end
    
    source
  end
  
  def generate_large_cpp_file(size)
    source = <<~CPP
      #pragma once
      #include <iostream>
      
      int main() { return 0; }
    CPP
    
    # Add many functions
    size.times do |i|
      source += <<~CPP
        int function_#{i}(int x) {
          return x > 0 ? x * 2 : 0;
        }
      CPP
    end
    
    source
  end
  
  def format_bytes(bytes)
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)} KB"
    else
      "#{(bytes / (1024.0 * 1024.0)).round(1)} MB"
    end
  end
end
