namespace :hqmf do
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

        measure = SimpleXml::Document.new(File.read file).to_model
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

      measure = SimpleXml::Document.new(File.read file).to_model
      outfile = File.join(outdir, "#{measure.cms_id}.json")
      File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(measure.to_json)) }
      puts "Wrote: #{outfile}\n"

    end

  end
end
