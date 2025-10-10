#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast"
require "fileutils"

# Parse all C++ files from gtk-gl-cpp-2025 project
class GtkProjectParser
  def initialize(project_path)
    @project_path = project_path
    @stats = {
      total_files: 0,
      parsed: 0,
      failed: 0,
      errors: Hash.new(0)
    }
  end
  
  def run
    puts "Parsing gtk-gl-cpp-2025 project..."
    puts "Path: #{@project_path}"
    puts "-" * 60
    
    cpp_files = find_cpp_files
    
    cpp_files.each do |file|
      parse_file(file)
    end
    
    print_report
  end
  
  private
  
  def find_cpp_files
    patterns = [
      "#{@project_path}/src/**/*.cpp",
      "#{@project_path}/include/**/*.hpp"
    ]
    
    files = patterns.flat_map { |pattern| Dir.glob(pattern) }
    @stats[:total_files] = files.size
    files
  end
  
  def parse_file(file)
    relative_path = file.sub(@project_path + "/", "")
    
    begin
      source = File.read(file)
      program = CppAst.parse(source)
      
      # Check roundtrip
      output = program.to_source
      if output == source
        @stats[:parsed] += 1
        puts "✓ #{relative_path}"
      else
        @stats[:failed] += 1
        puts "✗ #{relative_path} - roundtrip mismatch"
        save_mismatch(file, source, output)
      end
    rescue CppAst::ParseError => e
      @stats[:failed] += 1
      error_type = classify_error(e.message)
      @stats[:errors][error_type] += 1
      puts "✗ #{relative_path} - #{error_type}"
      puts "  Error: #{e.message[0..100]}"
    rescue StandardError => e
      @stats[:failed] += 1
      @stats[:errors]["Other: #{e.class}"] += 1
      puts "✗ #{relative_path} - #{e.class}"
      puts "  Error: #{e.message[0..100]}"
    end
  end
  
  def classify_error(message)
    case message
    when /Expected.*got/
      "Unexpected token"
    when /Unexpected token/
      "Unexpected token"
    when /Unexpected character/
      "Unexpected character"
    else
      "Other parse error"
    end
  end
  
  def save_mismatch(file, original, output)
    basename = File.basename(file, ".*")
    dir = "test/fixtures/mismatches"
    FileUtils.mkdir_p(dir)
    
    File.write("#{dir}/#{basename}_original.txt", original)
    File.write("#{dir}/#{basename}_output.txt", output)
  end
  
  def print_report
    puts "\n" + "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Total files:   #{@stats[:total_files]}"
    puts "Parsed:        #{@stats[:parsed]} (#{percentage(@stats[:parsed])}%)"
    puts "Failed:        #{@stats[:failed]} (#{percentage(@stats[:failed])}%)"
    puts
    
    if @stats[:errors].any?
      puts "Errors by type:"
      @stats[:errors].sort_by { |_k, v| -v }.each do |error_type, count|
        puts "  #{error_type}: #{count}"
      end
    end
    
    puts "=" * 60
  end
  
  def percentage(count)
    return 0 if @stats[:total_files].zero?
    ((count.to_f / @stats[:total_files]) * 100).round(1)
  end
end

# Run
project_path = ARGV[0] || "/home/jenya/workspaces/experimental/gtk-gl-cpp-2025"
parser = GtkProjectParser.new(project_path)
parser.run
