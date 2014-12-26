module DistributedFileServer
  class Cache
    def initialize(persistfolder, max_size = 100)
      @max_size = max_size
      @internal_hash = {}
      @persistfolder = persistfolder
    end

    def fetch(key)
      found = true
      value = @internal_hash.delete(key) { found = false }
      if found
        @internal_hash[key] = value
      else
        yield if block_given?
      end
    end

    def include?(key)
      found = true
      value = @internal_hash.delete(key) { found = false }
      if found
        @internal_hash[key] = value
        true
      else
        false
      end
    end

    def [](key)
      found = true
      value = @internal_hash.delete(key) { found = false }
      if found
        @internal_hash[key] = value
      else
        nil
      end
    end

    def []=(key, val)
      @internal_hash.delete(key)
      @internal_hash[key] = val
      delkey, delval = @internal_hash.delete(@internal_hash.first[0]) if @internal_hash.length > @max_size
      File.open(File.join(@persistfolder, delkey), "w") { |f| f.write delval }
      val
    end

    def each
      @internal_hash.to_a.reverse!.each do |pair|
        yield pair
      end
    end

    def to_a
      @internal_hash.to_a.reverse!
    end

    def delete(key)
      @internal_hash.delete(key)
    end

    def clear
      @internal_hash.clear
    end

    def count
      @internal_hash.count
    end
  end
end