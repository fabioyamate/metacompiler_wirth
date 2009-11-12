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

    attr_reader :output, :rule, :nfa
    
    def initialize(rule)
      raise Exception, "rule can't be nil" if rule.nil?
      
      @rule = rule
      # a simple tape implementation with internal cursor state
      @cs = CharStream.new(@rule)
      
      # output rule with states marked
      @output = "0 "
      
      # stack for end mark group (balancing groups)
      @stack = [] 
      
      # stack to keep tracking begin & end group states
      @stack_states = [0] 
      
      @last_state = 0 
      
      @transitions = {}
      
      @symbols = []
      @final_states = []
      
      @current_accept_state = 0
      
      execute
    end
    
    # Obtains the minimized dfa automata
    def dfa
      return @dfa unless @dfa.nil?
      @dfa = nfa_to_dfa(@nfa)
    end
    
    def minimized_dfa
      return @minimized_dfa unless @minimized_dfa.nil?
      @minimized_dfa = minimize_dfa(dfa)
    end
    
    # Mark states and creates a nfa automata
    def execute
      mark_states
      @nfa = {
        :initial => 0,
        :final => @final_states,
        :symbols => @symbols,
        :states => (0..@last_state),
        :transitions => @transitions
      }
    end
    
    # a straightforward lexer + syntatic implementation for Wirth grammar
    #
    # It's used two stacks, one to maintain a balanced syntax control of
    # group symbols () [] {}, and another that keeps track of states.
    #
    # The main stack is the @stack_states which always have two states:
    #   1. if entered in a group, it always have two entries
    #      the end mark group state and current state before the token readed
    #
    #                                     top
    #       n ( n ... ) n+1        stack: [n, n+1 ...]
    #       n: state_before_token
    #
    #       or
    #                                     top
    #       n { n+1 ... } n+1      stack: [n+1, n+1 ...]
    #       n: state_before_token
    #
    #   2. if it's not a group, it always keeps one entry, which is
    #      the next current state before a token
    #
    #                                      top
    #       ... n T n+1 ...         stack: [n+1, ...]
    #       n: state_before_token
    #
    # TODO: move to a tokenizer implementation in order to
    #       parse an entire language definition, and not only
    #       a single rule.
    def mark_states(entry_group=0)
      while not @cs.finished
        ch = @cs.read
        case ch
        when /[\[\(]/
          # we get the state before the start group (token)
          state_before_token = @stack_states.pop
          # we reserve the end state to this group
          #   n ( ... ) n+1
          # or
          #   n [ ... ] n+1
          @last_state = @last_state + 1
          end_group_state = @last_state
          
          # we push into stack the end state and keep the 
          # entry state of group
          #   state_before_token ( state_before_token ... ) end_group_state
          # or
          #   state_before_token [ state_before_token ... ] end_group_state
          @stack_states << end_group_state
          @stack_states << state_before_token
          
          #@final_states << @last_state if @stack.empty?
          
          # for validation of syntax we put into stack
          # the expected end mark group
          @stack << ')' if ch.eql? '('
          
          if ch.eql? '['
            @stack << ']'
            @transitions[state_before_token] ||= []
            @transitions[state_before_token] << [nil, end_group_state]
          end
          
          # we add to the output
          #   ( st    or  [ st
          @output << "#{ch} #{state_before_token} "
          
          # we recursivelly call to mark the internal rule,
          # with the entry state of the rule
          mark_states(state_before_token)
        when '{'
          # the algorithm is similar to '(' or '[' except
          # the states pushed into stack
          state_before_token = @stack_states.pop
          @last_state = @last_state + 1
          end_group_state = @last_state
          # for '{' group the entry state is the end group state
          #   state_before_token { end_group_state ... } end_group_state
          @stack_states << end_group_state
          @stack_states << end_group_state
          #@final_states << @last_state if @stack.empty?
          @stack << '}'
          
          @transitions[state_before_token] ||= []
          @transitions[state_before_token] << [nil, end_group_state]
          
          @output << "#{ch} #{end_group_state} "
          
          # we recursivelly call to mark the internal rule,
          # with the entry state of the rule
          mark_states(@last_state)
        when /[\]\)}]/
          # pop the expected end mark group
          end_mark = @stack.pop
          # validates the current end mark readed
          raise SyntaxError, "invalid end mark '#{ch}' expected '#{end_mark}'" unless ch.eql? end_mark
          # we then pop the end state inside group
          state_before_token = @stack_states.pop
          
          # we need to create a transition for exiting a group
          #    ... state_before_token ) end_group_state
          # produces  (state_before_token, nil) -> end_group_state
          end_group_state = @stack_states.last
          @transitions[state_before_token] ||= []
          @transitions[state_before_token] << [nil, end_group_state]
          
          @output << "#{ch} #{end_group_state} "
          
          # we then save a possible final state of the rule
          #   n ( n ... ) _n+1_ -> n+1 might be a final state
          #
          # n+1 will be a final state only if the group ends
          # with:
          #   - | (pipe): option, n ( n ... ) n+1 | n ...
          #   - . : end rule, n ( n ... ) n+1 '.'
          #
          # other option is the last state after a NT or T
          #   ... T n '.'
          #@current_accept_state = end_group_state
          return
        when ' ' # discart space chars
          next
        when '.' # end rule founded
          raise SyntaxError, "invalid wirth rule. The end mark groups are missing its open group: #{@stack.join(',')}" if not @stack.empty?
          @final_states << @stack_states.pop
          break
        when '|'
          state_before_token = @stack_states.pop
          
          if @stack.empty?
            # if it is not inside a group then we have this cenario
            #  entry_group A state_before_token | entry_group
            @final_states << state_before_token
          else
            # if the pipe is found inside a group, it can't be
            # a final state, in this case we need to add a transition
            # to the end state of the group
            #
            #   ... n ( n ... m | ... ) n+1    (m, nil) -> n+1
            end_state = @stack_states.last # the top is the end group state
            @transitions[state_before_token] ||= []
            @transitions[state_before_token] << [nil, end_state]
          end
          
          @output << "| #{entry_group} "
          @stack_states << entry_group
        else # non-terminal and terminal
          # TODO: a tokenizer should deal with this
          input = ch
          case ch
          when '"' # terminal
            while true
              ch = @cs.read
              raise SyntaxError, "null char readed, unbalanced quotes" if ch.nil?
              input << ch
              if ch.eql? '"'
                lookahead = @cs.read # read next
                @cs.undo
                unless lookahead.eql? '"'
                  raise SyntaxError, "terminal can't be empty" if input.length == 2
                  break
                end
              end
            end
          when /[a-zA-Z]/ # non-terminal
            while true
              ch = @cs.read
              if not ch =~ /[a-zA-Z_]/
                @cs.undo
                break
              end
              input << ch
            end
          else
            raise SyntaxError, "invalid name, can't have '#{ch}'"
          end
          @symbols << input unless @symbols.include?(input)
          state_before_token = @stack_states.pop
          # a transition to a NT or T goes to a new state
          #   ... state_before_token T end_state ...
          @last_state = @last_state + 1
          end_state = @last_state
          @stack_states << end_state
          
          @transitions[state_before_token] ||= []
          @transitions[state_before_token] << [input, end_state]
          
          @output << "#{input} #{@last_state} "
        end
      end
    end
    
    private :mark_states, :execute
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
        move <<  "(#{state}, #{symbol.inspect}) -> #{to}"
        
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
end

