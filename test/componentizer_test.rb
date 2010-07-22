require 'rubygems' # Not sure why this is necessary...
require 'test/unit'
require 'lib/componentizer'

class Chook::ComponentizerTest < Test::Unit::TestCase

  def test_componentization
    cz = componentize_fixture("components1.html")
    assert_equal(6, cz.components.size)
    assert_equal("body", cz.components.first.name.downcase)
  end


  def test_empty_components_removed
    cz = componentize_fixture("components2.html")
    assert_equal(5, cz.components.size)
    assert_not_equal("body", cz.components.first.name.downcase)
  end


  def test_writing_components
    cz = componentize_fixture("components1.html")
    cz.write_components(File.join("test", "tmp"))
    assert_equal(
      [
        "test/tmp/part1.xhtml",
        "test/tmp/part2.xhtml",
        "test/tmp/part3.xhtml",
        "test/tmp/part4.xhtml",
        "test/tmp/part5.xhtml",
        "test/tmp/part6.xhtml"
      ],
      Dir.glob("test/tmp/*")
    )
    FileUtils.rm_rf("test/tmp")
  end


  def componentize_fixture(fixture_path)
    fixture = File.new("test/fixtures/#{fixture_path}")
    doc = Nokogiri::HTML::Document.parse(fixture)
    Chook::Componentizer.new(doc.root)
  end

end
