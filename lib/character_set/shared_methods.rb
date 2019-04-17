#
# Various methods shared by the pure-Ruby and the extended implementation.
#
# Many of these methods are hotspots, so they are defined directly on
# the including classes for better performance.
#
class CharacterSet
  module SharedMethods
    def self.included(klass)
      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        LoadError = Class.new(::LoadError)

        class << self
          def [](*args)
            new(Array(args))
          end

          def parse(string)
            codepoints = Parser.codepoints_from_bracket_expression(string)
            result = new(codepoints)
            string.start_with?('[^') ? result.inversion : result
          end

          def of_property(property_name)
            require_optional_dependency('regexp_property_values')

            property = RegexpPropertyValues[property_name.to_s]
            from_ranges(*property.matched_ranges)
          end

          def of_regexp(regexp)
            require_optional_dependency('regexp_parser')

            root = ::Regexp::Parser.parse(regexp)
            of_expression(root)
          end

          def of_expression(expression)
            ExpressionConverter.convert(expression)
          end

          def require_optional_dependency(name)
            required_optional_dependencies[name] ||= begin
              require name
              true
            rescue ::LoadError
              entry_point = caller_locations.reverse.find do |loc|
                loc.absolute_path.to_s.include?('/lib/character_set')
              end
              method = entry_point && entry_point.label
              raise LoadError, 'You must the install the optional dependency '\
                               "'\#{name}' to use the method `\#{method}'."
            end
          end

          def required_optional_dependencies
            @required_optional_dependencies ||= {}
          end
        end # class << self

        def initialize(enumerable = [])
          merge(Parser.codepoints_from_enumerable(enumerable))
        end

        def replace(enum)
          unless [Array, CharacterSet, Range].include?(enum.class)
            enum = self.class.new(enum)
          end
          clear
          merge(enum)
        end

        # CharacterSet-specific conversion methods

        def assigned
          self & self.class.assigned
        end

        def valid
          self - self.class.surrogate
        end

        # CharacterSet-specific stringification methods

        def to_s(opts = {}, &block)
          Writer.write(ranges, opts, &block)
        end

        def to_s_with_surrogate_alternation
          Writer.write_surrogate_alternation(bmp_part.ranges, astral_part.ranges)
        end

        def inspect
          len = length
          "#<#{klass.name}: {\#{first(5) * ', '}\#{'...' if len > 5}} (size: \#{len})>"
        end

        # C-extension adapter method. Needs overriding in pure fallback.
        # Parsing kwargs in C is slower, verbose, and kinda deprecated.
        # TODO: parse?
        def inversion(include_surrogates: false, upto: 0x10FFFF)
          ext_inversion(include_surrogates, upto)
        end

        #
        # The following methods are here for `Set` compatibility, but they are
        # comparatively slow. Prefer others.
        #
        def map!
          block_given? or return enum_for(__method__) { size }
          arr = []
          each { |cp| arr << yield(cp) }
          replace(arr)
        end
        alias collect! map!

        def reject!(&block)
          block_given? or return enum_for(__method__) { size }
          old_size = size
          delete_if(&block)
          self if size != old_size
        end

        def select!(&block)
          block_given? or return enum_for(__method__) { size }
          old_size = size
          keep_if(&block)
          self if size != old_size
        end
        alias filter! select!

        def classify
          block_given? or return enum_for(__method__) { size }
          each_with_object({}) { |cp, h| (h[yield(cp)] ||= self.class.new).add(cp) }
        end

        def divide(&func)
          block_given? or return enum_for(__method__) { size }
          require 'set'

          if func.arity == 2
            require 'tsort'

            class << dig = {}
              include TSort

              alias tsort_each_node each_key
              def tsort_each_child(node, &block)
                fetch(node).each(&block)
              end
            end

            each do |u|
              dig[u] = a = []
              each{ |v| a << v if yield(u, v) }
            end

            set = Set.new
            dig.each_strongly_connected_component do |css|
              set.add(self.class.new(css))
            end
            set
          else
            Set.new(classify(&func).values)
          end
        end
      RUBY
    end # self.included
  end # SharedMethods
end