#require 'pp'
#include Grammar
#w = Grammar::Wirth.new('( n | "<" T ">" ) { "*" ( n | "<" T ">" ) } { "-" ( n | "<" T ">" ) { "*" ( n | "<" T ">" ) } }.')
#w = Grammar::Wirth.new('T I [ "<" N { "," N } ">" ] { "," I [ "<" N { "," N } ">" ] }.')
#w = Grammar::Wirth.new('(((numero | identificador | "(" expressao ")") {"^"( numero | identificador | "(" expressao ")")}){("*"|"/")( (numero | identificador | "(" expressao ")") {"^"( numero | identificador | "(" expressao ")")})}){("+"|"-") (((numero | identificador | "(" expressao ")") {"^"( numero | identificador | "(" expressao ")")}) {("*"|"/")(( numero | identificador | "(" expressao ")") {"^"( numero | identificador | "(" expressao ")")})})}.')
#w = Grammar::Wirth.new('( ( (numero | id | expr) { "+" numero } ) { "*" numero } ).')
#w = Grammar::Wirth.new('{(identificador "=" expressao | "if" (expressao comparador expressao | boolean) "then" seqcmds ["else" seqcmds] "ifend"| "switch" identificador "case" identificador seqcmds "break"{"case" identificador seqcmds "break"} "switchend" | "while" (expressao comparador expressao | boolean) "do" seqcmds "whilend"| "for" "("(identificador "=" expressao )";"(expressao comparador expressao | boolean)"; "expressao")" seqcmds "forend"| "scan" identificador | "print" (expressao | """expressao """)| "call" nome "("[identificador {","identificador}]")")";"}.')
#w = Grammar::Wirth.new('{ ( a | c (exp | d exp d) | b )} | c.')
#w = Grammar::Wirth.new('b c.')
#p w.output
#pp format_transitions(w.nfa)
#pp w.nfa
#pp format_transitions(w.dfa)
#pp format_transitions(w.minimized_dfa)