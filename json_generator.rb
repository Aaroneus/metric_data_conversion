require 'json'
require 'nokogiri'
require 'ruby-debug'

# Todo Tomorrow
# Parse UCUM into JSON that can be used by the app based on structure on pad.
# Once JSON is created, work on calculation algorithm to do conversions into chosen units.


begin

    Lookup = Struct.new(:id, :unit, :symbols, :measures, :conversion_factor_to, :class, :metric) do
      def to_json(*a)
        {:id => self.id, :unit => self.unit, :symbols => self.symbols, :measures => self.measures, :conversion_factor_to => self.conversion_factor_to, :class => self.class, :metric => self.metric}.to_json
      end

      def self.json_create(o)
        new(o['id'], o['unit'], o['symbols'], o['measures'], o['conversion_factor_to'], o['class'], o['metric'])
      end
    end

    ConversionFactor = Struct.new(:convert_to, :conversion_factor) do
      def to_json(*a)
        {:convert_to => self.convert_to, :conversion_factor => self.conversion_factor}.to_json
      end

      def self.json_create(o)
        new(o['convert_to'], o['conversion_factor'])
      end
    end

    file = File.open("metric_conversion_factors", "r")
    outfile = File.new("generated_json.json", "a+")
    parsed_text = []
    all_units = []
    uniq_units = []

    while (line = file.gets)
       #Cache original Text
       parsed_text << line
    end

    #Close input file
    file.close

    parsed_text.each do |line|
      units = line.split('---->')

      all_units << units[0].strip
      all_units << units[1].strip
    end

    puts "Number of uncleaned units "+ all_units.size.to_s
    uniq_units = all_units.uniq
    puts "Number of unique units "+ uniq_units.size.to_s

    lookups = []
    puts "Populating Array..."
    count = 0
    outfile.write("[")
    #Populate a lookup Array
    uniq_units.each do |unit|
      lookup = Lookup.new
      lookup.unit = unit
      parsed_text.each do |line|
        count = count + 1
        split_line = line.split('---->')
        if(split_line[0].strip == lookup.unit)

          c = ConversionFactor.new(split_line[1].strip, split_line[2].strip.gsub("c.f.== ", "").to_f)
          if (lookup.conversion_factor_to)
            lookup.conversion_factor_to << c
          else
           lookup.conversion_factor_to = []
           lookup.conversion_factor_to << c
          end
        end
      end
      # Write to file
      outfile.write(lookup.to_json)
      lookups << lookup
      count = 0
    end
    outfile.write("]")
    puts "Unique Lookups Found: #{lookups.length}"

    outfile.close
    # puts lookups

    # parse UCUM file
    puts("***********UCUM**********************")
    ucum = File.open("ucum-essence.xml", "r")
    doc = Nokogiri::XML(ucum)

    prefixes = []
    doc.xpath("//prefix").each do |p|
      prefixes << Nokogiri::HTML(p.xpath('name/text()').to_s).text
    end

    puts "Prefixes found: #{prefixes.length}"

    # doc.xpath("//base-unit").each do |bu|
    #   puts "**Found #{bu.xpath('name/text()')}, Sym: #{bu.xpath('printSymbol/text()')}, Measures: #{bu.xpath('property/text()')} "
    # end

    counter = 0
    matched = 0

    doc.xpath("//base-unit","//unit").each do |u|
      name = Nokogiri::HTML(u.xpath('name/text()').to_s).text
      property = Nokogiri::HTML(u.xpath('property/text()').to_s).text
      metric = u.attr('isMetric').to_s || ""
      # puts "Evaluating #{name}; #{property}; #{metric}"

      lookups.each do |l|
        if l.unit.casecmp(name) == 0
          l.measures = property
          puts "**Lookup #{l.unit} and UCUM #{name} measure #{l.measures}"
          matched = matched + 1
          # break
        elsif (l.unit+"s").casecmp(name) == 0
          l.measures = property
          # puts "**#{l.unit} measures #{l.measures}"
          matched = matched + 1
          # break
        elsif metric == "yes"
          prefixes.each do |p|
            prefixed_unit = p + l.unit   
            # puts "Checking #{prefixed_unit}"         
            if prefixed_unit.casecmp(name) == 0
              l.measures = property
              matched = matched + 1
            elsif (prefixed_unit + "s").casecmp(name) == 0
              l.measures = property
              matched = matched + 1
            end

            # puts "**#{prefixed_unit} measures #{l.measures}"
            
            # break
          end
        end
      end
      counter = counter + 1
    end
    puts "Evaluated #{counter} units from UCUM"
    puts "Matched #{matched} units from UCUM"
    # lookups.each do |l|
    #   # puts l.unit
    # end

    ucum.close



rescue => err
    puts "Exception: #{err}"
    err
end


