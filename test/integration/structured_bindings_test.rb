# frozen_string_literal: true

require "test_helper"

class StructuredBindingsTest < Minitest::Test
  def test_range_based_for_with_structured_bindings
    source = "for (auto& [key, value] : map) { use(key); }"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_const_structured_bindings
    source = "for (const auto& [k, v] : map) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_structured_bindings_with_spaces
    source = "for (auto & [ k , v ] : map) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_structured_bindings_three_elements
    source = "for (auto [x, y, z] : vec) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_structured_bindings_single_element
    source = "for (auto [x] : vec) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_structured_bindings_with_body
    source = <<~CPP
      for (const auto& [id, factory] : factories) {
          ids.push_back(id);
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_structured_bindings_ignore_variable
    source = "for (const auto& [id, _] : map) { use(id); }"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_classic_for_still_works
    source = "for (i = 0; i < 10; i++) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_simple_range_based_for
    source = "for (int x : vec) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_range_based_for_with_auto
    source = "for (auto x : vec) {}"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
end

