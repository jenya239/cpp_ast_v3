# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class AuroraListComprehensionTest < Minitest::Test
  def test_parse_and_transform_single_generator
    aurora_source = <<~AURORA
      fn double(xs: i32[]) -> i32[] =
        [x * 2 for x in xs]
    AURORA

    ast = MLC.parse(aurora_source)
    func = ast.declarations.first

    assert_instance_of MLC::AST::ListComprehension, func.body

    core = MLC.transform_to_core(ast)
    core_func = core.items.first

    assert_instance_of MLC::HighIR::ListCompExpr, core_func.body
    assert_equal 1, core_func.body.generators.length
    assert_equal "x", core_func.body.generators.first[:var_name]
  end

  def test_lowering_list_comprehension_with_filter
    aurora_source = <<~AURORA
      fn positives(xs: i32[]) -> i32[] =
        [x for x in xs if x > 0]
    AURORA

    cpp = MLC.to_cpp(aurora_source)

    assert_includes cpp, "std::vector<int> result;"
    assert_includes cpp, "for (int x : xs)"
    assert_includes cpp, "if (!(x > 0))"
    assert_includes cpp, "result.push_back(x);"
    assert_includes cpp, "return result;"
  end
end
