require 'rubygems' # Not sure why this is necessary...
require 'test/unit'
require 'lib/outliner'

class Chook::OutlinerTest < Test::Unit::TestCase

  def test_spec_1
    load_spec_and_compare_out('spec1')
  end


  def test_spec_2
    load_spec_and_compare_out('spec2')
  end


  def test_spec_3a
    load_spec_and_compare_out('spec3a')
  end


  def test_spec_3b
    load_spec_and_compare_out('spec3b')
  end


  def test_spec_4
    load_spec_and_compare_out('spec4')
  end


  def load_spec_and_compare_out(spec_name, to_html_options = {})
    to_html_options = {
      :title_empty_sections => true,
      :heading_wrapper => false
    }.merge(to_html_options)
    src_file = File.new("test/fixtures/#{spec_name}.doc.html")
    cmp_file = File.new("test/fixtures/#{spec_name}.out.html")
    doc = Nokogiri::HTML::Document.parse(src_file)
    outliner = Chook::Outliner.new(doc.root)
    outliner.process(doc.root)
    out = outliner.to_html(to_html_options).gsub(/\s+/, '')
    cmp = cmp_file.read.gsub(/\s+/, '')
    assert_equal(cmp, out)
  end

end
