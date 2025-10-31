# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class AuroraErrorDiagnosticsTest < Minitest::Test
  def test_compile_error_includes_source_location
    aurora_source = <<~AURORA
      fn main() -> void =
        if true then 1 else 2
    AURORA

    error = assert_raises MLC::CompileError do
      MLC.to_cpp(aurora_source)
    end

    assert_match(/<input>:\d+:\d+: function 'main' should not return a value/, error.message)
  end
end
