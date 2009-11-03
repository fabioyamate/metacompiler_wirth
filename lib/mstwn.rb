require 'rubygems'
require 'builder'
require 'pp'
require 'fa'

module Compiler
  class CharStream
    attr_reader :str
    
    def initialize(str="")
      @str = str
      @len = str.length
      @idx = 0
    end
    
    def finished
      @idx == @len
    end
    
    def read
    return nil if finished
      @idx = @idx + 1 if @idx < @len 
      @str[@idx-1].chr
    end
  end

  class Wirth
    include FiniteAutomata

    attr_reader :output, :str, :nfa
    
    def initialize(str)
      @str = str
      init
    end
    
    def init
      @output = ""
      @stack = []
      @cs = CharStream.new(@str)
      @last_state = 0
      @stack_states = [0]
      @transitions = []
      @current_accept_state = 0
      @final_states = []
      @symbols = []
      @initial_state = 0
      @states = []
    end
    
    def execute
      init
      @output = "0 "
      mark_states
      @nfa = {
        :initial => 0,
        :final => @final_states,
        :states => (0..@last_state),
        :transitions => @transitions,
        :symbols => @symbols
      }
      @states = (0..@last_state)
      @output
    end
    
    def dfa
      minimize_dfa(nfa_to_dfa(@nfa))
      #nfa_to_dfa(@nfa)
    end
    
    def dfa1
      nfa_to_dfa(@nfa)
    end

    def mark_states(entry_group=0)
      while not @cs.finished
        ch = @cs.read
        case ch
        when '('
          st = @stack_states.pop
          if @stack.empty?
            @last_state = @last_state + 1
          else
            @last_state = st + 1
          end
          @stack_states << @last_state
          @stack_states << @last_state - 1
          @current_accept_state = @last_state
          @stack << ')'
          @output << "( #{st} "
          mark_states(st)
        when ')'
          end_mark = @stack.pop
          raise SyntaxError, "invalid end mark '#{ch}' expected '#{end_mark}'" unless ch.eql? end_mark
          st = @stack_states.pop
          end_group_state = @stack_states.pop
          @stack_states << end_group_state
          @transitions << [st, nil, end_group_state]
          @output << ") #{end_group_state} "
          @current_accept_state = end_group_state
          return
        when '['
          st = @stack_states.pop
          if @stack.empty?
            @last_state = @last_state + 1
          else
            @last_state = st + 1
          end
          @stack_states << @last_state
          @stack_states << @last_state - 1
          @current_accept_state << @last_state
          @stack << "]" # adding end group mark
          @transitions << [st, nil, @last_state]
          @output << "[ #{st} "
          mark_states(st) # recursion call
        when ']'
          end_mark = @stack.pop
          raise SyntaxError, "invalid end mark '#{ch}' expected '#{end_mark}'" unless ch.eql? end_mark
          st = @stack_states.pop
          end_group_state = @stack_states.pop
          @stack_states << end_group_state
          @transitions << [st, nil, end_group_state]
          @output << "] #{end_group_state} "
          @current_accept_state = end_group_state
          return
        when '{'
          st = @stack_states.pop
          @last_state = @last_state + 1
          @stack_states << @last_state
          @stack_states << @last_state
          @current_accept_state = @last_state
          @stack << "}"
          @transitions << [st, nil, @last_state]
          @output << "{ #{@last_state} "
          mark_states(@last_state)
        when '}'
          end_mark = @stack.pop
          raise SyntaxError, "invalid end mark '#{ch}' expected '#{end_mark}'" unless ch.eql? end_mark
          st = @stack_states.pop
          end_group_state = @stack_states.pop
          @stack_states << end_group_state
          @transitions << [st, nil, end_group_state]
          @output << "} #{end_group_state} "
          @current_accept_state = end_group_state
          return
        when ' '
          next
        when '.'
          raise SyntaxError, "invalid wirth rule" if not @stack.empty?
          break
        when '|'
          st = @stack_states.pop # discart stack
          @output << "| #{entry_group} "
          @stack_states << entry_group
          if @stack.empty?
            @final_states << @current_accept_state
          else
            final_group_state = @stack_states.last
            @transitions << [st, nil, @current_accept_state]
          end
        else
          input = ch
          while ch.eql? ' '
            ch = @cs.read
          end
          if ch.eql? '"'
            while true
              ch = @cs.read
              raise SyntaxError, "null char received, check quotes balance" if ch.nil?
              input << ch
              break if ch.eql? '"'
            end
          else
            while true
              ch = @cs.read
              break unless ch =~ /[a-zA-Z]/
              input << ch
            end
          end
          @symbols << input unless @symbols.include?(input)
          st = @stack_states.pop
          @last_state = @last_state + 1
          @stack_states << @last_state
          @transitions << [st, input, @last_state]
          @output << "#{input} #{@last_state} "
          @current_accept_state = @last_state if @stack.empty?
        end
      end
      @final_states << @current_accept_state
    end
  end
