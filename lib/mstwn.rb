require 'fa'

module Streamer
  class CharStream
    attr_reader :str
    
    def initialize(str="")
      @str = str
      @len = str.length
      @idx = 0
    end
    
    def finished
      @idx >= @len
    end
    
    def read
      return nil if finished
      @idx = @idx + 1 if @idx < @len
      @str[@idx-1].chr
    end
    
    def undo
      @idx = @idx - 1 if @idx > 0
    end
  end
end

module Grammar
  class Wirth
    include Streamer
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
    end

    def mark_states(entry_group=0)
      while not @cs.finished
        ch = @cs.read
        case ch
        when /[\[\(]/
          st = @stack_states.pop
          @last_state = @last_state + 1
          @stack_states << @last_state # pushing the last state
          @stack_states << st # pushing start group
          @current_accept_state = @last_state
          @stack << ')' if ch.eql? '('
          @stack << ']' if ch.eql? '['
          @output << "#{ch} s #{st} "
          mark_states(st)
        when /[\]\)]/
          end_mark = @stack.pop
          raise SyntaxError, "invalid end mark '#{ch}' expected '#{end_mark}'" unless ch.eql? end_mark
          st = @stack_states.pop
          end_group_state = @stack_states.pop
          @stack_states << end_group_state
          @transitions << [st, nil, end_group_state]
          @output << ">#{ch}< #{end_group_state} "
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
          raise SyntaxError, "invalid wirth rule. The end mark groups are missing its open group: #{@stack.join(',')}" if not @stack.empty?
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
              raise SyntaxError, "null char readed, unbalanced quotes" if ch.nil?
              input << ch
              break if ch.eql? '"'
            end
          else
            while true
              ch = @cs.read
              unless ch =~ /[a-zA-Z]/
                @cs.undo
                break
              end
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