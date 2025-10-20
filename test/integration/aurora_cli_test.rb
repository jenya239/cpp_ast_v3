# frozen_string_literal: true

require_relative "../test_helper"
require "open3"
require "tmpdir"

class AuroraCLITest < Minitest::Test
  CLI = File.expand_path("../../bin/aurora", __dir__)

  def test_run_simple_program
    skip_unless_compiler_available

    Dir.mktmpdir do |dir|
      source = File.join(dir, "main.aur")
      File.write(source, <<~AUR)
        fn main() -> i32 = 0
      AUR

      _stdout, stderr, status = Open3.capture3(CLI, source)

      assert(status.success?, "Expected program to succeed, stderr: #{stderr}")
    end
  end

  def test_run_from_stdin
    skip_unless_compiler_available

    source = <<~AUR
      fn main() -> i32 = 0
    AUR

    _stdout, stderr, status = Open3.capture3(CLI, "-", stdin_data: source)

    assert(status.success?, "Expected execution success, stderr: #{stderr}")
  end

  def test_emit_cpp
    source = <<~AUR
      fn main() -> i32 = 0
    AUR

    stdout, stderr, status = Open3.capture3(CLI, "--emit-cpp", "-", stdin_data: source)

    assert(status.success?, "Expected emit success, stderr: #{stderr}")
    assert_includes stdout, "int main()"
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
