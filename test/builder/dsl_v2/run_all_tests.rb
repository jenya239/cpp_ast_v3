#!/usr/bin/env ruby
# frozen_string_literal: true

# Run all DSL v2 tests
require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

# Load all test files
require_relative "types_dsl_test"
require_relative "expr_builder_test"
require_relative "control_dsl_test"
require_relative "function_builder_test"
require_relative "class_builder_test"
require_relative "ownership_dsl_test"
require_relative "dsl_v2_integration_test"
require_relative "aurora_xqr_test"

# Run all tests
if __FILE__ == $0
  puts "=== Running DSL v2 Test Suite ==="
  puts
  
  # Run tests
  Test::Unit::AutoRunner.run
end
