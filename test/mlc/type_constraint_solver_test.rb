# frozen_string_literal: true

require_relative "../test_helper"
require "ostruct"

class TypeConstraintSolverTest < Minitest::Test
  Info = Struct.new(:type_params, :param_types, :ret_type)

  def build_solver(ensure_compatible_type: nil, type_error: nil, infer_type_arguments: nil)
    MLC::TypeSystem::TypeConstraintSolver.new(
      infer_type_arguments: infer_type_arguments || method(:mock_infer_type_arguments),
      substitute_type: ->(type, map) { substitute(type, map) },
      ensure_compatible_type: ensure_compatible_type || ->(_actual, _expected, _context = {}) {},
      type_error: type_error || ->(message) { raise message }
    )
  end

  def mock_infer_type_arguments(type_params, _param_types, args)
    inferred = args.last
    inferred = inferred.type if inferred.respond_to?(:type)
    type_params.to_h { |tp| [tp.name, inferred] }
  end

  def substitute(type, map)
    return map[type] if type.is_a?(String) && map.key?(type)
    type
  end

  def test_solver_instantiates_generic_return_type
    solver = build_solver
    type_params = [OpenStruct.new(name: "T")]
    info = Info.new(type_params, ["Option<i32>", "T"], "T")
    args = [OpenStruct.new(type: "Option<i32>"), OpenStruct.new(type: "i32")]

    inst = solver.solve(info, args, name: "unwrap")

    assert_equal ["Option<i32>", "i32"], inst.param_types
    assert_equal "i32", inst.ret_type
  end

  def test_solver_checks_argument_count
    captured = []
    solver = build_solver(
      type_error: ->(message) { captured << message; raise ArgumentError, message }
    )

    info = Info.new([], ["i32"], "i32")
    args = [
      OpenStruct.new(type: "i32"),
      OpenStruct.new(type: "i32")
    ]

    error = assert_raises(ArgumentError) do
      solver.solve(info, args, name: "add")
    end

    assert_match(/expects 1 argument/, error.message)
    refute_empty captured
  end

  def test_solver_propagates_type_mismatches
    ensure_calls = []
    solver = build_solver(
      ensure_compatible_type: lambda do |actual, expected, context|
        ensure_calls << [actual, expected, context]
        raise MLC::CompileError, "Mismatch" unless actual == expected
      end,
      infer_type_arguments: lambda do |type_params, _param_types, _args|
        type_params.to_h { |tp| [tp.name, "i32"] }
      end
    )

    type_params = [OpenStruct.new(name: "T")]
    info = Info.new(type_params, ["T"], "T")
    args = [OpenStruct.new(type: "Option<i32>")]

    assert_raises(MLC::CompileError) do
      solver.solve(info, args, name: "unwrap")
    end

    assert_equal 1, ensure_calls.length
    assert_equal "argument 1 of 'unwrap'", ensure_calls.first[2]
  end

  def test_solver_uses_substituted_parameter_types
    ensure_type_calls = []
    solver = build_solver(
      ensure_compatible_type: lambda do |actual, expected, _context|
        ensure_type_calls << [actual, expected]
      end
    )

    type_params = [OpenStruct.new(name: "T")]
    info = Info.new(type_params, ["T", "T"], "T")
    args = [
      OpenStruct.new(type: "Option<i32>"),
      OpenStruct.new(type: "Option<i32>")
    ]

    inst = solver.solve(info, args, name: "merge")

    assert_equal 2, ensure_type_calls.length
    assert_equal ["Option<i32>", "Option<i32>"], inst.param_types
    assert_equal "Option<i32>", inst.ret_type
  end
end
