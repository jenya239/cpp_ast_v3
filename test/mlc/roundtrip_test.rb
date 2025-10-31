# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/mlc"

class AuroraRoundtripTest < Minitest::Test
  def test_simple_function
    aurora_code = "fn add(a: i32, b: i32) -> i32 = a + b"
    
    # 1. Parse Aurora
    ast = MLC.parse(aurora_code)
    assert_instance_of MLC::AST::Program, ast
    assert_equal 1, ast.declarations.size
    
    func = ast.declarations.first
    assert_instance_of MLC::AST::FuncDecl, func
    assert_equal "add", func.name
    assert_equal 2, func.params.size
    assert_equal "i32", func.ret_type.name
    
    # 2. Transform to HighIR
    core_ir = MLC.transform_to_core(ast)
    assert_instance_of MLC::HighIR::Module, core_ir
    assert_equal 1, core_ir.items.size
    
    func_ir = core_ir.items.first
    assert_instance_of MLC::HighIR::Func, func_ir
    assert_equal "add", func_ir.name
    
    # 3. Lower to C++ AST
    cpp_ast = MLC.lower_to_cpp(core_ir)
    assert_instance_of CppAst::Nodes::Program, cpp_ast
    
    # 4. Generate C++ source
    cpp_code = cpp_ast.to_source
    assert_includes cpp_code, "int add"
    assert_includes cpp_code, "int a"
    assert_includes cpp_code, "int b"
    assert_includes cpp_code, "return"
    assert_includes cpp_code, "a + b"
  end
  
  def test_full_pipeline
    aurora_code = "fn add(a: i32, b: i32) -> i32 = a + b"
    
    # Full pipeline
    cpp_code = MLC.to_cpp(aurora_code)
    
    # Verify generated C++
    assert_includes cpp_code, "int add(int a, int b)"
    assert_includes cpp_code, "return a + b"
  end
  
  def test_compile_and_run
    aurora_code = "fn add(a: i32, b: i32) -> i32 = a + b"
    
    # Generate C++ code
    cpp_code = MLC.to_cpp(aurora_code)
    
    # Add main function for testing
    full_cpp = <<~CPP
      #{cpp_code}
      
      int main() {
        return add(2, 3) == 5 ? 0 : 1;
      }
    CPP
    
    # Write to temporary file
    temp_file = "/tmp/aurora_test.cpp"
    File.write(temp_file, full_cpp)
    runtime_dir = File.expand_path("../../runtime", __dir__)
    
    # Compile
    compile_result = system("g++ -std=c++20 -I #{runtime_dir} -o /tmp/aurora_test #{temp_file}")
    assert compile_result, "Compilation failed"
    
    # Run and check result
    run_result = system("/tmp/aurora_test")
    assert run_result, "Program should return 0 (success)"
    
    # Cleanup
    File.delete(temp_file) if File.exist?(temp_file)
    File.delete("/tmp/aurora_test") if File.exist?("/tmp/aurora_test")
  end
  
  def test_float_function
    aurora_code = "fn square(x: f32) -> f32 = x * x"
    
    cpp_code = MLC.to_cpp(aurora_code)
    
    assert_includes cpp_code, "float square(float x)"
    assert_includes cpp_code, "return x * x"
  end
  
  def test_record_type
    aurora_code = <<~AURORA
      type Point = { x: f32, y: f32 }
      fn make_point(x: f32, y: f32) -> Point = { x: x, y: y }
    AURORA
    
    cpp_code = MLC.to_cpp(aurora_code)
    
    assert_includes cpp_code, "struct Point"
    assert_includes cpp_code, "float x"
    assert_includes cpp_code, "float y"
    assert_includes cpp_code, "Point make_point"
  end
end
