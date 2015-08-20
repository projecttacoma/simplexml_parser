require 'fileutils'
require 'digest'
require_relative '../test_helper'

class MissingOidsTest < Minitest::Test
  RESULTS_DIR = File.join('tmp','with_missing_oids')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_with_missing_oids
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_missing_oids.xml")
    exception = assert_raises(RuntimeError) { SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml)) }
    assert_equal( "All QDM elements require VSAC value sets to load into Bonnie. This measure contains 2 QDM elements without VSAC value sets: \n[ Medication, Administered: Warfarin, Encounter, Performed: Inpatient ].", exception.message )
  end

end
