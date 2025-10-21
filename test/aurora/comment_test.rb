# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraCommentTest < Minitest::Test
  def test_block_comment_between_statements
    source = <<~AUR
      fn main() -> i32 =
        /* compute result */
        42
    AUR

    ast = Aurora.parse(source)
    assert_equal 1, ast.declarations.size

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "return 42;"
  end

  def test_multiline_block_comment_is_ignored
    source = <<~AUR
      fn value() -> i32 =
        /* comment line 1
           comment line 2 */
        7
    AUR

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "return 7;"
  end

  def test_doc_comment_like_syntax_does_not_break
    source = <<~AUR
      // overall description
      fn flag() -> bool =
        /// doc comment
        /* block doc */
        true
    AUR

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "return true;"
  end
end
