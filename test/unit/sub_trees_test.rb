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

    simple_xml_model.all_data_criteria.count.must_equal 13
    simple_xml_model.population_criteria('IPP').preconditions.first.preconditions.count.must_equal 3
    simple_xml_model.population_criteria('IPP').preconditions.first.comments.must_equal ['a real comment']

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

  def test_with_variable
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_variable.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.all_data_criteria.count.must_equal 9
    simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').derivation_operator.to_s.must_equal 'XPRODUCT'
    simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').type.to_s.must_equal "derived"
    simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').definition.to_s.must_equal 'derived'
    simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').variable.must_equal true

    simple_xml_model.source_data_criteria[6].derivation_operator.to_s.must_equal 'XPRODUCT'
    simple_xml_model.source_data_criteria[6].type.to_s.must_equal "derived"
    simple_xml_model.source_data_criteria[6].definition.to_s.must_equal 'derived'
    simple_xml_model.source_data_criteria[6].variable.must_equal true
  end

  def test_with_during_intersection
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_during_intersection.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    ipp = simple_xml_model.population_criteria('IPP')
    ipp.preconditions.count.must_equal 1
    ipp.preconditions.first.conjunction_code.must_equal "allTrue"
    ipp.preconditions.first.preconditions.count.must_equal 1
    ipp.preconditions.first.preconditions.first.reference.id.must_equal "GROUP_INTERSECT_CHILDREN_19"

    simple_xml_model.all_data_criteria.count.must_equal 12

    intersection = simple_xml_model.data_criteria('GROUP_INTERSECT_CHILDREN_19')
    intersection.derivation_operator.to_s.must_equal 'INTERSECT'
    intersection.children_criteria.size.must_equal 2
    intersection.temporal_references.size.must_equal 1
    intersection.temporal_references.first.type.must_equal 'DURING'
    intersection.temporal_references.first.reference.id.must_equal 'GROUP_UNION_CHILDREN_10'
  end

  def test_with_age_at_with_birthdate
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_age_at_with_birthdate.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.all_data_criteria.count.must_equal 9
    simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').definition.to_s.must_equal 'patient_characteristic_birthdate'
    simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').temporal_references[0].type.to_s.must_equal 'SBS'
  end

  def test_with_age_at_without_birthdate
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_age_at_without_birthdate.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.all_data_criteria.count.must_equal 8
    simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').definition.to_s.must_equal 'patient_characteristic_birthdate'
    simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').temporal_references[0].type.to_s.must_equal 'SBS'
  end

end
