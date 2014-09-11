require 'fileutils'
require 'digest'
require_relative '../test_helper'

class DateTimeDiffTest < Test::Unit::TestCase
  RESULTS_DIR = File.join('tmp','datetimediff')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_date_time_diff
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_datetimediff.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.all_data_criteria.count.must_equal 21
    simple_xml_model.populations.count.must_equal 4

    observ = simple_xml_model.population_criteria('OBSERV')
    observ.aggregator.must_equal "MEDIAN"
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    dc.subset_operators.count.must_equal 1
    dc.subset_operators[0].type.must_equal "DATETIMEDIFF"

    observ = simple_xml_model.population_criteria('OBSERV_1')
    observ.aggregator.must_equal "MEDIAN"
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    dc.subset_operators.count.must_equal 1
    dc.subset_operators[0].type.must_equal "DATETIMEDIFF"

    observ = simple_xml_model.population_criteria('OBSERV_2')
    observ.aggregator.must_equal "MEDIAN"
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    dc.subset_operators.count.must_equal 1
    dc.subset_operators[0].type.must_equal "DATETIMEDIFF"

    observ = simple_xml_model.population_criteria('OBSERV_3')
    observ.aggregator.must_equal "MEDIAN"
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    dc.subset_operators.count.must_equal 1
    dc.subset_operators[0].type.must_equal "DATETIMEDIFF"
    comparison = dc.subset_operators[0].value.low
    comparison.type.must_equal "PQ"
    comparison.unit.must_equal "d"
    comparison.value.must_equal "3"


  end


end
