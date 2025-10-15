# frozen_string_literal: true

require_relative "../test_helper"

class FunctionModifiersRoundtripTest < Minitest::Test
  def setup
    CppAst.formatting_mode = :lossless
  end
  
  def teardown
    CppAst.formatting_mode = :pretty
  end
  
  def test_function_override
    source = <<~CPP
      void foo() override;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_const
    source = <<~CPP
      void foo() const;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_const_override
    source = <<~CPP
      void foo() const override;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_final
    source = <<~CPP
      void foo() final;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_noexcept
    source = <<~CPP
      void foo() noexcept;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_default
    source = <<~CPP
      void foo() = default;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_delete
    source = <<~CPP
      void foo() = delete;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_pure_virtual
    source = <<~CPP
      void foo() = 0;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_override_with_body
    source = <<~CPP
      void foo() override {
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_const_override_default
    source = <<~CPP
      void foo() const override = default;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_complex_modifiers
    source = <<~CPP
      void foo() const noexcept override final;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_function_with_spaces
    source = <<~CPP
      void foo()  const  override ;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

