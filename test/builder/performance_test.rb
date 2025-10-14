# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/cpp_ast/builder/cache"

class PerformanceTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_cache_basic_functionality
    cache = CppAst::Builder::Cache.new
    
    # Test cache miss
    assert_nil cache.get("key1")
    assert_equal 0, cache.stats[:hit_count]
    assert_equal 1, cache.stats[:miss_count]
    
    # Test cache hit
    cache.set("key1", "value1")
    assert_equal "value1", cache.get("key1")
    assert_equal 1, cache.stats[:hit_count]
    assert_equal 1, cache.stats[:miss_count]
    
    # Test cache clear
    cache.clear
    assert_equal 0, cache.stats[:size]
    assert_equal 0, cache.stats[:hit_count]
    assert_equal 0, cache.stats[:miss_count]
  end
  
  def test_cache_hit_rate
    cache = CppAst::Builder::Cache.new
    
    # Fill cache
    cache.set("key1", "value1")
    cache.set("key2", "value2")
    
    # Test hits
    cache.get("key1")
    cache.get("key2")
    cache.get("key1") # Hit again
    
    # Test miss
    cache.get("key3")
    
    stats = cache.stats
    assert_equal 3, stats[:hit_count]
    assert_equal 1, stats[:miss_count]
    assert_equal 0.75, stats[:hit_rate]
  end
  
  def test_optimizer_basic_functionality
    optimizer = CppAst::Builder::Optimizer.new
    
    # Test compilation without cache
    result1 = optimizer.compile_with_cache("test_code_1") do |code|
      "compiled_#{code}"
    end
    
    assert_equal "compiled_test_code_1", result1
    
    # Test compilation with cache
    result2 = optimizer.compile_with_cache("test_code_1") do |code|
      "compiled_#{code}"
    end
    
    assert_equal "compiled_test_code_1", result2
    
    stats = optimizer.stats
    assert_equal 2, stats[:compilation][:total_compilations]
    assert_equal 1, stats[:compilation][:cached_compilations]
    assert_equal 1, stats[:cache][:hit_count]
    assert_equal 1, stats[:cache][:miss_count]
  end
  
  def test_optimizer_performance_improvement
    optimizer = CppAst::Builder::Optimizer.new
    
    # First compilation (cache miss)
    start_time = Time.now
    result1 = optimizer.compile_with_cache("complex_dsl_code") do |code|
      # Simulate complex compilation
      sleep(0.001) # 1ms
      "compiled_#{code}"
    end
    first_time = Time.now - start_time
    
    # Second compilation (cache hit)
    start_time = Time.now
    result2 = optimizer.compile_with_cache("complex_dsl_code") do |code|
      # This should not be called due to cache
      sleep(0.001) # 1ms
      "compiled_#{code}"
    end
    second_time = Time.now - start_time
    
    assert_equal result1, result2
    assert second_time < first_time, "Cached compilation should be faster"
    
    stats = optimizer.stats
    assert_equal 1, stats[:cache][:hit_count]
    assert_equal 1, stats[:cache][:miss_count]
  end
  
  def test_optimized_dsl_basic_functionality
    optimized_dsl = CppAst::Builder::OptimizedDSL.new
    
    # Test compilation
    result = optimized_dsl.compile("int(42)")
    assert_equal "int(42)", result
    
    # Test stats
    stats = optimized_dsl.stats
    assert stats[:compilation][:total_compilations] > 0
    assert stats[:compilation][:average_time] > 0
  end
  
  def test_optimized_dsl_caching
    optimized_dsl = CppAst::Builder::OptimizedDSL.new
    
    # First compilation
    result1 = optimized_dsl.compile("int(42)")
    
    # Second compilation (should be cached)
    result2 = optimized_dsl.compile("int(42)")
    
    assert_equal result1, result2
    
    stats = optimized_dsl.stats
    assert stats[:cache][:hit_count] > 0
  end
  
  def test_optimized_dsl_clear_cache
    optimized_dsl = CppAst::Builder::OptimizedDSL.new
    
    # Compile some code
    optimized_dsl.compile("int(42)")
    optimized_dsl.compile("string('hello')")
    
    # Clear cache
    optimized_dsl.clear_cache
    
    stats = optimized_dsl.stats
    assert_equal 0, stats[:cache][:size]
    assert_equal 0, stats[:cache][:hit_count]
    assert_equal 0, stats[:cache][:miss_count]
  end
  
  def test_memory_usage_tracking
    cache = CppAst::Builder::Cache.new
    
    # Add some data
    cache.set("key1", "value1")
    cache.set("key2", "value2")
    
    # Test memory usage
    memory_usage = cache.memory_usage
    assert memory_usage > 0
    
    # Clear cache
    cache.clear
    assert_equal 0, cache.memory_usage
  end
  
  def test_compilation_stats
    optimizer = CppAst::Builder::Optimizer.new
    
    # Multiple compilations
    5.times do |i|
      optimizer.compile_with_cache("code_#{i}") do |code|
        "result_#{code}"
      end
    end
    
    # Repeat some compilations (cache hits)
    3.times do |i|
      optimizer.compile_with_cache("code_#{i}") do |code|
        "result_#{code}"
      end
    end
    
    stats = optimizer.stats
    assert_equal 8, stats[:compilation][:total_compilations]
    assert_equal 3, stats[:compilation][:cached_compilations]
    assert_equal 3, stats[:cache][:hit_count]
    assert_equal 5, stats[:cache][:miss_count]
    assert stats[:compilation][:average_time] > 0
  end
end
