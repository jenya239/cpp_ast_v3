# frozen_string_literal: true

require_relative "../test_helper"

class ComplexClassTest < Minitest::Test
  # Real-world case from gtk-gl-cpp-2025
  def test_class_with_nested_struct_and_methods
    source = <<~CPP
      class DemoManager {
      public:
          struct DemoInfo {
              std::string id;
              std::string name;
          };

          void register_demo(const std::string& id) {
              demos_[id] = DemoInfo{id, name};
          }

      private:
          std::map<std::string, DemoInfo> demos_;
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Complex class with nested struct and methods"
  end
  
  # Simpler version
  def test_struct_with_template_types
    source = <<~CPP
      struct DemoInfo {
          std::string id;
          std::function<int()> factory;
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Struct with template types"
  end
  
  # Method with initializer in body
  def test_method_with_brace_initializer
    source = <<~CPP
      class Foo {
          void bar() {
              x = Bar{1, 2};
          }
      };
    CPP
    
    program = CppAst.parse(source)
    output = program.to_source
    
    assert_equal source, output, "Method with brace initializer"
  end
end

