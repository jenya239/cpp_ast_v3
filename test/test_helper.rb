# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/cpp_ast"
require_relative "../lib/mlc"

module TestHelpers
  # Helper method to test roundtrip accuracy
  # Usage: assert_roundtrip "x = 42;\n"
  def assert_roundtrip(source)
    program = CppAst.parse(source)
    result = program.to_source
    
    assert_equal source, result,
      "Roundtrip failed:\nExpected: #{source.inspect}\nGot:      #{result.inspect}"
  end
end

class Minitest::Test
  include TestHelpers

  # Support for tagging slow tests
  # Usage: tag :slow
  # Run only slow tests: TEST_TAGS=slow rake test
  # Run without slow tests: TEST_TAGS=!slow rake test
  def self.tag(name)
    @tags ||= []
    @tags << name unless @tags.include?(name)
  end

  def self.tags
    @tags || []
  end

  # Override setup to check tags
  def setup
    tags = ENV['TEST_TAGS']&.split(',') || []

    # Check for exclusion tags (starting with !)
    tags.each do |tag|
      if tag.start_with?('!')
        excluded_tag = tag[1..-1].to_sym
        skip "Skipped due to tag exclusion: !#{excluded_tag}" if self.class.tags.include?(excluded_tag)
      end
    end

    # Check for inclusion tags (only run these)
    inclusion_tags = tags.reject { |t| t.start_with?('!') }.map(&:to_sym)
    unless inclusion_tags.empty?
      skip "Skipped due to tag filter" unless (self.class.tags & inclusion_tags).any?
    end
  end

  def teardown
    super
    if defined?(CppAst) && CppAst.respond_to?(:formatting_mode=)
      CppAst.formatting_mode = :pretty
    end
  end
end
