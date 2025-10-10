#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/cpp_ast'

# Parse all .cpp files from gtk-gl-cpp-2025 project
gtk_project = "/home/jenya/workspaces/experimental/gtk-gl-cpp-2025/src"

unless Dir.exist?(gtk_project)
  puts "❌ gtk-gl-cpp-2025 project not found at: #{gtk_project}"
  exit 1
end

total = 0
success = 0
failures = []

Dir.glob("#{gtk_project}/**/*.cpp").each do |file|
  total += 1
  source = File.read(file)
  
  begin
    program = CppAst.parse(source)
    result = program.to_source
    
    if source == result
      success += 1
      puts "✅ #{File.basename(file)}"
    else
      failures << file
      puts "⚠️  #{File.basename(file)} (roundtrip mismatch)"
    end
  rescue => e
    failures << file
    puts "❌ #{File.basename(file)} (#{e.class}: #{e.message.lines.first.strip})"
  end
end

puts "\n" + "="*60
puts "Results: #{success}/#{total} files passed"
puts "Success rate: #{(success * 100.0 / total).round(1)}%"

if failures.any?
  puts "\nFailed files:"
  failures.each { |f| puts "  - #{File.basename(f)}" }
end

