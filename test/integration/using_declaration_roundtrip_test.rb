# frozen_string_literal: true

require_relative "../test_helper"

class UsingDeclarationRoundtripTest < Minitest::Test
  def test_using_namespace_simple
    source = "using namespace std;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_namespace_nested
    source = "using namespace std::chrono;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_namespace_with_spaces
    source = "using  namespace  std ;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_simple_name
    source = "using std::vector;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_nested_name
    source = "using std::chrono::seconds;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_type_alias
    source = "using MyInt = int;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_type_alias_complex
    source = "using StringVector = std::vector<std::string>;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_type_alias_with_spaces
    source = "using MyInt  =  int ;\n"
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_multiple_using_declarations
    source = <<~CPP
      using namespace std;
      using std::vector;
      using MyInt = int;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_with_comments
    source = <<~CPP
      // Import std namespace
      using namespace std;
      
      /* Type alias for convenience */
      using MyInt = int;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_using_in_real_code_context
    source = <<~CPP
      #include <vector>
      
      using namespace std;
      using MyVec = vector<int>;
      
      int main() {
          MyVec v;
          return 0;
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

