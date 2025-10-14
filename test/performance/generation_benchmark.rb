# frozen_string_literal: true

require "test_helper"
require "benchmark"

class GenerationBenchmarkTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_generate_100_template_classes
    start_time = Time.now
    
    classes = []
    100.times do |i|
      classes << template_class("TemplateClass#{i}", ["typename T"],
        function_decl("void", "method", [param("T", "value")], block())
          .const()
          .noexcept()
      )
    end
    
    generation_time = Time.now - start_time
    
    # Should generate 100 classes in less than 1 second
    assert generation_time < 1.0, "Generation of 100 template classes took #{generation_time}s, should be < 1s"
    
    # Test that all classes were generated
    assert_equal 100, classes.length
    
    # Test that generated code is valid
    cpp_code = classes.first.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "class TemplateClass0"
    
    puts "✅ Generated 100 template classes in #{generation_time.round(3)}s"
  end

  def test_generate_1000_enum_values
    start_time = Time.now
    
    enum_values = []
    1000.times do |i|
      enum_values << ["VALUE#{i}", i.to_s]
    end
    
    ast = enum_class("LargeEnum", enum_values, underlying_type: "int")
    
    generation_time = Time.now - start_time
    
    # Should generate 1000 enum values in less than 0.5 seconds
    assert generation_time < 0.5, "Generation of 1000 enum values took #{generation_time}s, should be < 0.5s"
    
    cpp_code = ast.to_source
    
    # Test that all values are present
    assert_includes cpp_code, "VALUE0 = 0"
    assert_includes cpp_code, "VALUE999 = 999"
    
    puts "✅ Generated 1000 enum values in #{generation_time.round(3)}s"
  end

  def test_generate_large_class_with_many_methods
    start_time = Time.now
    
    methods = []
    100.times do |i|
      methods << function_decl("void", "method#{i}", [param("int", "value")], block())
        .inline_body(block(return_stmt(id("value"))))
        .const()
        .noexcept()
    end
    
    ast = class_decl("LargeClass", *methods)
    
    generation_time = Time.now - start_time
    
    # Should generate large class in less than 0.5 seconds
    assert generation_time < 0.5, "Generation of large class took #{generation_time}s, should be < 0.5s"
    
    cpp_code = ast.to_source
    
    # Test that methods are present
    assert_includes cpp_code, "inline void method0(int value) const noexcept"
    assert_includes cpp_code, "inline void method99(int value) const noexcept"
    
    puts "✅ Generated large class with 100 methods in #{generation_time.round(3)}s"
  end

  def test_generate_complex_namespace
    start_time = Time.now
    
    # Generate a complex namespace with many elements
    elements = []
    
    # 50 using aliases
    50.times do |i|
      elements << using_alias("Type#{i}", "int")
    end
    
    # 50 enum classes
    50.times do |i|
      elements << enum_class("Enum#{i}", [["VALUE#{i}"]], underlying_type: "int")
    end
    
    # 50 template classes
    50.times do |i|
      elements << template_class("Template#{i}", ["typename T"],
        function_decl("void", "method", [param("T", "value")], block())
      )
    end
    
    ast = namespace_decl("ComplexNamespace", *elements)
    
    generation_time = Time.now - start_time
    
    # Should generate complex namespace in less than 1 second
    assert generation_time < 1.0, "Generation of complex namespace took #{generation_time}s, should be < 1s"
    
    cpp_code = ast.to_source
    
    # Test that elements are present
    assert_includes cpp_code, "namespace ComplexNamespace"
    assert_includes cpp_code, "using Type0 = int;"
    assert_includes cpp_code, "enum class Enum0 : int{VALUE0};"
    assert_includes cpp_code, "template <typename T>"
    
    puts "✅ Generated complex namespace in #{generation_time.round(3)}s"
  end

  def test_memory_usage
    # Test memory usage during generation
    initial_memory = `ps -o rss= -p #{Process.pid}`.to_i
    
    # Generate many objects
    objects = []
    1000.times do |i|
      objects << function_decl("void", "method#{i}", [], block())
      objects << enum_class("Enum#{i}", [["VALUE#{i}"]])
      objects << using_alias("Type#{i}", "int")
    end
    
    final_memory = `ps -o rss= -p #{Process.pid}`.to_i
    memory_used = final_memory - initial_memory
    
    # Should use less than 100MB
    assert memory_used < 100 * 1024, "Memory usage #{memory_used / 1024}MB, should be < 100MB"
    
    puts "✅ Memory usage: #{memory_used / 1024}MB for 3000 objects"
  end

  def test_benchmark_comparison
    # Benchmark different generation methods
    results = {}
    
    # Benchmark template class generation
    results[:template_class] = Benchmark.measure do
      100.times do |i|
        template_class("Class#{i}", ["typename T"],
          function_decl("void", "method", [], block())
        )
      end
    end
    
    # Benchmark enum class generation
    results[:enum_class] = Benchmark.measure do
      100.times do |i|
        enum_class("Enum#{i}", [["VALUE#{i}"]])
      end
    end
    
    # Benchmark function generation
    results[:function] = Benchmark.measure do
      100.times do |i|
        function_decl("void", "method#{i}", [], block())
      end
    end
    
    # All should be reasonably fast
    results.each do |type, time|
      assert time.real < 0.1, "#{type} generation took #{time.real}s, should be < 0.1s"
    end
    
    puts "✅ Benchmark results:"
    results.each do |type, time|
      puts "  #{type}: #{time.real.round(3)}s"
    end
  end

  def test_concurrent_generation
    # Test that generation is thread-safe
    threads = []
    results = []
    
    10.times do |i|
      threads << Thread.new do
        result = template_class("ConcurrentClass#{i}", ["typename T"],
          function_decl("void", "method", [], block())
        )
        results << result
      end
    end
    
    threads.each(&:join)
    
    # All threads should complete successfully
    assert_equal 10, results.length
    
    # All generated classes should be valid
    results.each do |ast|
      cpp_code = ast.to_source
      assert_includes cpp_code, "template <typename T>"
      assert_includes cpp_code, "class ConcurrentClass"
    end
    
    puts "✅ Concurrent generation completed successfully"
  end

  def test_large_file_generation
    # Test generation of a large file
    start_time = Time.now
    
    # Generate a large file with many classes
    classes = []
    50.times do |i|
      methods = []
      20.times do |j|
        methods << function_decl("void", "method#{j}", [param("int", "value")], block())
          .inline_body(block(return_stmt(id("value"))))
          .const()
      end
      
      classes << class_decl("Class#{i}", *methods)
    end
    
    ast = namespace_decl("LargeFile", *classes)
    
    generation_time = Time.now - start_time
    
    # Should generate large file in less than 2 seconds
    assert generation_time < 2.0, "Generation of large file took #{generation_time}s, should be < 2s"
    
    cpp_code = ast.to_source
    lines = cpp_code.lines.count
    
    # Should have many lines
    assert lines > 1000, "Generated file should have > 1000 lines, got #{lines}"
    
    puts "✅ Generated large file (#{lines} lines) in #{generation_time.round(3)}s"
  end
end
