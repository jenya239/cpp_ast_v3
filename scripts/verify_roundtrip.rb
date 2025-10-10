#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/cpp_ast'

# Verify roundtrip for all fixtures
fixtures_dir = File.join(__dir__, '../test/fixtures')
Dir.glob("#{fixtures_dir}/*.cpp").each do |file|
  source = File.read(file)
  program = CppAst.parse(source)
  result = program.to_source
  
  if source == result
    puts "✅ #{File.basename(file)}"
  else
    puts "❌ #{File.basename(file)}"
    puts "Expected:\n#{source.inspect}"
    puts "Got:\n#{result.inspect}"
    exit 1
  end
end

puts "\n✅ All fixtures verified!"

