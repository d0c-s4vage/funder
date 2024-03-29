#  Copyright (c) 2010, Nephi Johnson
#  All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without modification, are permitted
#  provided that the following conditions are met:
#  
#      * Redistributions of source code must retain the above copyright notice, this list of
#        conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright notice, this list of
#        conditions and the following disclaimer in the documentation and/or other materials
#        provided with the distribution.
#      * Neither the name of Funder nor the names of its contributors may be used to
#        endorse or promote products derived from this software without specific prior written
#        permission.
#  
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
#  AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
#  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.

require 'fields'
require 'values'
require 'actions'
require 'syntactic_sugar'
require 'funder_parser'

class Array
	def append_or_replace(val, &block)
		self.length.times do |i|
			if block.call(self[i])
				self[i] = val
				return
			end
		end
		self.insert(-1, val)
	end
end

class PreField
	attr_accessor :name, :klass, :value, :options, :parent_class
	def initialize(name, klass, value=nil, options={}, parent_class=nil)
		@name = name
		@klass = klass
		@options = options
		@value = value
		@parent_class = parent_class
	end
	def clone
		result_name = @name
		result_klass = @klass
		result_value = @value.clone rescue @value
		result_options = @options.clone
		result = PreField.new(result_name, result_klass, result_value, result_options, @parent_class)
		result
	end
	def create
		@value = @value.create if @value.respond_to?(:create)
		if @options[:mult]
			MultiField.new(@klass, @name, @value, @options)
		else
			@klass.new(@name, @value, @options)
		end
	end
	def inspect
		value_inspect = @value.inspect
		value_inspect = @value.inspect(1) if @value.kind_of?(Action)
		"#<PreField(#{klass.to_s}) @value=#{@value.inspect} @name=\"#{@name}\">"
	end
	def parse(data)
		puts "in PreField parse"
		len = read_length
		return nil if len == -1
		puts "  made it here"
		@klass.parse(data.slice!(0, len), self)
	end
	def read_length
		@klass.read_length(self)
	end
end

class PreAction
	attr_accessor :klass, :args
	def initialize(klass, *args)
		if klass.kind_of? Proc
			@klass = CustomAction
			args.insert(0, klass)
		else
			@klass = klass
		end
		@args = args
	end
	def create
		new_args = []
		@args.each do |arg|
			if arg.respond_to?(:create)
				new_args << arg.create
			else
				new_args << arg
			end
		end
		@klass.new(*new_args)
	end
end

class Funder < Str
	class << self
		include FunderParser
		include SyntacticSugar

		attr_accessor :order, :descendants
		def field(name, klass, value=nil, options={})
			@order ||= []
			pf = PreField.new(name, klass, value, options, self)
			@order.append_or_replace(pf) {|field| field.name == name}
			make_class_accessor(name, pf)
		end
		def unfield(name, klass, val=nil, options={})
			@unfields ||= []
			pf = PreField.new(name, klass, val, options, self)
			@unfields.append_or_replace(pf) {|field| field.name == name}
			make_class_accessor(name, pf)
		end
		def section(name, action=nil, options={}, &block)
			options[:action] = action
			@order ||= []
			new_class = name.to_s
			new_class[0,1] = new_class[0,1].upcase
			class_eval "class #{new_class} < Section ; end"
			klass = class_eval new_class
			klass.class_eval &block
			field(name, klass, nil, options)
			make_class_accessor(name, @order.find{|f| f.name == name})
		end
		def action(klass, *args)
			PreAction.new(klass, *args)
		end
		def bind(bind_lambda, fields_map=nil)
			if fields_map == nil
				return BoundValue.new(bind_lambda)
			else
				return MultiBoundValue.new(bind_lambda, fields_map)
			end
		end
		def counter(name, start_num=0, incrementor=1, replace=true)
			return Counter.new(name, start_num, incrementor, replace)
		end
		def make_class_accessor(name, val)
			self.class_eval <<-RUBY
				class << self ; attr_accessor :#{name} ; end
			RUBY
			instance_variable_set("@#{name}", val)
		end
		def inherited(klass)
			@order ||= []
			@unfields ||= []
			klass.class_eval{class << self ; attr_accessor :order, :unfields ; end}
			klass.unfields = []
			klass.order = []
			@order.each {|f| klass.order << f.clone ; klass.order.last.parent_class = klass }
			@unfields.each {|uf| klass.unfields << uf.clone ; klass.unfields.last.parent_class = klass }
			@descendants ||= []
			@descendants << klass

			@order.each do |f|
				klass.make_class_accessor(f.name, klass.order.find{|kf| kf.name == f.name})
			end
			@unfields.each do |uf|
				klass.make_class_accessor(uf.name, klass.unfields.find{|kuf| kuf.name == uf.name})
			end
			nil
		end
	end # class << self
	attr_accessor :order, :unfields
	def initialize(*args)
		super(*args) if args.length == 3
		@options = {}
		@order = []
		@unfields = []
		self.class.order.each {|f| create_field(f.clone, @order) }
		self.class.unfields.each {|uf| create_field(uf.clone, @unfields)}
		# this means we are the root node and need to tell all children nodes
		# that they can init now (everything should be created by now)
		init if @parent == nil
	end
	def create_field(pre_field, dest)
		self.class.class_eval { attr_accessor pre_field.name }
		field = pre_field.create
		field.parent = self
		dest << field
		instance_variable_set("@#{pre_field.name}", field)
	end
	def result_length
		res = 0
		@order.each do |field|
			res += field.result_length
		end
		res
	end
	def gen_val(*args)
		return @value if @value
		res = ""
		@order.map {|f| res << f.to_out	}
		res
	end
	def reset
		super
		@order.each {|f| f.reset }
		nil
	end
	def detail_inspect(level=0)
		""
	end
	def inspect(level=0)
		if level == 0
			res = "#<#{self.class.to_s} "
			fields_str = @order.map do |field|
				"#{field.name}=#{field.inspect(level+1)}"
			end.join(" ")
			res += fields_str + " " + detail_inspect + ">"
			return res
		elsif level == 1
			return "#<#{self.class.to_s}>"
		elsif level == 2
			return self.class.to_s
		else
			return ""
		end
	end
end

class Section < Funder
	def initialize(name, value, options)
		super(name, value, options)
		@action = options[:action]
		@action = @action.create if @action && @action.respond_to?(:create)
		@action.parent = @parent if @action
	end
	def parent=(val)
		@parent = val
		@action.parent = @parent if @action
	end
	def detail_inspect(level=0)
		if @action
			"action=#{@action.inspect(level+1)}"
		else
			""
		end
	end
end
