require 'fileutils'
require 'digest'
require_relative '../test_helper'

class TimingOperatorsTest < Test::Unit::TestCase
  RESULTS_DIR = File.join('tmp','with_timing_operators')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_with_missing_oids
    simple_xml = File.join(SIMPLE_XML_ROOT, "all_timing_operators.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_143').derivation_operator.to_s.must_equal 'UNION'
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_143').type.to_s.must_equal "derived"
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_143').definition.to_s.must_equal 'satisfies_any'
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_143').children_criteria.length.must_equal 25

    # verify MATv4.0.0 timing operators are correctly handled for HQMF2JS calculations
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_93').temporal_references[0].type.to_s.must_equal 'CONCURRENT'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_95').temporal_references[0].type.to_s.must_equal 'DURING'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_97').temporal_references[0].type.to_s.must_equal 'EAE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_99').temporal_references[0].type.to_s.must_equal 'EACW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_101').temporal_references[0].type.to_s.must_equal 'EACWS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_103').temporal_references[0].type.to_s.must_equal 'EAS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_105').temporal_references[0].type.to_s.must_equal 'EBE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_107').temporal_references[0].type.to_s.must_equal 'EBCW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_109').temporal_references[0].type.to_s.must_equal 'EBCWS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_111').temporal_references[0].type.to_s.must_equal 'EBS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_113').temporal_references[0].type.to_s.must_equal 'ECW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_115').temporal_references[0].type.to_s.must_equal 'ECWS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_117').temporal_references[0].type.to_s.must_equal 'EDU'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_119').temporal_references[0].type.to_s.must_equal 'OVERLAP'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_121').temporal_references[0].type.to_s.must_equal 'SAE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_123').temporal_references[0].type.to_s.must_equal 'SACWE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_125').temporal_references[0].type.to_s.must_equal 'SACW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_127').temporal_references[0].type.to_s.must_equal 'SAS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_129').temporal_references[0].type.to_s.must_equal 'SBE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_131').temporal_references[0].type.to_s.must_equal 'SBCWE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_133').temporal_references[0].type.to_s.must_equal 'SBCW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_135').temporal_references[0].type.to_s.must_equal 'SBS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_137').temporal_references[0].type.to_s.must_equal 'SCW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_139').temporal_references[0].type.to_s.must_equal 'SCWE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_141').temporal_references[0].type.to_s.must_equal 'SDU'
  end

end
