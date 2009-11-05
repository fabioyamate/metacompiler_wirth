require 'mstwn'

class WirthController < ApplicationController
  include Grammar
  
  NONTERMINAL = /[a-zA-Z][a-zA-Z]*/
  TERMINAL = /".+"/
  RULES = /.*\./
  RULE = /(?:([a-zA-Z]+)\s*=)?\s*([^\.]+\.)/
  
  def index
    @wirth_notation = params[:wirth_notation]
    return if @wirth_notation.nil?
    
    @converted = []
    @automatas = {}
    
    @wirth_notation.gsub!(/(\342\200\230|\342\200\231|\342\200\234|\342\200\235)/, '"')
    @wirth_notation.scan(RULES).each do |r|
      begin
        name, decl = RULE.match(r).captures

        s = Wirth.new(decl)
        s.execute

        stated_rule = s.output.gsub(/\b(\d+)\b/, "<span>\\1</span>").gsub(/\b([A-Z][a-zA-Z]*)\b/, "<b>\\1</b>").gsub(/("[^\s]+")/, "<i>\\1</i>")
        @converted << { :name => name, :stated => stated_rule }
        @automatas[name] = fa_to_s(s.dfa)
      rescue SyntaxError => e
        @converted << { :name => name, :stated => e.message }
      rescue Exception => e
        @converted << { :name => name, :stated => "An unexpected error occurred" }
      end
    end
  end
end
