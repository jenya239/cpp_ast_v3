# frozen_string_literal: true

require_relative "../test_helper"

class ConstexprVariableRoundtripTest < Minitest::Test
  def test_constexpr_uint32
    source = "constexpr uint32_t SIZE = 2048;"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_constexpr_size_t
    source = "constexpr size_t MAX_SIZE = 16384;"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_const_static_int
    source = "const static int VALUE = 42;"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_multiple_constexpr_in_namespace
    source = <<~CPP
      namespace constants {
          constexpr uint32_t DEFAULT_SIZE = 2048;
          constexpr uint32_t MAX_SIZE = 8192;
          constexpr size_t CACHE_SIZE = 1024;
      }
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_constexpr_with_tabs
    source = "constexpr\tuint32_t\tSIZE\t=\t2048;"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_constexpr_inline_variable
    source = "inline constexpr int VALUE = 100;"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
end

