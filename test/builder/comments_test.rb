# frozen_string_literal: true

require_relative "../test_helper"

class CommentsTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_inline_comment
    comment = inline_comment("This is a comment")
    assert_equal "// This is a comment", comment.to_source
  end
  
  def test_block_comment
    comment = block_comment("This is a block comment")
    assert_equal "/* This is a block comment */", comment.to_source
  end
  
  def test_doxygen_inline_comment
    comment = doxygen_comment("This is doxygen", style: :inline)
    assert_equal "/// This is doxygen", comment.to_source
  end
  
  def test_doxygen_block_comment
    comment = doxygen_comment("This is doxygen block", style: :block)
    assert_equal "/** This is doxygen block */", comment.to_source
  end
  
  def test_doc_comment_helper
    comment = doc_comment("This is documentation")
    assert_equal "/** This is documentation */", comment.to_source
  end
  
  def test_comment_with_leading_trivia
    comment = inline_comment("Comment with leading")
    comment = comment.with_leading("  ")
    assert_equal "  // Comment with leading", comment.to_source
  end
  
  def test_comments_in_program
    program = program(
      inline_comment("Start of program"),
      var_decl("int", "x"),
      block_comment("End of program")
    )
    
    expected = <<~CPP.strip + "\n"
      // Start of program
      int x;
      /* End of program */
    CPP
    
    assert_equal expected, program.to_source
  end
  
  def test_doxygen_documentation
    program = program(
      doc_comment("This class represents a point in 2D space"),
      class_decl("Point", 
        public_section(
          var_decl("double", "x"),
          var_decl("double", "y")
        )
      )
    )
    
    expected = <<~CPP.strip
      /** This class represents a point in 2D space */
      class Point {
      public:
        double x;
        double y;
      };
    CPP
    
    assert_includes program.to_source, "This class represents a point in 2D space"
    assert_includes program.to_source, "class Point"
    assert_includes program.to_source, "double x"
    assert_includes program.to_source, "double y"
  end
end
