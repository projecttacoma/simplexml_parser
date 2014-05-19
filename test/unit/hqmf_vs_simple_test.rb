require 'fileutils'
require 'digest'
require_relative '../test_helper'

class HQMFVsSimpleTest < Test::Unit::TestCase
  RESULTS_DIR = File.join('tmp','hqmf_simple_diffs')

#  HQMF_ROOT = File.join('test', 'fixtures', 'hqmf', '2_4_0_bundle')
  HQMF_ROOT = File.join('test', 'fixtures', 'hqmf', 'eh_2014')

#  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml','2_4_0_bundle')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml','eh_2014')

  # Create a blank folder for the errors
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  # Automatically generate one test method per measure file
  measure_files = File.join(HQMF_ROOT, '*.xml')
  
  Dir.glob(measure_files).each do | measure_filename |
#    measure_name = /.*[\/\\]((ep|eh)_.*)\.xml/.match(measure_filename)[1]
    measure_name = File.basename(measure_filename, ".xml")
    define_method("test_#{measure_name}") do
      do_roundtrip_test(measure_filename, measure_name)
    end
  end

  def do_roundtrip_test(measure_filename, measure_name)
    puts ">> #{measure_name}"
    # parse the model from the V1 XML
    hqmf_model = HQMF::Parser.parse(File.open(measure_filename).read, HQMF::Parser::HQMF_VERSION_1)

    simple_xml = File.join(SIMPLE_XML_ROOT, "#{hqmf_model.cms_id}.xml")
    simple_xml_model = SimpleXml::Parser.parse(File.read(simple_xml), SimpleXml::Parser::SIMPLEXML_VERSION_1)

    hqmf_model.all_data_criteria.sort! {|l,r| l.id <=> r.id}
    simple_xml_model.all_data_criteria.sort! {|l,r| l.id <=> r.id}
    hqmf_model.attributes.sort! {|l,r| l.name <=> r.name}
    simple_xml_model.attributes.sort! {|l,r| l.name <=> r.name}

    hqmf_model.instance_variable_set(:@attributes, [])
    simple_xml_model.instance_variable_set(:@attributes, [])

    # reject the negated source data criteria... these are bad artifacts from HQMF v1.0
    # we also want to pull those from the derived data criteria as well, but not all the negated from there, only the bad from the source data criteria
    hqmf_model.source_data_criteria.reject! {|dc| dc.negation}

    # only compare referenced data criteria since those are the ones that will impact calculation
    referenced_ids = hqmf_model.referenced_data_criteria.map(&:id)
    hqmf_model.all_data_criteria.reject! {|dc| !referenced_ids.include? dc.id }
    referenced_ids = simple_xml_model.referenced_data_criteria.map(&:id)
    simple_xml_model.all_data_criteria.reject! {|dc| !referenced_ids.include? dc.id }

    # Generate new IDs for data criteria in both models by hashing a subset of the fields.
    # Then remap the original IDs created when each model was parsed to the common ID for
    # comparison below.
    remap_ids(hqmf_model)
    remap_ids(simple_xml_model)

    # try to match IDs for data criteria that have changed
    # simple_referenced_dc = simple_xml_model.referenced_data_criteria
    # hqmf_referenced_dc = hqmf_model.referenced_data_criteria

    # simple_referenced_dc.each {|dc| dc.instance_variable_set(:@description, '')}
    # hqmf_referenced_dc.each {|dc| dc.instance_variable_set(:@description, '')}

    # orig_simple_keys = simple_referenced_dc.map {|dc| dc.id }
    # dc_key_translation = get_dc_key_translation(hqmf_referenced_dc, simple_referenced_dc, {})
    # orig_simple_keys.each {|k| puts "NO TRANSLATION FOR: #{k}" unless dc_key_translation[k]}

    # simple_xml_model.all_population_criteria.each do |pc|
    #   update_referenced_ids(pc, dc_key_translation)
    # end


    hqmf_json = JSON.parse(hqmf_model.to_json.to_json)
    simple_xml_json = JSON.parse(simple_xml_model.to_json.to_json)

    # update_v1_json(hqmf_json)
    # update_v2_json(simple_xml_json)

    diff = hqmf_json.diff_hash(simple_xml_json, true, true)

    unless diff.empty?
      outfile = File.join("#{RESULTS_DIR}","#{measure_name}_diff.json")
      File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(diff.to_json))) }
      outfile = File.join("#{RESULTS_DIR}","#{measure_name}_hqmf.json")
      File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(hqmf_json)) }
      outfile = File.join("#{RESULTS_DIR}","#{measure_name}_simplexml.json")
      File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(simple_xml_json)) }
    end

    assert diff.empty?, 'Differences in model between HQMF and SimpleXml... we need a better comparison mechanism'
    
  end

  def remap_ids(measure_model)
    idmap = Hash.new

    # First pass calculates new IDs by hashing various attributes that should be identical in both models
    measure_model.all_data_criteria.each do |dc|
      # generate a SHA256 hash of key fields in the data criteria
      sha256 = Digest::SHA256.new
      sha256.update "#{measure_model.id}:#{measure_model.title}:"
      sha256.update "#{dc.code_list_id}:"
      sha256.update "#{dc.definition}:"
      sha256.update "#{dc.negation}:"
      sha256.update dc.status.nil? ? "<nil>:" : "#{dc.status}:"
      sha256.update dc.negation_code_list_id.nil? ? "<nil>:" : "#{dc.negation_code_list_id}:"
      sha256.update dc.value.nil? ? "<nil>:" : "#{dc.value.type}:"
      if dc.subset_operators.nil?
        sha256.update "<nil>:"
      else
        dc.subset_operators.each do |sso|
          sha256.update "#{sso.type}:"
        end
      end
      sha256.update dc.derivation_operator.nil? ? "<nil>:" : "#{dc.derivation_operator}:"
      idmap[dc.id] = sha256.hexdigest
    end

    # Second pass reassigns IDs using the hash-generated ID
    measure_model.all_data_criteria.each do |dc|
      if ! idmap[dc.id].nil?
        dc.id = idmap[dc.id]
      else
        puts "IDMAP: No mapped ID for data criteria: #{dc.id}"
      end
      unless dc.temporal_references.nil?
        dc.temporal_references.each do |tr|
          if ! idmap[tr.reference.id].nil?
            tr.reference.id = idmap[tr.reference.id]
          else
            puts "IDMAP: No mapped ID for temporal reference: #{tr.reference.id}"
          end
        end
      end
      unless dc.children_criteria.nil?
        dc.children_criteria.each_index do |cci|
          child_id = dc.children_criteria[cci]
          if ! idmap[child_id].nil?
            dc.children_criteria[cci] = idmap[child_id]
          else
            puts "IDMAP: No mapped ID for child criteria: #{child_id}"
          end
        end
      end
    end

    # Now that the data criteria IDs have been remapped, we need to change the
    # references to those data criteria in the population criteria.
    measure_model.all_population_criteria.each do |pc|
      remap_preconditions(idmap, pc.preconditions)
    end
    puts "\nIDMAP DONE\n\n"
  end

  def remap_preconditions(idmap, preconditions)
    if preconditions.nil?
      return
    end

    preconditions.each do |pc|
      remap_preconditions(idmap, pc.preconditions)
      unless pc.reference.nil?
        if ! idmap[pc.reference.id].nil?
          pc.reference.id = idmap[pc.reference.id]
        else
          puts "IDMAP: no mapped ID for #{pc.reference.id}"
        end
      end
    end
  end

  # def get_dc_key_translation(hqmf_referenced_dc, simple_referenced_dc, dc_key_translation)

  #   orig_count = dc_key_translation.keys.count
  #   hqmf_referenced_dc.each do |dc|
  #     hqmf_key = dc.id
  #     match = simple_referenced_dc.select {|sdc| sdc.base_json.diff_hash(dc.base_json, true, true).empty?}

  #     if (match.count > 0)
  #       match = match.first
  #       dc_key_translation[match.id] = hqmf_key
  #     end
  #   end

  #   simple_referenced_dc.each do |dc|
  #     dc.id = dc_key_translation[dc.id] if dc_key_translation[dc.id]
  #     if (dc.temporal_references)
  #       dc.temporal_references.each do |ref|
  #         ref.reference.id = dc_key_translation[ref.reference.id] if dc_key_translation[ref.reference.id]
  #       end
  #     end
  #     if (dc.children_criteria)
  #       dc.children_criteria.map! {|k| dc_key_translation[k] || k}
  #     end
  #   end

  #   dc_key_translation = get_dc_key_translation(hqmf_referenced_dc, simple_referenced_dc, dc_key_translation) if (dc_key_translation.keys.count > orig_count)

  #   dc_key_translation

  # end

  # def update_referenced_ids(precondition, dc_key_translation)
  #   if (precondition.preconditions && !precondition.preconditions.empty?)
  #     precondition.preconditions.each do |child|
  #       update_referenced_ids(child, dc_key_translation)
  #     end
  #   else
  #     if (precondition.respond_to?(:reference) && precondition.reference)
  #       precondition.reference.id = dc_key_translation[precondition.reference.id] if dc_key_translation[precondition.reference.id]
  #     end
  #   end
  # end

end
