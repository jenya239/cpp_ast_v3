# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class AuroraIOTest < Minitest::Test
  def test_print_lowering
    aurora_source = <<~AUR
      fn main() -> i32 = println("hello")
    AUR

    cpp = MLC.to_cpp(aurora_source)

    assert_includes cpp, "aurora::io::println"
    assert_includes cpp, 'aurora::String("hello")'
  end

  def test_read_line_and_args_lowering
    aurora_source = <<~AUR
      fn main() -> str = read_line()
      fn second() -> str[] = args()
    AUR

    cpp = MLC.to_cpp(aurora_source)

    assert_includes cpp, "aurora::io::read_line"
    assert_includes cpp, "aurora::io::args"
  end
end
