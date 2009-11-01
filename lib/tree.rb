require 'ostruct'

module Tequila

  class Tree

    attr_reader :root

    def initialize
      @root = OpenStruct.new({:name => :root})
      @tree = { @root => [] }
    end

    def add_child_to(branch, child)
      @tree[branch] ||= []
      @tree[branch] << child
    end

    def parent_for?(node)
      @tree.keys.select {|n| @tree[n].include?(node)}[0]
    end

    def nodes
      @tree.values.inject([]){ |res, nodes| res + nodes }.uniq
    end

    def build_hash
      @tree[root].inject({}) do |out, n|
        out.merge(build_hash_with_context(n, n.content.call))
      end
    end

    def build_hash_with_context(node, context)
      if context.kind_of? Array
        { node.label =>
          context.map do |elementary_context|
            build_hash_with_context(node, elementary_context)
          end
        }
      elsif @tree[node]
        node_value = node.apply(context).merge(
          @tree[node].inject({}) do |out, n|
            new_context = n.content.call(context)
            if new_context.nil?
              out
            else
              if n.bounded?
                out.merge(build_hash_with_context(n, new_context).values.first)
              else
                out.merge(build_hash_with_context(n, new_context))
              end
            end
          end)
        node.suppress_label ?
          node_value :
          { node.label.singularize => node_value }
      else
        node.suppress_label ?
          node.apply(context) :
          { node.label.singularize => node.apply(context) }
      end
    end

    def to_s
      nodes.inject('') do |res, node|
        res <<
        node.to_s  <<
        (node.bounded? ? " bounded_to: " : " parent: ") <<
        "#{parent_for?(node).name}\n"
      end
    end
  end

  class Node

    attr_accessor :methods
    attr_accessor :attributes
    attr_accessor :code_blocks
    attr_accessor :label
    attr_accessor :suppress_label
    attr_accessor :statics
    attr_reader :name
    attr_reader :content
    attr_reader :type

    class CodeBlock
      attr_reader :label
      attr_reader :code

      def initialize(label, code)
        @label = label
        @code = code
      end

      def to_s
        label + code + "\n"
      end
    end

    class Method
      attr_accessor :label
      attr_accessor :params
      attr_reader :name

      def initialize(name)
        @name = name
        @label = name
        @params = []
      end

      def to_s
        name +
        (params.empty? ? '' : "(#{params * ','})") +
        (name == label ? '' : " => #{label}")
      end
    end

    class Static
      attr_accessor :label
      attr_accessor :value

      def initialize label, value
        @label = label
        @value = value
      end

      def to_s
        "#{label}: #{value}"
      end
    end

    class Attribute
      attr_accessor :label
      attr_reader :name

      def initialize(name)
        @name = name
        @label = name
      end

      def to_s
        name == label ?
        name : "#{name}(#{label}) "
      end

    end

    #====================================#
    #             main class             #
    #====================================#

    def initialize(name, type, bounded = false)
      @name = name
      @label = @name.gsub(/[@\$]/,'')
      @type = type
      @methods = []
      @attributes = { :only => [], :except => []}
      @code_blocks = []
      @statics = []
      @suppress_label = false
    end

    def eval(vars)
      @content = case type
      when :variable
        lambda { Kernel.eval name, vars }
      when :association, :bounded
        lambda { |context| context.send(name.intern)}
      end
      self
    end

    def apply(context)
      if attributes[:only].size > 0
        attributes[:only].inject({}) do |res, att|
          res[att.label] = context.send(att.name.intern)
          res
        end
      elsif attributes[:except].size > 0
        context.attributes.delete_if {|(k,v)| attributes[:except].map(&:name).include?(k)}
      else
        # use all variables by default if they are supported
        context.respond_to?(:attributes) ? context.attributes : {}
      end.merge(
        (methods || []).inject({}) do |res, m|
          res[m.label] = context.send(m.name.intern, *(m.params.map {|p| context.instance_eval p}))
          res
        end
      ).merge(
        code_blocks.inject({}) do |res, cb|
          res[cb.label] = context.instance_eval cb.code
          res
        end
      ).merge(
        statics.inject({}) do |res, s|
          res[s.label] = s.value
          res
        end
      )
    end

    def add_attribute(key, attr)
      unless @attributes[key].include?(attr)
        @attributes[key] << attr
      end
    end

    def bounded?
      :bounded == type
    end

    def to_s
      "Node: " <<
        ((name == label) ? name : "#{name}(#{label})") <<
        (methods.empty? ? ' ' : " Methods: #{methods.map(&:to_s).join(',')} ")  <<
        (if attributes[:except].size > 0
          "Except: #{attributes[:except].to_s}"
        elsif attributes[:only].size > 0
          "Only: #{attributes[:only].to_s}"
        else
          ''
        end) <<
        ((code_blocks.size > 0) ? "Code blocks: \n" << code_blocks.map(&:to_s).join : '')
    end
  end

end

