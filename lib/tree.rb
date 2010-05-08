require 'ostruct'

module Tequila

  class Config

    class Default
      @@show_initial_label = false

      def self.show_initial_label!
        @@show_initial_label = true
      end

      def self.hide_initial_label!
        @@show_initial_label = false
      end

      def self.show_initial_label?
        @@show_initial_label
      end
    end

    attr_reader :show_initial_label

    def show_initial_label!
      @show_initial_label = true
    end

    def hide_initial_label!
      @show_initial_label = false
    end

    def initialize
      @show_initial_label = Default.show_initial_label?
    end

  end

  class Tree

    attr_reader :root
    attr_accessor :config

    def initialize
      @root = OpenStruct.new({:name => :root})
      @tree = { @root => [] }
      @config = Tequila::Config.new
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
      res = @tree[root].inject({}) do |out, n|
        out.merge(build_hash_with_context(n, n.content.call))
      end
      ((res.values.first.kind_of? Array) && !config.show_initial_label) ?
      res.values.first : res
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

    # it is used for attributes if 'all' keyword was specified
    attr_reader :pick_all
    attr_reader :drop_all

    class ImpreciseAttributesDeclarationError < StandardError; end
    class NoAttributeError < StandardError; end

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
      mapping = {}
      if context.respond_to?(:attributes) && !drop_all

        if (pick_all || drop_all)
          unless attributes[:only].empty? && attributes[:except].empty?
            raise ImpreciseAttributesDeclarationError, "declaration conflict"
          end
        end

        context_attributes = context.attributes
        #p "All: #{context_attributes.keys.inspect}"
        if attributes[:only].size > 0
          chosen_attributes = attributes[:only].map(&:name)
          #p "Chosen: #{chosen_attributes}"
          unless (foreign_attributes = (chosen_attributes.to_set - context_attributes.keys.to_set)).empty?
            raise NoAttributeError, "can't find attributes: #{foreign_attributes.to_a.join(', ')}"
          end
          attributes[:only].inject({}) do |res, att|
            res[att.label] = context_attributes[att.name]
            res
          end
        elsif attributes[:except].size > 0

          ignored_attributes = attributes[:except].map(&:name)
          #p "Ignored: #{ignored_attributes.inspect}"
          unless (foreign_attributes = (ignored_attributes.to_set - context_attributes.keys.to_set)).empty?
            raise NoAttributeError, "can't find attributes: #{foreign_attributes.to_a.join(', ')}"
          end
          context_attributes.delete_if { |att_name, _| ignored_attributes.include?(att_name) }
        else
          # use all variables by default if they are supported
          context_attributes
        end
      else
        {}
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
      raise ImpreciseAttributesDeclarationError if (pick_all || drop_all)
      unless @attributes[key].include?(attr)
        @attributes[key] << attr
      end
    end

    def no_attributes!
      if pick_all
        raise ImpreciseAttributesDeclarationError, "declaration conflict"
      else
        @drop_all = true
      end
    end

    def all_attributes!
      if drop_all
        raise ImpreciseAttributesDeclarationError, "declaration conflict"
      else
        @pick_all = true
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

