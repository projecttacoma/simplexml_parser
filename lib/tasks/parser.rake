namespace :simplexml do

  desc 'Parse all SimpleXml files in a directory'
  task :parse_all, [:source_dir] do |t, args|

    source_dir = args.source_dir
    outdir = File.join('tmp','parsed')
    FileUtils.rm_r outdir if File.exist? outdir
    FileUtils.mkdir_p outdir

    Dir.glob(File.join(source_dir, '*.xml')).each do |file|
      puts "####################################"
      puts "### processing: #{file}..."
      puts "####################################"

      measure = SimpleXml::Parser::V1Parser.new.parse(File.read(file))
      outfile = File.join(outdir, "#{measure.cms_id}.json")
      File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(measure.to_json)) }
      puts "Wrote: #{outfile}\n"
    end

  end

  desc 'Parse a SimpleXml file'
  task :parse, [:file] do |t, args|

    file = args.file
    outdir = File.join('tmp','parsed')
    FileUtils.rm_r outdir if File.exist? outdir
    FileUtils.mkdir_p outdir

    puts "####################################"
    puts "### processing: #{file}..."
    puts "####################################"

    measure = SimpleXml::Parser::V1Parser.new.parse(File.read(file))
    outfile = File.join(outdir, "#{measure.cms_id}.json")
    File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(measure.to_json)) }
    puts "Wrote: #{outfile}\n"

  end

  desc 'Convert SimpleXml To HQMF R2.1'
  task :convert, [:file] do |t, args|
    model = SimpleXml::Parser::V1Parser.new.parse(File.open(args.file).read)
    # clear out the attributes... we don't have the correct mappings for those
    model.instance_variable_set(:@attributes, [])
    hqmf_xml = HQMF2::Generator::ModelProcessor.to_hqmf(model)
    outdir = File.join('tmp','hqmf_r2')
    FileUtils.mkdir_p outdir

    outfile = File.join(outdir,"#{model.cms_id}_hqmf_r2.xml")
    File.open(outfile, 'w') { |file | file.write(make_xml_pretty(hqmf_xml)) }
    puts "Wrote HQMF R2.1 XML to: #{outfile}"
  end

  def make_xml_pretty(xml_content)
    require "rexml/document"
    doc = REXML::Document.new xml_content
    out = ""
    doc.write(out, 2)
    out
  end

end
