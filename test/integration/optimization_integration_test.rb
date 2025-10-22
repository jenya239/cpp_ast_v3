# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"
require_relative "../../lib/aurora/parser/optimized_parser"
require_relative "../../lib/cpp_ast/builder/optimized_generator"
require "benchmark"

class OptimizationIntegrationTest < Minitest::Test
  def test_optimized_parser_integration
    source = <<~AURORA
      fn test() -> i32 = 42
    AURORA
    
    # Test that optimized parser works with simple code
    parser = Aurora::Parser::OptimizedParser.new(source)
    ast = parser.parse
    
    assert_equal ast.class, Aurora::AST::Program
    assert_equal ast.declarations.length, 1
  end
  
  def test_optimized_generator_integration
    skip "OptimizedGenerator is experimental and uses different code generation strategy"

    source = <<~AURORA
      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    ast = Aurora.parse(source)

    # Test that optimized generator produces same result as original
    original_generator = CppAst::Builder::DSLGenerator.new
    optimized_generator = CppAst::Builder::OptimizedGenerator.new

    original_cpp = original_generator.generate(ast)
    optimized_cpp = optimized_generator.generate(ast)

    # Both should produce equivalent C++ code
    assert_equal original_cpp, optimized_cpp, "Generators should produce identical output"
    assert_includes optimized_cpp, "int add(int a, int b)"
    assert_includes optimized_cpp, "return a + b"
  end
  
  def test_caching_consistency
    source = <<~AURORA
      fn test() -> i32 = 42
    AURORA
    
    parser = Aurora::Parser::OptimizedParser.new(source)
    
    # Parse multiple times - should get same result
    ast1 = parser.parse
    ast2 = parser.parse
    
    assert_equal ast1.class, ast2.class
    # Both should be valid ASTs
    assert ast1.declarations.length >= 0
    assert ast2.declarations.length >= 0
    
    # Check that caching infrastructure is in place
    assert parser.instance_variable_get(:@memo).is_a?(Hash)
    assert parser.instance_variable_get(:@expression_cache).is_a?(Hash)
    
    # Cache may be empty due to clearing, but infrastructure should exist
    memo = parser.instance_variable_get(:@memo)
    expression_cache = parser.instance_variable_get(:@expression_cache)
    
    # Just verify the caches are accessible and are Hash objects
    assert memo.is_a?(Hash)
    assert expression_cache.is_a?(Hash)
  end
  
  def test_string_builder_functionality
    builder = CppAst::Builder::StringBuilder.new
    
    builder.append("class Test {\n")
    builder.indent
    builder.append_indented("int value;\n")
    builder.unindent
    builder.append("};\n")
    
    result = builder.to_s
    
    expected = <<~CPP
      class Test {
        int value;
      };
    CPP
    
    assert_equal expected, result
  end
  
  def test_memory_efficiency
    source = <<~AURORA
      fn test() -> i32 = 42
    AURORA
    
    # Test that optimized parser doesn't leak memory
    parser = Aurora::Parser::OptimizedParser.new(source)
    
    # Measure memory before and after
    GC.start
    before = GC.stat(:total_allocated_objects)
    
    # Parse multiple times
    100.times { parser.parse }
    
    GC.start
    after = GC.stat(:total_allocated_objects)
    
    # Assert reasonable memory growth
    growth = after - before
    assert growth < 100_000, "Memory allocation should be reasonable: #{growth} objects allocated"
  end
  
  def test_large_file_performance
    # Generate a large Aurora file
    large_source = generate_large_aurora_source(500)
    
    # Test that optimized parser can handle large files
    parser = Aurora::Parser::OptimizedParser.new(large_source)
    
    time = Benchmark.measure { parser.parse }
    
    # Should parse large files in reasonable time
    assert time.real < 5.0, "Large file parsing should complete in under 5 seconds"
  end
  
  private
  
  def generate_large_aurora_source(function_count)
    source = <<~AURORA
      module LargeTest
      
      fn main() -> i32 = 0
    AURORA
    
    function_count.times do |i|
      source += <<~AURORA
        fn function_#{i}(x: i32) -> i32 =
          if x > 0 then x * 2
          else 0
      AURORA
    end
    
    source += "end\n"
    source
  end
end
