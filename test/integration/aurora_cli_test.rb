# frozen_string_literal: true

require_relative "../test_helper"
require "open3"
require "tmpdir"

class AuroraCLITest < Minitest::Test
  CLI = File.expand_path("../../bin/mlc", __dir__)

  def test_run_simple_program
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "main.mlc")
      File.write(source, <<~AUR)
        fn main() -> i32 =
          println("hello")
      AUR

      stdout, stderr, status = Open3.capture3(CLI, source)

      assert(status.success?, "Expected program to succeed, stderr: #{stderr}")
      assert_equal "hello\n", stdout
    end
  end

  def test_run_from_stdin
    skip_unless_compiler_available

    source = <<~AUR
      fn main() -> i32 = println("from-stdin")
    AUR

    stdout, stderr, status = Open3.capture3(CLI, "-", stdin_data: source)

    assert(status.success?, "Expected execution success, stderr: #{stderr}")
    assert_equal "from-stdin\n", stdout
  end

  def test_program_reads_runtime_stdin
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "stdin.mlc")
      File.write(source, <<~AUR)
        fn main() -> i32 = println(read_line())
      AUR

      stdout, stderr, status = Open3.capture3(CLI, source, stdin_data: "hello\n")

      assert(status.success?, "Expected execution success, stderr: #{stderr}")
      assert_equal "hello\n", stdout
    end
  end

  def test_emit_cpp
    source = <<~AUR
      fn main() -> i32 = 0
    AUR

    stdout, stderr, status = Open3.capture3(CLI, "--emit-cpp", "-", stdin_data: source)

    assert(status.success?, "Expected emit success, stderr: #{stderr}")
    assert_includes stdout, "int main()"
  end

  def test_compile_error_includes_filename
    Dir.mktmpdir do |dir|
      source = File.join(dir, "invalid.mlc")
      File.write(source, <<~AUR)
        fn main() -> void =
          if true then 1 else 2
      AUR

      _stdout, stderr, status = Open3.capture3(CLI, source)

      refute status.success?, "Expected compilation failure"
      assert_match(/#{Regexp.escape(source)}:\d+:\d+: function 'main' should not return a value/, stderr)
    end
  end

  def test_pass_arguments
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "args.mlc")
      File.write(source, <<~AUR)
        fn main() -> i32 = println(args()[1])
      AUR

      stdout, stderr, status = Open3.capture3(CLI, source, "--", "program", "value")

      assert(status.success?, "Expected execution success, stderr: #{stderr}")
      assert_equal "value\n", stdout
    end
  end

  def test_let_binding_result_is_exit_code
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "let.mlc")
      File.write(source, <<~AUR)
        fn main() -> i32 =
          let x = 41
          x + 1
      AUR

      stdout, stderr, status = Open3.capture3(CLI, source)

      assert_equal 42, status.exitstatus, "Unexpected exit code, stderr: #{stderr}"
      assert_equal "", stdout
    end
  end

  def test_array_literal_and_methods
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "array.mlc")
      File.write(source, <<~AUR)
        fn count(items: str[]) -> i32 =
          items.length()

        fn main() -> i32 =
          count(["a", "b", "c"])
      AUR

      stdout, stderr, status = Open3.capture3(CLI, source)

      assert_equal 3, status.exitstatus, "Unexpected exit code, stderr: #{stderr}"
      assert_equal "", stdout
    end
  end

  def test_map_filter_fold_pipeline
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "stats.mlc")
      File.write(source, <<~AUR)
        type Stats = { total: i32, warnings: i32, errors: i32 }

        fn normalize(line: str) -> str = line.trim()

        fn is_empty_line(line: str) -> bool = line.trim().is_empty()

        fn detect(line: str) -> str =
          let parts = line.split(":")
          if parts.is_empty() then
            "OTHER"
          else
            parts[0].trim().upper()

        fn update_stats(acc: Stats, level: str) -> Stats =
          if level == "WARN" then
            Stats { total: acc.total + 1, warnings: acc.warnings + 1, errors: acc.errors }
          else if level == "ERROR" then
            Stats { total: acc.total + 1, warnings: acc.warnings, errors: acc.errors + 1 }
          else
            Stats { total: acc.total + 1, warnings: acc.warnings, errors: acc.errors }

        fn main() -> i32 =
          let lines = input().split("\n")
          let clean = lines.map((line: str) => normalize(line)).filter((line: str) => !is_empty_line(line))
          let levels = clean.map((line: str) => detect(line))
          let stats = levels.fold(
            Stats { total: 0, warnings: 0, errors: 0 },
            (acc: Stats, level: str) => update_stats(acc, level)
          )
          if stats.errors == 1 then
            0
          else
            1
      AUR

      input = <<~LOG
        INFO: Start
        WARN: Slow response
        ERROR: Connection failed
        INFO: Done
      LOG

      _stdout, stderr, status = Open3.capture3(CLI, source, stdin_data: input)

      assert(status.success?, "Expected execution success, stderr: #{stderr}")
    end
  end

  private

  def skip_unless_compiler_available
    return if @compiler_checked

    @compiler_checked = true
    compiler = ENV.fetch("CXX", "g++")
    available = system("#{compiler} --version > /dev/null 2>&1")
    skip "C++ compiler (#{compiler}) not available" unless available
  end
end
