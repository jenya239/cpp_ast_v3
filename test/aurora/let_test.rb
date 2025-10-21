# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraLetTest < Minitest::Test
  def test_let_lowering_generates_lambda_iife
    aurora_source = <<~AUR
      fn main() -> i32 =
        let x = 1
        x + 1
    AUR

    cpp = Aurora.to_cpp(aurora_source)

    refute_includes cpp, "[&]()"
    assert_includes cpp, "const int x = 1;"
    assert_includes cpp, "return x + 1;"
  end
end
