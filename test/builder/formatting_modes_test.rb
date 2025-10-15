# frozen_string_literal: true

require_relative "../test_helper"

class FormattingModesTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_pretty_mode_default
    # Убеждаемся что режим сброшен к default
    CppAst.formatting_mode = :pretty
    assert_equal :pretty, CppAst.formatting_mode
  end
  
  def test_template_pretty_mode
    CppAst.formatting_mode = :pretty
    ast = template_decl("typename T", function_decl("void", "foo", [], block()))
    assert_includes ast.to_source, "template <typename T>"
  end
  
  def test_template_lossless_mode
    CppAst.formatting_mode = :lossless
    ast = template_decl("typename T", function_decl("void", "foo", [], block()))
    # В lossless режиме нет пробела после template
    assert_match /template<typename T>/, ast.to_source
  end
  
  def test_with_formatting_mode_block
    outer_mode = CppAst.formatting_mode
    
    CppAst.with_formatting_mode(:lossless) do
      assert_equal :lossless, CppAst.formatting_mode
      ast = template_decl("typename T", function_decl("void", "foo", [], block()))
      assert_match /template<typename T>/, ast.to_source
    end
    
    # После блока режим восстанавливается
    assert_equal outer_mode, CppAst.formatting_mode
  end
  
  def test_thread_safety
    results = []
    threads = []
    
    threads << Thread.new do
      CppAst.with_formatting_mode(:pretty) do
        sleep 0.01
        results << CppAst.formatting_mode
      end
    end
    
    threads << Thread.new do
      CppAst.with_formatting_mode(:lossless) do
        sleep 0.01
        results << CppAst.formatting_mode
      end
    end
    
    threads.each(&:join)
    
    assert_equal 2, results.size
    assert_includes results, :pretty
    assert_includes results, :lossless
  end
  
  def test_invalid_mode_raises_error
    assert_raises(ArgumentError) do
      CppAst.formatting_mode = :invalid
    end
  end
  
  def test_function_rparen_suffix_pretty
    CppAst.formatting_mode = :pretty
    ast = function_decl("void", "test", [], block())
    assert_includes ast.to_source, "void test() {"
  end
  
  def test_function_rparen_suffix_lossless
    CppAst.formatting_mode = :lossless
    ast = function_decl("void", "test", [], block())
    assert_includes ast.to_source, "void test(){"
  end
  
  def test_enum_class_underlying_type_pretty
    CppAst.formatting_mode = :pretty
    ast = enum_class("Format", ["A8", "RGB8"], underlying_type: "uint8_t")
    # В pretty режиме должен быть одинарный пробел перед двоеточием
    assert_includes ast.to_source, "enum class Format :uint8_t"
  end
  
  def test_enum_class_underlying_type_lossless
    CppAst.formatting_mode = :lossless
    ast = enum_class("Format", ["A8", "RGB8"], underlying_type: "uint8_t")
    # В lossless режиме не должно быть пробела перед двоеточием
    assert_includes ast.to_source, "enum class Format:uint8_t"
  end
end
