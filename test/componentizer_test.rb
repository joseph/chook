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
        "test/tmp/part1.html",
        "test/tmp/part2.html",
        "test/tmp/part3.html",
        "test/tmp/part4.html",
        "test/tmp/part5.html",
        "test/tmp/part6.html"
      ],
      Dir.glob("test/tmp/*")
    )
    FileUtils.rm_rf("test/tmp")
  end


  def componentize_fixture(fixture_path)
    fixture = File.new("test/fixtures/#{fixture_path}")
    doc = Nokogiri::HTML::Document.parse(fixture)
    cz = Chook::Componentizer.new(doc)
    cz.process(doc.root)
  end

end
