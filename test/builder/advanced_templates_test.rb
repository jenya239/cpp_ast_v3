# frozen_string_literal: true

require_relative "../test_helper"

class AdvancedTemplatesTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_variadic_template_class
    klass = variadic_template_class("Container", "T")
    assert_includes klass.to_source, "template"
    assert_includes klass.to_source, "typename T"
    assert_includes klass.to_source, "typename... Args"
    assert_includes klass.to_source, "class Container"
  end
  
  def test_variadic_template_function
    func = variadic_template_function("void", "process", "T")
    assert_includes func.to_source, "template"
    assert_includes func.to_source, "typename T"
    assert_includes func.to_source, "typename... Args"
    assert_includes func.to_source, "void process"
  end
  
  def test_template_template_param
    param = template_template_param("Container", ["typename T"])
    assert_equal "template<typename T> class Container", param
  end
  
  def test_sfinae_requires
    requires = sfinae_requires("Drawable", "T")
    assert_equal "requires Drawable<T>", requires
  end
  
  def test_concept_declaration
    concept = concept_decl("Drawable", ["typename T"], "requires(T t) { t.draw(); }")
    assert_equal "template<typename T>\nconcept Drawable = requires(T t) { t.draw(); };", concept.to_source
  end
  
  def test_complex_concept
    concept = concept_decl("Serializable", 
      ["typename T"], 
      "requires(T t) { t.serialize(); t.deserialize(); }"
    )
    
    expected = "template<typename T>\nconcept Serializable = requires(T t) { t.serialize(); t.deserialize(); };"
    assert_equal expected, concept.to_source
  end
  
  def test_concept_with_multiple_params
    concept = concept_decl("Comparable", 
      ["typename T", "typename U"], 
      "requires(T t, U u) { t < u; t > u; t == u; }"
    )
    
    expected = "template<typename T, typename U>\nconcept Comparable = requires(T t, U u) { t < u; t > u; t == u; };"
    assert_equal expected, concept.to_source
  end
  
  def test_advanced_template_example
    program = program(
      # Concept definition
      concept_decl("Drawable", ["typename T"], "requires(T t) { t.draw(); }"),
      
      # Variadic template class
      variadic_template_class("Vector", "T"),
      
      # Simple template function
      template_decl(["typename T"], 
        function_decl("void", "draw_if_drawable", [
          param("T", "obj")
        ], block(
          expr_stmt(call(id("obj"), "draw", []))
        ))
      )
    )
    
    assert_includes program.to_source, "concept Drawable"
    assert_includes program.to_source, "template"
    assert_includes program.to_source, "typename... Args"
    assert_includes program.to_source, "class Vector"
    assert_includes program.to_source, "void draw_if_drawable"
  end
  
  def test_template_specialization
    # Primary template
    primary = template_decl(["typename T"], class_decl("Container"))
    
    # Specialization
    specialization = template_decl([], class_decl("Container<int>"))
    
    assert_includes primary.to_source, "template"
    assert_includes primary.to_source, "typename T"
    assert_includes specialization.to_source, "template"
  end
  
  def test_variadic_template_with_constraints
    program = program(
      # Concept
      concept_decl("Arithmetic", ["typename T"], "requires(T t) { t + t; t - t; t * t; }"),
      
      # Variadic function with constraints
      template_decl(["typename... Args"], 
        function_decl("auto", "sum", [
          param("Args...", "args")
        ], block(
          return_stmt(call(id("std::reduce"), [id("args...")]))
        ))
      )
    )
    
    assert_includes program.to_source, "concept Arithmetic"
    assert_includes program.to_source, "template"
    assert_includes program.to_source, "typename... Args"
    assert_includes program.to_source, "auto sum"
    assert_includes program.to_source, "Args... args"
  end
end
