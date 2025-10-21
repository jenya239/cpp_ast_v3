# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraCollectionsTest < Minitest::Test
  def test_map_and_filter_lowering
    aurora_source = <<~AUR
      fn clean(lines: str[]) -> str[] =
        lines.map(line => line.trim()).filter(line => !line.is_empty())
    AUR

    cpp = Aurora.to_cpp(aurora_source)

    assert_includes cpp, "aurora::collections::map"
    assert_includes cpp, "aurora::collections::filter"
  end

  def test_fold_lowering
    aurora_source = <<~AUR
      type Stats = { total: i32, warnings: i32 }

      fn accumulate(lines: str[]) -> Stats =
        lines.fold(
          Stats { total: 0, warnings: 0 },
          (acc, line) =>
            if line.upper() == "WARN" then
              Stats { total: acc.total + 1, warnings: acc.warnings + 1 }
            else
              Stats { total: acc.total + 1, warnings: acc.warnings }
        )
    AUR

    cpp = Aurora.to_cpp(aurora_source)

    assert_includes cpp, "aurora::collections::fold"
  end
end
