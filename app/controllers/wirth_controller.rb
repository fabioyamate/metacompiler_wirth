require 'grammar_wirth'
require 'jflap'

class WirthController < ApplicationController
  include Grammar
  include JFLAP
  
  NONTERMINAL = /[a-zA-Z][a-zA-Z_]*/
  TERMINAL = /".+"/
  RULES = /.*\./
  RULE = /(?:([a-zA-Z][a-zA-Z_]*)\s*=)?\s*(.+\.)\n?/
  
  def index
    @wirth_notation = params[:wirth_notation]
    return if @wirth_notation.nil?
    
    @converted = []
    @automatas = {}
    
    @wirth_notation.gsub!(/(\342\200\230|\342\200\231|\342\200\234|\342\200\235)/, '"')
    @wirth_notation.scan(RULES).each do |r|
      begin
        data = RULE.match(r)
        if data.nil?
          @converted << { :name => "Error", :stated => "Unterminated declaration" }
          next
        end
        p data.captures
        name, decl = data.captures
        p decl

        s = Wirth.new(decl)

        stated_rule = s.output.gsub(/(\s+".+"\s+)/, "<i>\\1</i>").gsub(/(\s+[a-zA-Z][a-zA-Z_]*\s+)/, "<b>\\1</b>").gsub(/\b(\d+)\b/, "<span>\\1</span>")
        @converted << { :name => name, :stated => stated_rule }
        
        @automatas[name] = {
          :nfa => fa_to_s(s.nfa),
          :dfa => fa_to_s(s.dfa),
          :minimized_dfa => fa_to_s(s.minimized_dfa)
        }
        
        jflap_output = ""
        generate_jflap_fa(jflap_output, s.minimized_dfa);
        
        @automatas[name][:jflap] = jflap_output
      rescue SyntaxError => e
        @converted << { :name => name, :stated => e.message }
      rescue Exception => e
        @converted << { :name => name, :stated => "An unexpected error occurred" }
        p "-" * 30
        p e.message
        e.backtrace.each do |line|
          p line
        end
        p "-" * 30
      end
    end
  end
end
