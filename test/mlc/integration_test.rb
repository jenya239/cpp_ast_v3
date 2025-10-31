# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/mlc"

class AuroraIntegrationTest < Minitest::Test
  def test_example_1_simple_function
    aurora_code = "fn id(x: i32) -> i32 = x"
    
    cpp_code = MLC.to_cpp(aurora_code)
    
    # Compile and test
    test_cpp = <<~CPP
      #{cpp_code}
      
      int main() {
        return id(42) == 42 ? 0 : 1;
      }
    CPP
    
    assert_compiles_and_runs(test_cpp)
  end
  
  def test_example_2_binary_operations
    aurora_code = "fn add(a: i32, b: i32) -> i32 = a + b"
    
    cpp_code = MLC.to_cpp(aurora_code)
    
    test_cpp = <<~CPP
      #{cpp_code}
      
      int main() {
        return add(2, 3) == 5 ? 0 : 1;
      }
    CPP
    
    assert_compiles_and_runs(test_cpp)
  end
  
  def test_example_3_simple_math
    aurora_code = "fn multiply(a: i32, b: i32) -> i32 = a * b"
    
    cpp_code = MLC.to_cpp(aurora_code)
    
    test_cpp = <<~CPP
      #{cpp_code}
      
      int main() {
        return multiply(6, 7) == 42 ? 0 : 1;
      }
    CPP
    
    assert_compiles_and_runs(test_cpp)
  end
  
  def test_example_4_float_operations
    aurora_code = "fn divide(a: f32, b: f32) -> f32 = a / b"
    
    cpp_code = MLC.to_cpp(aurora_code)
    
    test_cpp = <<~CPP
      #{cpp_code}
      
      int main() {
        return divide(10.0f, 2.0f) == 5.0f ? 0 : 1;
      }
    CPP
    
    assert_compiles_and_runs(test_cpp)
  end
  
  private
  
  def assert_compiles_and_runs(cpp_code)
    temp_file = "/tmp/aurora_integration_test.cpp"
    binary_file = "/tmp/aurora_integration_test"
    runtime_dir = File.expand_path("../../runtime", __dir__)
    
    begin
      # Write C++ code
      File.write(temp_file, cpp_code)
      
      # Compile
      compile_result = system("g++ -std=c++20 -I #{runtime_dir} -o #{binary_file} #{temp_file}")
      assert compile_result, "Compilation failed for:\n#{cpp_code}"
      
      # Run
      run_result = system(binary_file)
      assert run_result, "Program execution failed for:\n#{cpp_code}"
      
    ensure
      # Cleanup
      File.delete(temp_file) if File.exist?(temp_file)
      File.delete(binary_file) if File.exist?(binary_file)
    end
  end
end
