require 'fileutils'
require 'digest'
require_relative '../test_helper'

class SubTreesTest < Test::Unit::TestCase
  RESULTS_DIR = File.join('tmp','with_sub_trees')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_with_sub_trees
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_sub_trees.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    # outfile = File.join("#{RESULTS_DIR}","result.json")
    # File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(simple_xml_model.to_json)) }

    simple_xml_model.all_data_criteria.count.must_equal 11
    simple_xml_model.population_criteria('IPP').preconditions.first.preconditions.count.must_equal 3
    simple_xml_model.data_criteria('GROUP__CHILDREN_11').comments.must_equal ['comment']

  end

  def test_with_satisfies_all
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_satisfies_all.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.all_data_criteria.count.must_equal 8
    simple_xml_model.data_criteria('GROUP_satisfiesAll_CHILDREN_5').derivation_operator.to_s.must_equal 'INTERSECT'
    simple_xml_model.data_criteria('GROUP_satisfiesAll_CHILDREN_5').type.to_s.must_equal "derived"
    simple_xml_model.data_criteria('GROUP_satisfiesAll_CHILDREN_5').definition.to_s.must_equal 'satisfies_all'
  end

  def test_with_satisfies_any
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_satisfies_any.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.all_data_criteria.count.must_equal 8
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_5').derivation_operator.to_s.must_equal 'UNION'
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_5').type.to_s.must_equal "derived"
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_5').definition.to_s.must_equal 'satisfies_any'
  end

end