end

module JFLAP
  def generate_jflap_fa_file(filename, fa)
    f = File.new(filename, 'w')
    counter = 0
    xml = Builder::XmlMarkup.new(:target => f, :indent => 2)
    xml.instruct!
    xml.structure do
    xml.type "fa"
      fa[:states].each do |s|
        xml.state :id => s, :name => "q#{s}" do
          xml.initial if fa[:initial] == s
          xml.final if fa[:final].include?(s)
        end
        counter = counter + 1
      end
      fa[:transitions].each do |k,v|
        from = k
        v.each do |t|
          read, to = t
          xml.transition do
            xml.from from
            xml.to to
            xml.read read
          end
        end
      end
    end
    f.close
  end

  def generate_jflap_fa_file2(filename, fa)
    f = File.new(filename, 'w')
    counter = 0
    xml = Builder::XmlMarkup.new(:target => f, :indent => 2)
    xml.instruct!
    xml.structure do
    xml.type "fa"
      fa[:states].each do |s|
        xml.state :id => s, :name => "q#{s}" do
          xml.initial if fa[:initial] == s
          xml.final if fa[:final].include?(s)
        end
        counter = counter + 1
      end
      fa[:transitions].each do |t|
        from, read, to = t
        xml.transition do
          xml.from from
          xml.to to
          xml.read read
        end
      end
    end
    f.close
  end
end

def format_transitions(fa)
  moves = []
  fa[:states].each do |state|
    next if fa[:transitions][state].nil?
    fa[:transitions][state].each do |t|
      symbol, to = t
      move = "        "
      move = "initial " if state.eql? fa[:initial]
      move = " accept " if fa[:final].include?(to)
      move <<  "(#{state}, #{symbol}) -> #{to}"
      p move
      moves << move
    end
  end
  moves
end

def fa_to_s(fa)
  formatted = "initial: #{fa[:initial]}\n"
  formatted << "final: #{fa[:final].join(', ')}\n"
  fa[:states].each do |state|
    next if fa[:transitions][state].nil?
    fa[:transitions][state].each do |t|
      symbol, to = t
      formatted <<  "(#{state}, #{symbol}) -> #{to}\n"
    end
  end
  formatted
end


#s = Compiler::Wirth.new("( n | < T > ) { * ( n | < T > ) } { - ( n | < T > ) { * ( n | < T > ) } }.")
#p s.execute
#p s.nfa
#p s.dfa
#include JFLAP

#s2 = Compiler::Wirth.new("T I [ < N { , N } > ] { , I [ < N { , N } > ] }.")
#s2 = Compiler::Wirth.new("{ ( a | b ) } a b b.")
#s2 = Compiler::Wirth.new('n ( C | O ) a [ C { , C } ] b.')
#s2 = Compiler::Wirth.new('n C + p C * [ P { , P } ] / - | C.')
#s2.execute
#p s2.nfa
#p s2.dfa
#p s2.dfa
#generate_jflap_fa_file2("abobrinha.jff", s2.nfa)
#s2.dfa
#p format_transitions(s2.dfa)
