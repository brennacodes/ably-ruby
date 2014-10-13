module Ably::Modules
  # Enum brings Enum like functionality used in other languages to Ruby
  #
  # @example
  #   class House
  #     extend Ably::Moduels::Enum
  #     CONSTRUCTION = ruby_enum('CONSTRUCTION',
  #       :brick,
  #       :steel,
  #       :wood
  #     )
  #   end
  #
  #   House::CONSTRUCTION(:brick).to_i # => 0
  #   House::CONSTRUCTION('Wood').to_i # => 2
  #   House::CONSTRUCTION.Wood == :wood # => true
  #
  module Enum
    # ruby_enum returns an Enum-like class that should be assigned to a constant in your class
    # The first `enum_name` argument must match the constant name so that the coercion method is available
    #
    # @example
    #   class House
    #     extend Ably::Moduels::Enum
    #     CONSTRUCTION = ruby_enum('CONSTRUCTION', :brick)
    #   end
    #
    #   # ensures the following coercion method is available
    #   House::CONSTRUCTION(:brick) # => CONSTRUCTION.Brick
    #
    def ruby_enum(enum_name, *values)
      enum_class = Class.new do
        include Conversions
        extend Conversions

        @enum_name = enum_name
        @by_index  = {}
        @by_symbol = {}

        class << self
          def get(identifier)
            case identifier
            when Symbol
              by_symbol.fetch(identifier)
            when String
              by_symbol.fetch(convert_to_snake_case_symbol(identifier))
            when Numeric
              by_index.fetch(identifier)
            when ancestors.first
              identifier
            else
              raise KeyError, "Cannot find Enum matching identifier '#{identifier}' argument as it is an unacceptable type: #{identifier.class}"
            end
          end

          def [](*args)
            get(*args)
          end

          def to_s
            name
          end

          def size
            by_symbol.keys.length
          end
          alias_method :length, :size

          # The name provided in the constructor for this Enum
          def name
            @enum_name
          end

          private
          attr_reader :by_index, :by_symbol

          # Define constants for each of the Enum values
          # e.g. define_constants(:dog) creates Enum::Dog
          def define_values(values)
            raise RuntimeError, "#{name} Enum cannot be modified" if by_index.frozen?

            values.map do |value|
              # Convert any key => index_value pairs into array pairs
              Array(value)
            end.flatten(1).each_with_index do |name, index|
              name, index = name if name.kind_of?(Array) # name is key => index_value pair
              raise ArgumentError, "Index value '#{index}' is invalid" unless index.kind_of?(Numeric)

              camel_name  = convert_to_mixed_case(name, force_camel: true)
              name_symbol = convert_to_snake_case_symbol(name)
              enum        = new(camel_name, name_symbol, index.to_i)

              by_index[index.to_i]   = enum
              by_symbol[name_symbol] = enum

              define_singleton_method camel_name do
                enum
              end
            end

            by_index.freeze
            by_symbol.freeze
          end
        end

        def initialize(name, symbol, index)
          @name   = name
          @index  = index
          @symbol = symbol
        end

        def to_s
          "#{self.class}.#{name}"
        end

        def to_i
          index
        end

        def to_sym
          symbol
        end

        def to_json(*args)
          %{"#{symbol}"}
        end

        # Allow comparison of Enum objects based on:
        #
        # * Other equivalent Enum objects
        # * Symbol
        # * String
        # * Integer index of Enum
        #
        def ==(other)
          case other
          when Symbol
            self.to_sym == convert_to_snake_case_symbol(other)
          when String
            self.to_sym == convert_to_snake_case_symbol(other)
          when Numeric
            self.to_i == other.to_i
          when self.class
            self.to_i == other.to_i
          else
            false
          end
        end

        private
        attr_reader :name, :index, :symbol

        define_values values
      end

      # Convert any comparable object into this Enum
      # @example
      #
      #   class Example
      #     DOGS = ruby_enum('DOGS', :terrier, :labrador, :great_dane)
      #   end
      #
      #   Example.DOGS(:great_dane) # => <DOGS.GreatDane>
      #   Example.DOGS(0) # => <DOGS.Terrier>
      #   Example.new.DOGS(0) # => <DOGS.Terrier>
      #
      define_singleton_method enum_name do |val|
        enum_class.get(val)
      end

      define_method enum_name do |val|
        enum_class.get(val)
      end

      enum_class
    end
  end
end