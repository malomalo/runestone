class Runestone::Settings

  attr_reader :indexes, :dictionary
  
  def initialize(model, name: , dictionary: , &block)
    @name = name
    @dictionary = dictionary
    @indexes = {}
    instance_exec(&block)
  end

  def index(*args, weight: 1)
    @indexes[weight] = args.map(&:to_s)
  end

  def attribute(*names, &block)
    deps = if block_given? and names.length > 2
      raise ArgumentError.new('Cannot pass multiple attribute names if block given')
    else
      names.length > 1 ? names.pop : names.first
    end
    deps = deps.to_s if !deps.is_a?(Proc)

    @attributes ||= {}
    names.each do |name|
      @attributes[name.to_sym] = [block ? block : nil, deps]
    end
  end
  alias :attributes :attribute

  def extract_attributes(record)
    attributes = {}

    @attributes.each do |name, value|
      attributes[name] = if value[0].is_a?(Proc)
        record.instance_exec(&value[0])
      else
        rv = record.send(name)
      end
    end

    remove_nulls(attributes)
  end

  def changed?(record)
    @attributes.detect do |name, value|
      if value[1].is_a?(Proc)
        record.instance_exec(&value[1])
      elsif record.attribute_names.include?(value[1])
        record.previous_changes.has_key?(value[1])
      elsif record._reflections[value[1]] && association = record.association(value[1])
        association.loaded? && association.changed_for_autosave?
      end
    end
  end
  
  def vectorize(data)
    conn = Runestone::Model.connection
    tsvector = []

    @indexes.each do |weight, paths|
      tsweight = {4 => 'D', 3 => 'C', 2 => 'B', 1 => 'A'}[weight]
      paths.each do |path|
        path = path.to_s.split('.')
        
        dig(data, path).each do |value|
          next if !value
          language = value.to_s.size <= 5 ? 'simple' : @dictionary
          tsvector << "setweight(to_tsvector(#{conn.quote(language)}, #{conn.quote(value.to_s.downcase)}), #{conn.quote(tsweight)})"
        end
      end
    end
    tsvector.empty? ? ["to_tsvector('')"] : tsvector
  end
  
  def corpus(data)
    words = []
    
    @indexes.each do |weight, paths|
      paths.each do |path|
        dig(data, path.to_s.split('.')).each do |value|
          next if !value
          value.to_s.split(/\s+/).each do |word|
            words << word.downcase.gsub(/\A\W/, '').gsub(/\W\Z/, '')
          end
        end
      end
    end
    
    words
  end

  def remove_nulls(value)
    if value.is_a?(Hash)
      nh = {}
      value.each do |k, v|
        nh[k] = if v.is_a?(Hash) || v.is_a?(Array)
          remove_nulls(v)
        elsif !v.nil?
          v.is_a?(String) ? v.unicode_normalize(:nfc) : v
        end
        nh.delete(k) if nh[k].nil? || (nh[k].is_a?(Hash) && nh[k].empty?)
      end
      nh
    elsif value.is_a?(Array)
      value.select{|i| !i.nil? && !i.empty? }.map { |i| remove_nulls(i) }
    else
      value
    end
  end

  def dig(data, keys)
    if data.is_a?(Hash)
      key = keys.shift
      dig(data[key.to_sym] || data[key.to_s], keys)
    elsif data.is_a?(Array)
      data.map{ |d| dig(d, keys.dup) }.flatten.compact
    else
      [data]
    end
  end

end