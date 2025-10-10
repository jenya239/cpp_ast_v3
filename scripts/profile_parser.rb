#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark'
require_relative '../lib/cpp_ast'

# Test files from gtk-gl-cpp-2025
test_files = [
  '/home/jenya/workspaces/experimental/gtk-gl-cpp-2025/include/gl/buffer.hpp',
  '/home/jenya/workspaces/experimental/gtk-gl-cpp-2025/include/text/texture_atlas.hpp',
  '/home/jenya/workspaces/experimental/gtk-gl-cpp-2025/include/gl/shader.hpp'
]

puts "Профилирование парсера C++ AST"
puts "=" * 60

test_files.each do |file_path|
  next unless File.exist?(file_path)
  
  source = File.read(file_path)
  file_name = File.basename(file_path)
  
  puts "\nФайл: #{file_name}"
  puts "Размер: #{source.size} байт, #{source.lines.count} строк"
  
  # Warm-up
  CppAst.parse(source) rescue nil
  
  # Benchmark
  iterations = 100
  time = Benchmark.realtime do
    iterations.times do
      begin
        CppAst.parse(source)
      rescue CppAst::ParseError => e
        # Ignore parse errors for profiling
      end
    end
  end
  
  avg_time_ms = (time / iterations) * 1000
  throughput = source.size / (time / iterations) / 1024 / 1024  # MB/s
  
  puts "  Среднее время: %.2f мс" % avg_time_ms
  puts "  Throughput: %.2f MB/s" % throughput
end

puts "\n" + "=" * 60
puts "Профилирование завершено"

